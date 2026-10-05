package ledger

import (
	"testing"
)

func TestCalculateSplit_Equal(t *testing.T) {
	// ₹1.00 = 100 paise divided among 3 people: deterministic 34, 33, 33
	inputs := []ParticipantInput{
		{UserID: "user_c"},
		{UserID: "user_a"},
		{UserID: "user_b"},
	}

	shares, err := CalculateSplit(100, SplitEqual, inputs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(shares) != 3 {
		t.Fatalf("expected 3 shares, got %d", len(shares))
	}

	// Sorted by UserID: user_a gets 34, user_b gets 33, user_c gets 33
	expected := map[string]int64{
		"user_a": 34,
		"user_b": 33,
		"user_c": 33,
	}

	var sum int64
	for _, s := range shares {
		sum += s.ShareAmount
		if expected[s.UserID] != s.ShareAmount {
			t.Errorf("expected user %s to have share %d, got %d", s.UserID, expected[s.UserID], s.ShareAmount)
		}
	}

	if sum != 100 {
		t.Errorf("expected total sum 100, got %d", sum)
	}
}

func TestCalculateSplit_PercentageBasisPoints(t *testing.T) {
	// 33.33%, 33.33%, 33.34% -> 3333, 3333, 3334 basis points on ₹1,000 (100,000 paise)
	inputs := []ParticipantInput{
		{UserID: "user_1", BasisPoints: 3333},
		{UserID: "user_2", BasisPoints: 3333},
		{UserID: "user_3", BasisPoints: 3334},
	}

	shares, err := CalculateSplit(100_000, SplitPercentage, inputs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var sum int64
	for _, s := range shares {
		sum += s.ShareAmount
	}
	if sum != 100_000 {
		t.Errorf("expected exact sum 100000, got %d", sum)
	}
}

func TestCalculateSplit_Shares(t *testing.T) {
	// 2 shares, 1 share, 1 share on 400 paise
	inputs := []ParticipantInput{
		{UserID: "user_a", Shares: 2},
		{UserID: "user_b", Shares: 1},
		{UserID: "user_c", Shares: 1},
	}

	shares, err := CalculateSplit(400, SplitShares, inputs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	expected := map[string]int64{
		"user_a": 200,
		"user_b": 100,
		"user_c": 100,
	}
	var sum int64
	for _, s := range shares {
		sum += s.ShareAmount
		if s.ShareAmount != expected[s.UserID] {
			t.Errorf("user %s expected %d, got %d", s.UserID, expected[s.UserID], s.ShareAmount)
		}
	}
	if sum != 400 {
		t.Errorf("expected sum 400, got %d", sum)
	}
}

func TestZeroParticipantPayer_And_ReversalFlow(t *testing.T) {
	// Scenario: A pays ₹500 for B only (zero consumption by A)
	members := []string{"user_a", "user_b"}

	exp1 := Expense{
		ID:        "exp_1",
		GroupID:   "grp_1",
		PaidBy:    "user_a",
		Amount:    50000, // ₹500
		Currency:  "INR",
		SplitType: SplitExact,
		Participants: []ParticipantShare{
			{UserID: "user_b", ShareAmount: 50000},
		},
	}

	expenses := []Expense{exp1}
	active := FilterActiveExpenses(expenses)

	balances, err := CalculateNetBalances(active, nil, members)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if balances["user_a"] != 50000 {
		t.Errorf("expected user_a to be +50000, got %d", balances["user_a"])
	}
	if balances["user_b"] != -50000 {
		t.Errorf("expected user_b to be -50000, got %d", balances["user_b"])
	}

	// Pairwise check: UserB owes UserA ₹500 (PairwiseDebt(user_a, user_b) should be +50000)
	pairwise := CalculatePairwiseDebts(active, nil, members)
	if len(pairwise) != 1 {
		t.Fatalf("expected 1 pairwise record, got %d", len(pairwise))
	}
	if pairwise[0].NetDebt != 50000 {
		t.Errorf("expected pairwise net debt to be +50000, got %d", pairwise[0].NetDebt)
	}

	// Now B settles ₹500 to A: status CONFIRMED
	settlement := Settlement{
		ID:       "set_1",
		GroupID:  "grp_1",
		FromUser: "user_b",
		ToUser:   "user_a",
		Amount:   50000,
		Status:   SettlementConfirmed,
	}

	settlements := []Settlement{settlement}
	balancesAfterSettlement, err := CalculateNetBalances(active, settlements, members)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if balancesAfterSettlement["user_a"] != 0 || balancesAfterSettlement["user_b"] != 0 {
		t.Errorf("expected zero balances after settlement, got %+v", balancesAfterSettlement)
	}

	// NOW REVERSAL: Expense exp_1 is reversed!
	revID := "exp_1"
	reversalExp := Expense{
		ID:                "rev_1",
		GroupID:           "grp_1",
		PaidBy:            "user_a",
		Amount:            50000,
		Currency:          "INR",
		SplitType:         SplitExact,
		IsReversal:        true,
		ReversesExpenseID: &revID,
	}
	expenses = append(expenses, reversalExp)
	activeAfterReversal := FilterActiveExpenses(expenses)

	// In active expenses, exp_1 is now excluded because rev_1 reversed it!
	if len(activeAfterReversal) != 0 {
		t.Fatalf("expected 0 active expenses after reversal, got %d", len(activeAfterReversal))
	}

	// Recalculate balances: with 0 active expenses and 1 confirmed settlement B -> A of 50000:
	// B paid A 50000 when no debt existed, so B now has +50000 credit, and A has -50000 debt!
	balancesAfterReversal, err := CalculateNetBalances(activeAfterReversal, settlements, members)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if balancesAfterReversal["user_b"] != 50000 {
		t.Errorf("expected user_b to have credit +50000, got %d", balancesAfterReversal["user_b"])
	}
	if balancesAfterReversal["user_a"] != -50000 {
		t.Errorf("expected user_a to owe -50000, got %d", balancesAfterReversal["user_a"])
	}

	// Pairwise check: now user_a owes user_b ₹500!
	pairwiseAfterReversal := CalculatePairwiseDebts(activeAfterReversal, settlements, members)
	if len(pairwiseAfterReversal) != 1 {
		t.Fatalf("expected 1 pairwise record, got %d", len(pairwiseAfterReversal))
	}
	// NetDebt between user_a and user_b: NetDebt < 0 means user_a owes user_b
	if pairwiseAfterReversal[0].NetDebt != -50000 {
		t.Errorf("expected user_a to owe user_b -50000, got %d", pairwiseAfterReversal[0].NetDebt)
	}

	// Recommended settlement: A must now pay B ₹500!
	recommendations := GenerateGreedySettlements(balancesAfterReversal)
	if len(recommendations) != 1 {
		t.Fatalf("expected 1 recommended transfer, got %d", len(recommendations))
	}
	if recommendations[0].FromUser != "user_a" || recommendations[0].ToUser != "user_b" || recommendations[0].Amount != 50000 {
		t.Errorf("expected A -> B 50000 transfer, got %+v", recommendations[0])
	}
}

func TestGreedySettlement_ComplexGraph(t *testing.T) {
	// A: +500, B: +200, C: -400, D: -300
	netBalances := map[string]int64{
		"user_a": 50000,
		"user_b": 20000,
		"user_c": -40000,
		"user_d": -30000,
	}

	transfers := GenerateGreedySettlements(netBalances)

	var totalTransferred int64
	for _, tr := range transfers {
		totalTransferred += tr.Amount
	}

	// Total positive debt is 70000
	if totalTransferred != 70000 {
		t.Errorf("expected total transferred to be 70000, got %d", totalTransferred)
	}

	// Verify that applying these transfers completely zeros out all balances
	reconstructed := make(map[string]int64)
	for u, b := range netBalances {
		reconstructed[u] = b
	}
	for _, tr := range transfers {
		reconstructed[tr.FromUser] += tr.Amount
		reconstructed[tr.ToUser] -= tr.Amount
	}

	for u, b := range reconstructed {
		if b != 0 {
			t.Errorf("expected user %s to be zeroed out, got %d", u, b)
		}
	}
}

func TestPendingReservation(t *testing.T) {
	settlements := []Settlement{
		{
			ID:       "set_1",
			GroupID:  "grp_1",
			FromUser: "user_b",
			ToUser:   "user_a",
			Amount:   25000,
			Status:   SettlementPaymentRecorded,
		},
	}

	reserved := CalculatePendingReserved(settlements)
	if reserved["user_b"]["user_a"] != 25000 {
		t.Errorf("expected 25000 reserved from user_b to user_a, got %d", reserved["user_b"]["user_a"])
	}
}
