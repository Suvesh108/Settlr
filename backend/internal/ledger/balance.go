package ledger

import (
	"sort"
)

// FilterActiveExpenses extracts non-reversed and non-reversal expenses.
func FilterActiveExpenses(expenses []Expense) []Expense {
	reversedIDs := make(map[string]struct{})
	for _, e := range expenses {
		if e.IsReversal && e.ReversesExpenseID != nil {
			reversedIDs[*e.ReversesExpenseID] = struct{}{}
		}
	}

	var active []Expense
	for _, e := range expenses {
		if e.IsReversal {
			continue
		}
		if _, wasReversed := reversedIDs[e.ID]; wasReversed {
			continue
		}
		active = append(active, e)
	}
	return active
}

// CalculateNetBalances computes the net position of every member in the group.
// Positive: User is a creditor (should receive money).
// Negative: User is a debtor (needs to pay money).
func CalculateNetBalances(activeExpenses []Expense, confirmedSettlements []Settlement, members []string) (map[string]int64, error) {
	balances := make(map[string]int64, len(members))
	for _, m := range members {
		balances[m] = 0
	}

	for _, e := range activeExpenses {
		balances[e.PaidBy] += e.Amount
		for _, p := range e.Participants {
			balances[p.UserID] -= p.ShareAmount
		}
	}

	for _, s := range confirmedSettlements {
		if s.Status != SettlementConfirmed {
			continue
		}
		balances[s.FromUser] += s.Amount
		balances[s.ToUser] -= s.Amount
	}

	// Verify the fundamental zero-sum invariant
	var totalSum int64
	for _, b := range balances {
		totalSum += b
	}
	if totalSum != 0 {
		return nil, ErrInvariantViolation
	}

	return balances, nil
}

// CalculatePairwiseDebts calculates direct bilateral debts between all pairs of members.
// Sign convention: If NetDebt > 0, UserB owes UserA. If NetDebt < 0, UserA owes UserB.
func CalculatePairwiseDebts(activeExpenses []Expense, confirmedSettlements []Settlement, members []string) []PairwiseDetail {
	// grossDebt[A][B] = amount that B owes A directly
	grossDebt := make(map[string]map[string]int64)
	for _, m := range members {
		grossDebt[m] = make(map[string]int64)
	}

	for _, e := range activeExpenses {
		payer := e.PaidBy
		for _, p := range e.Participants {
			if p.UserID == payer {
				continue
			}
			if grossDebt[payer] == nil {
				grossDebt[payer] = make(map[string]int64)
			}
			grossDebt[payer][p.UserID] += p.ShareAmount
		}
	}

	for _, s := range confirmedSettlements {
		if s.Status != SettlementConfirmed {
			continue
		}
		if grossDebt[s.ToUser] == nil {
			grossDebt[s.ToUser] = make(map[string]int64)
		}
		// Settlement payment from B to A directly offsets what B owes A
		grossDebt[s.ToUser][s.FromUser] -= s.Amount
	}

	sortedMembers := make([]string, len(members))
	copy(sortedMembers, members)
	sort.Strings(sortedMembers)

	var details []PairwiseDetail
	for i := 0; i < len(sortedMembers); i++ {
		for j := i + 1; j < len(sortedMembers); j++ {
			uA := sortedMembers[i]
			uB := sortedMembers[j]

			bOwesA := int64(0)
			if grossDebt[uA] != nil {
				bOwesA = grossDebt[uA][uB]
			}

			aOwesB := int64(0)
			if grossDebt[uB] != nil {
				aOwesB = grossDebt[uB][uA]
			}

			net := bOwesA - aOwesB
			if net != 0 {
				details = append(details, PairwiseDetail{
					UserA:   uA,
					UserB:   uB,
					NetDebt: net,
				})
			}
		}
	}

	return details
}

// CalculatePendingReserved amounts for all pairs where status is PAYMENT_RECORDED.
func CalculatePendingReserved(settlements []Settlement) map[string]map[string]int64 {
	reserved := make(map[string]map[string]int64)
	for _, s := range settlements {
		if s.Status != SettlementPaymentRecorded {
			continue
		}
		if reserved[s.FromUser] == nil {
			reserved[s.FromUser] = make(map[string]int64)
		}
		reserved[s.FromUser][s.ToUser] += s.Amount
	}
	return reserved
}
