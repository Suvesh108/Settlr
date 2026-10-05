package expenses

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"expense-tracker/backend/database"
	"expense-tracker/backend/internal/ledger"
	"expense-tracker/backend/internal/memstore"
	"expense-tracker/backend/internal/middleware"
	"expense-tracker/backend/internal/websocket"
	"expense-tracker/backend/pkg/response"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Handler struct {
	pool *pgxpool.Pool
	hub  *websocket.Hub
}

func NewHandler(pool *pgxpool.Pool, hub *websocket.Hub) *Handler {
	return &Handler{pool: pool, hub: hub}
}

type CreateExpenseRequest struct {
	Amount       int64                     `json:"amount"` // Minor units (e.g. paise)
	Description  string                    `json:"description"`
	Category     string                    `json:"category"`
	PaidBy       string                    `json:"paid_by"`
	SplitType    ledger.SplitType          `json:"split_type"`
	Participants []ledger.ParticipantInput `json:"participants"`
}

type ExpenseDetailResponse struct {
	ID                 string                    `json:"id"`
	GroupID            string                    `json:"group_id"`
	PaidBy             string                    `json:"paid_by"`
	PayerName          string                    `json:"payer_name,omitempty"`
	Amount             int64                     `json:"amount"`
	Currency           string                    `json:"currency"`
	Description        string                    `json:"description"`
	Category           string                    `json:"category"`
	SplitType          string                    `json:"split_type"`
	ExpenseDate        time.Time                 `json:"expense_date"`
	IsReversal         bool                      `json:"is_reversal"`
	IsReversed         bool                      `json:"is_reversed"`
	ReversesExpenseID  *string                   `json:"reverses_expense_id,omitempty"`
	CreatedBy          string                    `json:"created_by"`
	CreatedAt          time.Time                 `json:"created_at"`
	Participants       []ledger.ParticipantShare `json:"participants"`
}

