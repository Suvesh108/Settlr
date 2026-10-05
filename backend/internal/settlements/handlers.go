package settlements

import (
	"encoding/json"
	"net/http"
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

type RecordSettlementRequest struct {
	ToUser string `json:"to_user"`
	Amount int64  `json:"amount"` // Minor units (paise)
}

type SettlementResponse struct {
	ID           string     `json:"id"`
	GroupID      string     `json:"group_id"`
	FromUser     string     `json:"from_user"`
	FromUserName string     `json:"from_user_name,omitempty"`
	ToUser       string     `json:"to_user"`
	ToUserName   string     `json:"to_user_name,omitempty"`
	Amount       int64      `json:"amount"`
	Status       string     `json:"status"`
	RecordedBy   string     `json:"recorded_by"`
	ConfirmedBy  *string    `json:"confirmed_by,omitempty"`
	CancelledBy  *string    `json:"cancelled_by,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	ConfirmedAt  *time.Time `json:"confirmed_at,omitempty"`
	CancelledAt  *time.Time `json:"cancelled_at,omitempty"`
}

func (h *Handler) RecordSettlement(w http.ResponseWriter, r *http.Request) {
	debtorID, _ := middleware.GetUserID(r.Context())
	groupID := chi.URLParam(r, "groupId")

	var req RecordSettlementRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "INVALID_BODY", "Malformed request body")
		return
	}

	if req.ToUser == "" || req.ToUser == debtorID || req.Amount <= 0 || req.Amount > ledger.MaxTransactionAmount {
		response.Error(w, http.StatusBadRequest, "VALIDATION_FAILED", "Valid creditor and positive amount required")
		return
	}

	var settlementID string
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
		grp.LedgerVersion++
		newLedgerVersion = grp.LedgerVersion

		settlementID = uuid.NewString()
		rec := &memstore.SettlementRecord{
			ID:         settlementID,
			GroupID:    groupID,
			FromUser:   debtorID,
			ToUser:     req.ToUser,
			Amount:     req.Amount,
			Status:     "PAYMENT_RECORDED",
			RecordedBy: debtorID,
			CreatedAt:  time.Now(),
		}
		store.Settlements[groupID] = append([]*memstore.SettlementRecord{rec}, store.Settlements[groupID]...)

		store.Activities[groupID] = append([]*memstore.ActivityRecord{
			{
				ID:        uuid.NewString(),
				GroupID:   groupID,
				ActorID:   debtorID,
				Action:    "PAYMENT_RECORDED",
				Summary:   "Recorded payment claim",
				CreatedAt: time.Now(),
			},
		}, store.Activities[groupID]...)
		store.Unlock()
	} else {
		err := database.RunInTx(r.Context(), h.pool, func(tx pgx.Tx) error {
			u1, u2 := debtorID, req.ToUser
			if u1 > u2 {
				u1, u2 = u2, u1
			}
			rows, err := tx.Query(r.Context(),
				`SELECT user_id, status FROM group_members WHERE group_id = $1 AND user_id IN ($2, $3) ORDER BY user_id FOR UPDATE`,
				groupID, u1, u2,
			)
			if err != nil {
				return err
			}
			var lockedMembers int
			for rows.Next() {
				var uid, status string
				if err := rows.Scan(&uid, &status); err == nil && status == "ACTIVE" {
					lockedMembers++
				}
			}
			rows.Close()
			if lockedMembers != 2 {
				return pgx.ErrNoRows
			}

			err = tx.QueryRow(r.Context(),
				`INSERT INTO settlements (group_id, from_user, to_user, amount, status, recorded_by)
				 VALUES ($1, $2, $3, $4, 'PAYMENT_RECORDED', $5)
				 RETURNING id`,
				groupID, debtorID, req.ToUser, req.Amount, debtorID,
			).Scan(&settlementID)
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
				 VALUES ($1, $2, 'PAYMENT_RECORDED', 'Payment recorded', $3)`,
				groupID, debtorID, map[string]interface{}{"settlement_id": settlementID, "amount": req.Amount},
			)
			return err
		})

		if err != nil {
			response.Error(w, http.StatusBadRequest, "SETTLEMENT_RECORD_FAILED", "Failed to record settlement: "+err.Error())
			return
		}
	}

	h.hub.Broadcast(groupID, "settlement.recorded", map[string]interface{}{
		"settlement_id":  settlementID,
		"from_user":      debtorID,
		"to_user":        req.ToUser,
		"amount":         req.Amount,
		"ledger_version": newLedgerVersion,
	})

	response.JSON(w, http.StatusCreated, map[string]interface{}{
		"id":             settlementID,
		"status":         "PAYMENT_RECORDED",
		"ledger_version": newLedgerVersion,
	})
}

