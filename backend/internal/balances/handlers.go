package balances

import (
	"errors"
	"fmt"
	"net/http"

	"expense-tracker/backend/internal/ledger"
	"expense-tracker/backend/internal/memstore"
	"expense-tracker/backend/pkg/response"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Handler struct {
	pool *pgxpool.Pool
}

func NewHandler(pool *pgxpool.Pool) *Handler {
	return &Handler{pool: pool}
}

type UserBalanceResponse struct {
	UserID     string `json:"user_id"`
	Name       string `json:"name"`
	Email      string `json:"email"`
	NetBalance int64  `json:"net_balance"` // >0 creditor, <0 debtor
}

type PairwiseResponse struct {
	UserA       string `json:"user_a"`
	UserAName   string `json:"user_a_name"`
	UserB       string `json:"user_b"`
	UserBName   string `json:"user_b_name"`
	NetDebt     int64  `json:"net_debt"` // >0 means UserB owes UserA
	Explanation string `json:"explanation"`
}

type RecommendedResponse struct {
	FromUser     string `json:"from_user"`
	FromUserName string `json:"from_user_name"`
	ToUser       string `json:"to_user"`
	ToUserName   string `json:"to_user_name"`
	Amount       int64  `json:"amount"`
}

func (h *Handler) loadGroupState(r *http.Request, groupID string) ([]ledger.Expense, []ledger.Settlement, []string, map[string]string, int64, error) {
	if h.pool == nil {
		store := memstore.Get()
		store.RLock()
		defer store.RUnlock()

		grp, exists := store.Groups[groupID]
		if !exists {
			return nil, nil, nil, nil, 0, errors.New("group not found")
		}

		var memberIDs []string
		userNames := make(map[string]string)
		for _, m := range store.Members[groupID] {
			memberIDs = append(memberIDs, m.UserID)
			if u, uExists := store.Users[m.UserID]; uExists {
				userNames[m.UserID] = u.Name
			} else {
				userNames[m.UserID] = "Member"
			}
		}

		var expenses []ledger.Expense
		for _, e := range store.Expenses[groupID] {
			expenses = append(expenses, ledger.Expense{
				ID:                 e.ID,
				GroupID:            e.GroupID,
				PaidBy:             e.PaidBy,
				Amount:             e.Amount,
				Currency:           e.Currency,
				SplitType:          ledger.SplitType(e.SplitType),
				Participants:       e.Participants,
				IsReversal:         e.IsReversal,
				ReversesExpenseID:  e.ReversesExpenseID,
			})
		}
		activeExpenses := ledger.FilterActiveExpenses(expenses)

		var settlements []ledger.Settlement
		for _, s := range store.Settlements[groupID] {
			if s.Status == "CONFIRMED" {
				settlements = append(settlements, ledger.Settlement{
					ID:       s.ID,
					GroupID:  s.GroupID,
					FromUser: s.FromUser,
					ToUser:   s.ToUser,
					Amount:   s.Amount,
					Status:   ledger.SettlementConfirmed,
				})
			}
		}

		return activeExpenses, settlements, memberIDs, userNames, grp.LedgerVersion, nil
	}

	ctx := r.Context()

	// 1. Get ledger version
	var ledgerVersion int64
	err := h.pool.QueryRow(ctx, `SELECT ledger_version FROM groups WHERE id = $1`, groupID).Scan(&ledgerVersion)
	if err != nil {
		return nil, nil, nil, nil, 0, err
	}

	// 2. Fetch all members
	memberRows, err := h.pool.Query(ctx,
		`SELECT gm.user_id, u.name FROM group_members gm JOIN users u ON gm.user_id = u.id WHERE gm.group_id = $1`,
		groupID,
	)
	if err != nil {
		return nil, nil, nil, nil, 0, err
	}
	defer memberRows.Close()

	var memberIDs []string
	userNames := make(map[string]string)
	for memberRows.Next() {
		var uid, name string
		if err := memberRows.Scan(&uid, &name); err == nil {
			memberIDs = append(memberIDs, uid)
			userNames[uid] = name
		}
	}

	// 3. Fetch active expenses from canonical view
	expRows, err := h.pool.Query(ctx,
		`SELECT id, group_id, paid_by, amount, currency, split_type FROM v_active_expenses WHERE group_id = $1`,
		groupID,
	)
	if err != nil {
		return nil, nil, nil, nil, 0, err
	}
	defer expRows.Close()

	var expenses []ledger.Expense
	for expRows.Next() {
		var exp ledger.Expense
		var splitTypeStr string
		if err := expRows.Scan(&exp.ID, &exp.GroupID, &exp.PaidBy, &exp.Amount, &exp.Currency, &splitTypeStr); err == nil {
			exp.SplitType = ledger.SplitType(splitTypeStr)

			pRows, err := h.pool.Query(ctx,
				`SELECT user_id, share_amount FROM expense_participants WHERE expense_id = $1`,
				exp.ID,
			)
			if err == nil {
				for pRows.Next() {
					var p ledger.ParticipantShare
					if err := pRows.Scan(&p.UserID, &p.ShareAmount); err == nil {
						exp.Participants = append(exp.Participants, p)
					}
				}
				pRows.Close()
			}
			expenses = append(expenses, exp)
		}
	}

	// 4. Fetch confirmed settlements
	settleRows, err := h.pool.Query(ctx,
		`SELECT id, group_id, from_user, to_user, amount, status FROM settlements WHERE group_id = $1 AND status = 'CONFIRMED'`,
		groupID,
	)
	if err != nil {
		return nil, nil, nil, nil, 0, err
	}
	defer settleRows.Close()

	var settlements []ledger.Settlement
	for settleRows.Next() {
		var s ledger.Settlement
		var statusStr string
		if err := settleRows.Scan(&s.ID, &s.GroupID, &s.FromUser, &s.ToUser, &s.Amount, &statusStr); err == nil {
			s.Status = ledger.SettlementStatus(statusStr)
			settlements = append(settlements, s)
		}
	}

	return expenses, settlements, memberIDs, userNames, ledgerVersion, nil
}

func (h *Handler) GetBalances(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")
	expenses, settlements, memberIDs, userNames, version, err := h.loadGroupState(r, groupID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to compute balances")
		return
	}

	balances, err := ledger.CalculateNetBalances(expenses, settlements, memberIDs)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "LEDGER_CALCULATION_ERROR", err.Error())
		return
	}

	var results []UserBalanceResponse
	for _, uid := range memberIDs {
		results = append(results, UserBalanceResponse{
			UserID:     uid,
			Name:       userNames[uid],
			NetBalance: balances[uid],
		})
	}

	response.JSON(w, http.StatusOK, map[string]interface{}{
		"group_id":       groupID,
		"ledger_version": version,
		"balances":       results,
	})
}