func (h *Handler) CreateExpense(w http.ResponseWriter, r *http.Request) {
	userID, _ := middleware.GetUserID(r.Context())
	groupID := chi.URLParam(r, "groupId")

	var req CreateExpenseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "INVALID_BODY", "Malformed request body")
		return
	}

	req.Description = strings.TrimSpace(req.Description)
	if req.Description == "" || req.Amount <= 0 || req.Amount > ledger.MaxTransactionAmount {
		response.Error(w, http.StatusBadRequest, "VALIDATION_FAILED", "Valid description and positive amount are required")
		return
	}
	if req.PaidBy == "" {
		req.PaidBy = userID
	}
	if req.Category == "" {
		req.Category = "GENERAL"
	}

	calculatedShares, err := ledger.CalculateSplit(req.Amount, req.SplitType, req.Participants)
	if err != nil {
		response.Error(w, http.StatusBadRequest, "SPLIT_CALCULATION_ERROR", err.Error())
		return
	}

	var expenseID string
	var groupCurrency string
	var newLedgerVersion int64

	if h.pool == nil {
		store := memstore.Get()
		store.Lock()
		grp, exists := store.Groups[groupID]
		if !exists {
			store.Unlock()
			response.Error(w, http.StatusNotFound, "NOT_FOUND", "Group not found")
			return
		}
		groupCurrency = grp.Currency
		grp.LedgerVersion++
		newLedgerVersion = grp.LedgerVersion

		expenseID = uuid.NewString()
		rec := &memstore.ExpenseRecord{
			ID:           expenseID,
			GroupID:      groupID,
			PaidBy:       req.PaidBy,
			Amount:       req.Amount,
			Currency:     groupCurrency,
			Description:  req.Description,
			Category:     req.Category,
			SplitType:    string(req.SplitType),
			ExpenseDate:  time.Now(),
			CreatedBy:    userID,
			CreatedAt:    time.Now(),
			Participants: calculatedShares,
		}
		store.Expenses[groupID] = append([]*memstore.ExpenseRecord{rec}, store.Expenses[groupID]...)

		store.Activities[groupID] = append([]*memstore.ActivityRecord{
			{
				ID:        uuid.NewString(),
				GroupID:   groupID,
				ActorID:   userID,
				Action:    "EXPENSE_CREATED",
				Summary:   "Added expense: " + req.Description,
				CreatedAt: time.Now(),
			},
		}, store.Activities[groupID]...)
		store.Unlock()
	} else {
		err = database.RunInTx(r.Context(), h.pool, func(tx pgx.Tx) error {
			err := tx.QueryRow(r.Context(),
				`SELECT currency FROM groups WHERE id = $1 FOR UPDATE`,
				groupID,
			).Scan(&groupCurrency)
			if err != nil {
				return err
			}

			var payerStatus string
			err = tx.QueryRow(r.Context(),
				`SELECT status FROM group_members WHERE group_id = $1 AND user_id = $2`,
				groupID, req.PaidBy,
			).Scan(&payerStatus)
			if err != nil || payerStatus != "ACTIVE" {
				return pgx.ErrNoRows
			}

			for _, p := range calculatedShares {
				var pStatus string
				err = tx.QueryRow(r.Context(),
					`SELECT status FROM group_members WHERE group_id = $1 AND user_id = $2`,
					groupID, p.UserID,
				).Scan(&pStatus)
				if err != nil || pStatus != "ACTIVE" {
					return pgx.ErrNoRows
				}
			}

			err = tx.QueryRow(r.Context(),
				`INSERT INTO expenses (group_id, paid_by, amount, currency, description, category, split_type, created_by)
				 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
				 RETURNING id`,
				groupID, req.PaidBy, req.Amount, groupCurrency, req.Description, req.Category, string(req.SplitType), userID,
			).Scan(&expenseID)
			if err != nil {
				return err
			}

			for _, p := range calculatedShares {
				_, err = tx.Exec(r.Context(),
					`INSERT INTO expense_participants (expense_id, user_id, share_amount, basis_points, shares)
					 VALUES ($1, $2, $3, $4, $5)`,
					expenseID, p.UserID, p.ShareAmount, p.BasisPoints, p.Shares,
				)
				if err != nil {
					return err
				}
			}

			err = tx.QueryRow(r.Context(),
				`UPDATE groups SET ledger_version = ledger_version + 1, updated_at = NOW() WHERE id = $1 RETURNING ledger_version`,
				groupID,
			).Scan(&newLedgerVersion)
			if err != nil {
				return err
			}

			_, err = tx.Exec(r.Context(),
				`INSERT INTO activity_logs (group_id, actor_id, action, summary, metadata)
				 VALUES ($1, $2, 'EXPENSE_CREATED', $3, $4)`,
				groupID, userID, "Added expense: "+req.Description,
				map[string]interface{}{"expense_id": expenseID, "amount": req.Amount},
			)
			return err
		})

		if err != nil {
			response.Error(w, http.StatusBadRequest, "EXPENSE_CREATION_FAILED", "Failed to create expense: "+err.Error())
			return
		}
	}

	h.hub.Broadcast(groupID, "expense.created", map[string]interface{}{
		"expense_id":     expenseID,
		"amount":         req.Amount,
		"ledger_version": newLedgerVersion,
	})

	response.JSON(w, http.StatusCreated, map[string]interface{}{
		"id":             expenseID,
		"group_id":       groupID,
		"amount":         req.Amount,
		"currency":       groupCurrency,
		"ledger_version": newLedgerVersion,
		"participants":   calculatedShares,
	})
}