func (h *Handler) ConfirmSettlement(w http.ResponseWriter, r *http.Request) {
	creditorID, _ := middleware.GetUserID(r.Context())
	groupID := chi.URLParam(r, "groupId")
	settlementID := chi.URLParam(r, "settlementId")

	var newLedgerVersion int64

	if h.pool == nil {
		store := memstore.Get()
		store.Lock()
		var found *memstore.SettlementRecord
		for _, s := range store.Settlements[groupID] {
			if s.ID == settlementID {
				found = s
				break
			}
		}
		if found == nil || found.Status != "PAYMENT_RECORDED" || found.ToUser != creditorID {
			store.Unlock()
			response.Error(w, http.StatusBadRequest, "CONFIRM_FAILED", "Settlement cannot be confirmed")
			return
		}

		now := time.Now()
		found.Status = "CONFIRMED"
		found.ConfirmedBy = &creditorID
		found.ConfirmedAt = &now

		grp := store.Groups[groupID]
		if grp != nil {
			grp.LedgerVersion++
			newLedgerVersion = grp.LedgerVersion
		}

		store.Activities[groupID] = append([]*memstore.ActivityRecord{
			{
				ID:        uuid.NewString(),
				GroupID:   groupID,
				ActorID:   creditorID,
				Action:    "PAYMENT_CONFIRMED",
				Summary:   "Payment confirmed by receiver",
				CreatedAt: time.Now(),
			},
		}, store.Activities[groupID]...)
		store.Unlock()
	} else {
		err := database.RunInTx(r.Context(), h.pool, func(tx pgx.Tx) error {
			var s SettlementResponse
			err := tx.QueryRow(r.Context(),
				`SELECT id, group_id, from_user, to_user, amount, status 
				 FROM settlements 
				 WHERE id = $1 AND group_id = $2 FOR UPDATE`,
				settlementID, groupID,
			).Scan(&s.ID, &s.GroupID, &s.FromUser, &s.ToUser, &s.Amount, &s.Status)
			if err != nil {
				return err
			}

			if s.Status != "PAYMENT_RECORDED" || s.ToUser != creditorID {
				return pgx.ErrNoRows
			}

			_, err = tx.Exec(r.Context(),
				`UPDATE settlements 
				 SET status = 'CONFIRMED', confirmed_by = $1, confirmed_at = NOW(), updated_at = NOW() 
				 WHERE id = $2`,
				creditorID, settlementID,
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
				 VALUES ($1, $2, 'PAYMENT_CONFIRMED', 'Payment confirmed by receiver', $3)`,
				groupID, creditorID, map[string]interface{}{"settlement_id": settlementID, "amount": s.Amount},
			)
			return err
		})

		if err != nil {
			response.Error(w, http.StatusBadRequest, "CONFIRM_FAILED", "Failed to confirm settlement")
			return
		}
	}

	h.hub.Broadcast(groupID, "settlement.confirmed", map[string]interface{}{
		"settlement_id":  settlementID,
		"ledger_version": newLedgerVersion,
	})

	response.JSON(w, http.StatusOK, map[string]interface{}{
		"id":             settlementID,
		"status":         "CONFIRMED",
		"ledger_version": newLedgerVersion,
	})
}

func (h *Handler) CancelSettlement(w http.ResponseWriter, r *http.Request) {
	callerID, _ := middleware.GetUserID(r.Context())
	groupID := chi.URLParam(r, "groupId")
	settlementID := chi.URLParam(r, "settlementId")

	var newLedgerVersion int64

	if h.pool == nil {
		store := memstore.Get()
		store.Lock()
		var found *memstore.SettlementRecord
		for _, s := range store.Settlements[groupID] {
			if s.ID == settlementID {
				found = s
				break
			}
		}
		if found == nil || found.Status != "PAYMENT_RECORDED" || (found.FromUser != callerID && found.ToUser != callerID) {
			store.Unlock()
			response.Error(w, http.StatusBadRequest, "CANCEL_FAILED", "Settlement cannot be cancelled")
			return
		}

		now := time.Now()
		found.Status = "CANCELLED"
		found.CancelledBy = &callerID
		found.CancelledAt = &now

		grp := store.Groups[groupID]
		if grp != nil {
			grp.LedgerVersion++
			newLedgerVersion = grp.LedgerVersion
		}

		store.Activities[groupID] = append([]*memstore.ActivityRecord{
			{
				ID:        uuid.NewString(),
				GroupID:   groupID,
				ActorID:   callerID,
				Action:    "PAYMENT_CANCELLED",
				Summary:   "Payment cancelled",
				CreatedAt: time.Now(),
			},
		}, store.Activities[groupID]...)
		store.Unlock()
	} else {
		err := database.RunInTx(r.Context(), h.pool, func(tx pgx.Tx) error {
			var s SettlementResponse
			err := tx.QueryRow(r.Context(),
				`SELECT id, group_id, from_user, to_user, amount, status 
				 FROM settlements 
				 WHERE id = $1 AND group_id = $2 FOR UPDATE`,
				settlementID, groupID,
			).Scan(&s.ID, &s.GroupID, &s.FromUser, &s.ToUser, &s.Amount, &s.Status)
			if err != nil {
				return err
			}

			if s.Status != "PAYMENT_RECORDED" || (callerID != s.FromUser && callerID != s.ToUser) {
				return pgx.ErrNoRows
			}

			_, err = tx.Exec(r.Context(),
				`UPDATE settlements 
				 SET status = 'CANCELLED', cancelled_by = $1, cancelled_at = NOW(), updated_at = NOW() 
				 WHERE id = $2`,
				callerID, settlementID,
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
				 VALUES ($1, $2, 'PAYMENT_CANCELLED', 'Payment cancelled', $3)`,
				groupID, callerID, map[string]interface{}{"settlement_id": settlementID},
			)
			return err
		})

		if err != nil {
			response.Error(w, http.StatusBadRequest, "CANCEL_FAILED", "Failed to cancel settlement")
			return
		}
	}

	h.hub.Broadcast(groupID, "settlement.cancelled", map[string]interface{}{
		"settlement_id":  settlementID,
		"ledger_version": newLedgerVersion,
	})

	response.JSON(w, http.StatusOK, map[string]interface{}{
		"id":             settlementID,
		"status":         "CANCELLED",
		"ledger_version": newLedgerVersion,
	})
}

