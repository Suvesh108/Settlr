package ledger

import (
	"sort"
)

type balanceNode struct {
	userID string
	amount int64
}

// GenerateGreedySettlements generates a simplified, minimal-step group payment plan.
// Matches the largest creditor with the largest debtor iteratively.
func GenerateGreedySettlements(netBalances map[string]int64) []RecommendedTransfer {
	var creditors []balanceNode
	var debtors []balanceNode

	for u, b := range netBalances {
		if b > 0 {
			creditors = append(creditors, balanceNode{userID: u, amount: b})
		} else if b < 0 {
			debtors = append(debtors, balanceNode{userID: u, amount: -b}) // Store absolute positive debt
		}
	}

	// Deterministic sorting
	sort.Slice(creditors, func(i, j int) bool {
		if creditors[i].amount == creditors[j].amount {
			return creditors[i].userID < creditors[j].userID
		}
		return creditors[i].amount > creditors[j].amount
	})

	sort.Slice(debtors, func(i, j int) bool {
		if debtors[i].amount == debtors[j].amount {
			return debtors[i].userID < debtors[j].userID
		}
		return debtors[i].amount > debtors[j].amount
	})

	var recommendations []RecommendedTransfer
	cIdx, dIdx := 0, 0

	for cIdx < len(creditors) && dIdx < len(debtors) {
		creditor := &creditors[cIdx]
		debtor := &debtors[dIdx]

		transfer := creditor.amount
		if debtor.amount < transfer {
			transfer = debtor.amount
		}

		if transfer > 0 {
			recommendations = append(recommendations, RecommendedTransfer{
				FromUser: debtor.userID,
				ToUser:   creditor.userID,
				Amount:   transfer,
			})
		}

		creditor.amount -= transfer
		debtor.amount -= transfer

		if creditor.amount == 0 {
			cIdx++
		}
		if debtor.amount == 0 {
			dIdx++
		}
	}

	return recommendations
}