func (h *Handler) ListExpenses(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")

	var expensesList []ExpenseDetailResponse

	if h.pool == nil {
		store := memstore.Get()
		store.RLock()
		for _, e := range store.Expenses[groupID] {
			pName := "Member"
			if u, exists := store.Users[e.PaidBy]; exists {
				pName = u.Name
			}
			expensesList = append(expensesList, ExpenseDetailResponse{
				ID:                e.ID,
				GroupID:           e.GroupID,
				PaidBy:            e.PaidBy,
				PayerName:         pName,
				Amount:            e.Amount,
				Currency:          e.Currency,
				Description:       e.Description,
				Category:          e.Category,
				SplitType:         e.SplitType,
				ExpenseDate:       e.ExpenseDate,
				IsReversal:        e.IsReversal,
				IsReversed:        e.IsReversed,
				ReversesExpenseID: e.ReversesExpenseID,
				CreatedBy:         e.CreatedBy,
				CreatedAt:         e.CreatedAt,
				Participants:      e.Participants,
			})
		}
		store.RUnlock()
	} else {
		rows, err := h.pool.Query(r.Context(),
			`SELECT e.id, e.group_id, e.paid_by, u.name, e.amount, e.currency, e.description, 
			        e.category, e.split_type, e.expense_date, e.is_reversal, e.is_reversed, 
			        e.reverses_expense_id, e.created_by, e.created_at
			 FROM expenses e
			 JOIN users u ON e.paid_by = u.id
			 WHERE e.group_id = $1
			 ORDER BY e.created_at DESC`,
			groupID,
		)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to fetch expenses")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var exp ExpenseDetailResponse
			err := rows.Scan(
				&exp.ID, &exp.GroupID, &exp.PaidBy, &exp.PayerName, &exp.Amount, &exp.Currency,
				&exp.Description, &exp.Category, &exp.SplitType, &exp.ExpenseDate,
				&exp.IsReversal, &exp.IsReversed, &exp.ReversesExpenseID, &exp.CreatedBy, &exp.CreatedAt,
			)
			if err != nil {
				continue
			}

			pRows, err := h.pool.Query(r.Context(),
				`SELECT user_id, share_amount, basis_points, shares FROM expense_participants WHERE expense_id = $1`,
				exp.ID,
			)
			if err == nil {
				for pRows.Next() {
					var p ledger.ParticipantShare
					if err := pRows.Scan(&p.UserID, &p.ShareAmount, &p.BasisPoints, &p.Shares); err == nil {
						exp.Participants = append(exp.Participants, p)
					}
				}
				pRows.Close()
			}

			expensesList = append(expensesList, exp)
		}
	}

	response.JSON(w, http.StatusOK, expensesList)
}