func (h *Handler) ListSettlements(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")

	var list []SettlementResponse

	if h.pool == nil {
		store := memstore.Get()
		store.RLock()
		for _, s := range store.Settlements[groupID] {
			fName := "Member"
			tName := "Member"
			if u, exists := store.Users[s.FromUser]; exists {
				fName = u.Name
			}
			if u, exists := store.Users[s.ToUser]; exists {
				tName = u.Name
			}
			list = append(list, SettlementResponse{
				ID:           s.ID,
				GroupID:      s.GroupID,
				FromUser:     s.FromUser,
				FromUserName: fName,
				ToUser:       s.ToUser,
				ToUserName:   tName,
				Amount:       s.Amount,
				Status:       s.Status,
				RecordedBy:   s.RecordedBy,
				ConfirmedBy:  s.ConfirmedBy,
				CancelledBy:  s.CancelledBy,
				CreatedAt:    s.CreatedAt,
				ConfirmedAt:  s.ConfirmedAt,
				CancelledAt:  s.CancelledAt,
			})
		}
		store.RUnlock()
	} else {
		rows, err := h.pool.Query(r.Context(),
			`SELECT s.id, s.group_id, s.from_user, u1.name, s.to_user, u2.name, 
			        s.amount, s.status, s.recorded_by, s.confirmed_by, s.cancelled_by, 
			        s.created_at, s.confirmed_at, s.cancelled_at
			 FROM settlements s
			 JOIN users u1 ON s.from_user = u1.id
			 JOIN users u2 ON s.to_user = u2.id
			 WHERE s.group_id = $1
			 ORDER BY s.created_at DESC`,
			groupID,
		)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to fetch settlements")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var s SettlementResponse
			err := rows.Scan(
				&s.ID, &s.GroupID, &s.FromUser, &s.FromUserName, &s.ToUser, &s.ToUserName,
				&s.Amount, &s.Status, &s.RecordedBy, &s.ConfirmedBy, &s.CancelledBy,
				&s.CreatedAt, &s.ConfirmedAt, &s.CancelledAt,
			)
			if err == nil {
				list = append(list, s)
			}
		}
	}

	response.JSON(w, http.StatusOK, list)
}