func (h *Handler) GetPairwiseBalances(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")
	expenses, settlements, memberIDs, userNames, version, err := h.loadGroupState(r, groupID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to compute pairwise debts")
		return
	}

	debts := ledger.CalculatePairwiseDebts(expenses, settlements, memberIDs)

	var results []PairwiseResponse
	for _, d := range debts {
		nameA := userNames[d.UserA]
		nameB := userNames[d.UserB]
		var explanation string
		if d.NetDebt > 0 {
			explanation = fmt.Sprintf("%s owes %s", nameB, nameA)
		} else {
			explanation = fmt.Sprintf("%s owes %s", nameA, nameB)
		}

		results = append(results, PairwiseResponse{
			UserA:       d.UserA,
			UserAName:   nameA,
			UserB:       d.UserB,
			UserBName:   nameB,
			NetDebt:     d.NetDebt,
			Explanation: explanation,
		})
	}

	response.JSON(w, http.StatusOK, map[string]interface{}{
		"group_id":       groupID,
		"ledger_version": version,
		"pairwise":       results,
	})
}

func (h *Handler) GetRecommendedSettlements(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")
	expenses, settlements, memberIDs, userNames, version, err := h.loadGroupState(r, groupID)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to compute recommendations")
		return
	}

	balances, err := ledger.CalculateNetBalances(expenses, settlements, memberIDs)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "LEDGER_CALCULATION_ERROR", err.Error())
		return
	}

	transfers := ledger.GenerateGreedySettlements(balances)

	var results []RecommendedResponse
	for _, t := range transfers {
		results = append(results, RecommendedResponse{
			FromUser:     t.FromUser,
			FromUserName: userNames[t.FromUser],
			ToUser:       t.ToUser,
			ToUserName:   userNames[t.ToUser],
			Amount:       t.Amount,
		})
	}

	response.JSON(w, http.StatusOK, map[string]interface{}{
		"group_id":       groupID,
		"ledger_version": version,
		"transfers":      results,
	})
}
