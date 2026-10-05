package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"expense-tracker/backend/database"
	"expense-tracker/backend/internal/activity"
	"expense-tracker/backend/internal/auth"
	"expense-tracker/backend/internal/balances"
	"expense-tracker/backend/internal/expenses"
	"expense-tracker/backend/internal/groups"
	"expense-tracker/backend/internal/memstore"
	"expense-tracker/backend/internal/middleware"
	"expense-tracker/backend/internal/settlements"
	"expense-tracker/backend/internal/syncbox"
	"expense-tracker/backend/internal/websocket"
	"expense-tracker/backend/pkg/response"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

func main() {
	log.Println("[Server] Starting Group Financial Ledger API server...")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 1. Connect to PostgreSQL
	pool, err := database.Connect(ctx)
	if err != nil {
		log.Printf("[Server WARNING] Database connection failed: %v. Running in limited mode or check DATABASE_URL.", err)
	} else {
		defer pool.Close()
		// Run schema migrations
		if err := database.RunMigrations(ctx, pool, "database/migrations/001_init.sql"); err != nil {
			log.Printf("[Server ERROR] Migrations error: %v", err)
		}
		// Start periodic idempotency cleanup
		middleware.CleanupExpiredIdempotencyKeys(ctx, pool)
	}

	// 2. Initialize in-memory WebSocket Room Hub
	hub := websocket.NewHub()
	go hub.Run()

	// 3. Initialize Handlers
	authHandler := auth.NewHandler(pool)
	groupsHandler := groups.NewHandler(pool)
	expensesHandler := expenses.NewHandler(pool, hub)
	balancesHandler := balances.NewHandler(pool)
	settlementsHandler := settlements.NewHandler(pool, hub)
	activityHandler := activity.NewHandler(pool)
	syncboxHandler := syncbox.NewHandler(hub)

	// 4. Setup Router
	r := chi.NewRouter()

	// Global Middlewares
	r.Use(chiMiddleware.RequestID)
	r.Use(chiMiddleware.RealIP)
	r.Use(chiMiddleware.Logger)
	r.Use(chiMiddleware.Recoverer)
	r.Use(chiMiddleware.Timeout(30 * time.Second))

	// CORS Setup
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"http://localhost:5173", "http://localhost:3000", "http://127.0.0.1:5173", "*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token", "Idempotency-Key"},
		ExposedHeaders:   []string{"Link", "X-Idempotent-Replay"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health Check
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		dbStatus := "connected"
		if pool == nil {
			dbStatus = "disconnected"
		}
		response.JSON(w, http.StatusOK, map[string]string{
			"status":   "healthy",
			"database": dbStatus,
			"time":     time.Now().Format(time.RFC3339),
		})
	})

	// Public Auth & Session Endpoints
	r.Route("/api/v1/auth", func(r chi.Router) {
		r.Post("/session", authHandler.GetOrCreateSession)
		r.Post("/register", authHandler.Register)
		r.Post("/login", authHandler.Login)
		r.With(middleware.RequireAuth).Get("/me", authHandler.GetMe)
	})

	// Protected Routes
	r.Group(func(r chi.Router) {
		r.Use(middleware.RequireAuth)

		// Group Creation & Joining
		r.Route("/api/v1/groups", func(r chi.Router) {
			r.Post("/", groupsHandler.CreateGroup)
			r.Get("/", groupsHandler.ListUserGroups)
			r.Post("/join", groupsHandler.JoinGroup)

			// Group-Scoped Routes (Protected with Active Member RBAC)
			r.Route("/{groupId}", func(r chi.Router) {
				if pool != nil {
					r.Use(middleware.RequireGroupMember(pool))
				}

				r.Get("/", groupsHandler.GetGroup)
				r.Delete("/", groupsHandler.DeleteGroup)
				r.Post("/leave", groupsHandler.LeaveGroup)

				// Expenses
				r.Route("/expenses", func(r chi.Router) {
					if pool != nil {
						r.With(middleware.RequireIdempotency(pool, "EXPENSE_CREATE")).Post("/", expensesHandler.CreateExpense)
					} else {
						r.Post("/", expensesHandler.CreateExpense)
					}
					r.Get("/", expensesHandler.ListExpenses)

					// Reversal
					if pool != nil {
						r.With(middleware.RequireIdempotency(pool, "EXPENSE_REVERSE")).Post("/{expenseId}/reverse", expensesHandler.ReverseExpense)
					} else {
						r.Post("/{expenseId}/reverse", expensesHandler.ReverseExpense)
					}
				})

				// Balances & Debt
				r.Get("/balances", balancesHandler.GetBalances)
				r.Get("/balances/pairwise", balancesHandler.GetPairwiseBalances)
				r.Get("/settlements/recommended", balancesHandler.GetRecommendedSettlements)

				// Settlements
				r.Route("/settlements", func(r chi.Router) {
					if pool != nil {
						r.With(middleware.RequireIdempotency(pool, "SETTLEMENT_RECORD")).Post("/", settlementsHandler.RecordSettlement)
					} else {
						r.Post("/", settlementsHandler.RecordSettlement)
					}
					r.Get("/", settlementsHandler.ListSettlements)

					// Confirm
					if pool != nil {
						r.With(middleware.RequireIdempotency(pool, "SETTLEMENT_CONFIRM")).Post("/{settlementId}/confirm", settlementsHandler.ConfirmSettlement)
						r.With(middleware.RequireIdempotency(pool, "SETTLEMENT_CANCEL")).Post("/{settlementId}/cancel", settlementsHandler.CancelSettlement)
					} else {
						r.Post("/{settlementId}/confirm", settlementsHandler.ConfirmSettlement)
						r.Post("/{settlementId}/cancel", settlementsHandler.CancelSettlement)
					}
				})

				// Activity Logs
				r.Get("/activity", activityHandler.ListActivity)

				// Zero-Knowledge Sync Mailbox (E2EE Push/Pull across Mumbai, Bangalore, Kashmir)
				r.Route("/sync", func(r chi.Router) {
					r.Post("/push", syncboxHandler.PushEnvelopes)
					r.Get("/pull", syncboxHandler.PullEnvelopes)
				})
			})
		})
	})

	// Authorized Real-Time WebSocket endpoint
	r.Get("/ws/groups/{groupId}", func(w http.ResponseWriter, r *http.Request) {
		groupID := chi.URLParam(r, "groupId")
		tokenStr := r.URL.Query().Get("token")
		if tokenStr == "" {
			tokenStr = r.Header.Get("Sec-WebSocket-Protocol")
		}

		claims, err := auth.ValidateToken(tokenStr)
		if err != nil {
			http.Error(w, "Unauthorized token", http.StatusUnauthorized)
			return
		}

		// Verify membership if pool is active
		if pool != nil {
			var status string
			err = pool.QueryRow(r.Context(),
				`SELECT status FROM group_members WHERE group_id = $1 AND user_id = $2`,
				groupID, claims.UserID,
			).Scan(&status)
			if err != nil || status != "ACTIVE" {
				http.Error(w, "Forbidden: not active member", http.StatusForbidden)
				return
			}
		} else {
			store := memstore.Get()
			store.RLock()
			member, exists := store.Members[groupID][claims.UserID]
			store.RUnlock()
			if !exists || member.Status != "ACTIVE" {
				http.Error(w, "Forbidden: not active member", http.StatusForbidden)
				return
			}
		}

		websocket.ServeWs(hub, w, r, claims.UserID, groupID)
	})

	// Start HTTP Server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	server := &http.Server{
		Addr:    ":" + port,
		Handler: r,
	}

	go func() {
		log.Printf("[Server] REST & WebSocket Server listening on http://localhost:%s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[Server FATAL] ListenAndServe: %v", err)
		}
	}()

	// Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("[Server] Shutting down server gracefully...")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("[Server ERROR] Server forced shutdown: %v", err)
	}
	log.Println("[Server] Server exited successfully.")
}