func (h *Handler) ReverseExpense(w http.ResponseWriter, r *http.Request) {
	userID, _ := middleware.GetUserID(r.Context())
	groupID := chi.URLParam(r, "groupId")
	expenseID := chi.URLParam(r, "expenseId")

	var reversalID string
	var newLedgerVersion int64

	if h.pool == nil {
		store := memstore.Get()
		store.Lock()
		var orig *memstore.ExpenseRecord
		for _, e := range store.Expenses[groupID] {
			if e.ID == expenseID {
				orig = e
				break
			}
		}
		if orig == nil || orig.IsReversed || orig.IsReversal {
			store.Unlock()
			response.Error(w, http.StatusBadRequest, "REVERSAL_FAILED", "Expense cannot be reversed")
			return
		}

		orig.IsReversed = true
		reversalID = uuid.NewString()
		revRecord := &memstore.ExpenseRecord{
			ID:                reversalID,
			GroupID:           groupID,
			PaidBy:            orig.PaidBy,
			Amount:            orig.Amount,
			Currency:          orig.Currency,
			Description:       "Reversal: " + orig.Description,
			Category:          orig.Category,
			SplitType:         orig.SplitType,
			ExpenseDate:       time.Now(),
			IsReversal:        true,
			ReversesExpenseID: &orig.ID,
			CreatedBy:         userID,
			CreatedAt:         time.Now(),
			Participants:      orig.Participants,
		}
		store.Expenses[groupID] = append([]*memstore.ExpenseRecord{revRecord}, store.Expenses[groupID]...)

		grp := store.Groups[groupID]
		if grp != nil {
			grp.LedgerVersion++
			newLedgerVersion = grp.LedgerVersion
		}

		store.Activities[groupID] = append([]*memstore.ActivityRecord{
			{
				ID:        uuid.NewString(),
				GroupID:   groupID,
				ActorID:   userID,
				Action:    "EXPENSE_REVERSED",
				Summary:   "Reversed expense: " + orig.Description,
				CreatedAt: time.Now(),
			},
		}, store.Activities[groupID]...)
		store.Unlock()
	} else {
		err := database.RunInTx(r.Context(), h.pool, func(tx pgx.Tx) error {
			var orig ExpenseDetailResponse
			err := tx.QueryRow(r.Context(),
				`SELECT id, group_id, paid_by, amount, currency, description, category, split_type, is_reversal, is_reversed, created_by
				 FROM expenses WHERE id = $1 AND group_id = $2 FOR UPDATE`,
				expenseID, groupID,
			).Scan(
				&orig.ID, &orig.GroupID, &orig.PaidBy, &orig.Amount, &orig.Currency,
				&orig.Description, &orig.Category, &orig.SplitType, &orig.IsReversal, &orig.IsReversed, &orig.CreatedBy,
			)
			if err != nil {
				return err
			}

			if orig.IsReversal || orig.IsReversed {
				return pgx.ErrNoRows
			}

			var userRole string
			_ = tx.QueryRow(r.Context(),
				`SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2 AND status = 'ACTIVE'`,
				groupID, userID,
			).Scan(&userRole)

			isAuthorized := (userID == orig.PaidBy) || (userID == orig.CreatedBy) || (userRole == "OWNER" || userRole == "ADMIN")
			if !isAuthorized {
				return pgx.ErrNoRows
			}

			var inactiveCount int
			err = tx.QueryRow(r.Context(),
				`SELECT COUNT(*) FROM group_members 
				 WHERE group_id = $1 AND status != 'ACTIVE' 
				   AND user_id IN (
				       SELECT user_id FROM expense_participants WHERE expense_id = $2
				       UNION SELECT $3::uuid
				   )`,
				groupID, expenseID, orig.PaidBy,
			).Scan(&inactiveCount)
			if err != nil || inactiveCount > 0 {
				return pgx.ErrNoRows
			}

			_, err = tx.Exec(r.Context(),
				`UPDATE expenses SET is_reversed = TRUE, updated_at = NOW() WHERE id = $1`,
				expenseID,
			)
			if err != nil {
				return err
			}

			revDesc := "Reversal: " + orig.Description
			err = tx.QueryRow(r.Context(),
				`INSERT INTO expenses (group_id, paid_by, amount, currency, description, category, split_type, is_reversal, reverses_expense_id, created_by)
				 VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE, $8, $9)
				 RETURNING id`,
				groupID, orig.PaidBy, orig.Amount, orig.Currency, revDesc, orig.Category, orig.SplitType, orig.ID, userID,
			).Scan(&reversalID)
			if err != nil {
				return err
			}

			_, err = tx.Exec(r.Context(),
				`INSERT INTO expense_participants (expense_id, user_id, share_amount, basis_points, shares)
				 SELECT $1, user_id, share_amount, basis_points, shares 
				 FROM expense_participants WHERE expense_id = $2`,
				reversalID, expenseID,
			)
			if err != nil {
				return err
			}

			err = tx.QueryRow(r.Context(),
				`UPDATE groups SET ledger_version = ledger_version + 1, updated_at = NOW() WHERE id = $1 RETURNING ledger_version`,
				groupID,
			).Scan(&newLedgerVersion)
			if err != nil {
				return err
			}

			_, err = tx.Exec(r.Context(),
				`INSERT INTO activity_logs (group_id, actor_id, action, summary, metadata)
				 VALUES ($1, $2, 'EXPENSE_REVERSED', $3, $4)`,
				groupID, userID, "Reversed expense: "+orig.Description,
				map[string]interface{}{"original_id": expenseID, "reversal_id": reversalID},
			)
			return err
		})

		if err != nil {
			response.Error(w, http.StatusBadRequest, "REVERSAL_FAILED", "Could not reverse expense")
			return
		}
	}

	h.hub.Broadcast(groupID, "expense.reversed", map[string]interface{}{
		"original_id":    expenseID,
		"reversal_id":    reversalID,
		"ledger_version": newLedgerVersion,
	})

	response.JSON(w, http.StatusOK, map[string]interface{}{
		"original_id":    expenseID,
		"reversal_id":    reversalID,
		"ledger_version": newLedgerVersion,
		"status":         "REVERSED",
	})
}
