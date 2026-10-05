package ledger

import "errors"

// Currency minor units limit: 1,000,000,000 INR = 100,000,000,000 paise (10^11)
const MaxTransactionAmount int64 = 100_000_000_000

// SplitType defines supported allocation methods.
type SplitType string

const (
	SplitEqual      SplitType = "EQUAL"
	SplitExact      SplitType = "EXACT"
	SplitPercentage SplitType = "PERCENTAGE"
	SplitShares     SplitType = "SHARES"
)

// SettlementStatus defines the 3-stage settlement lifecycle.
type SettlementStatus string

const (
	SettlementPaymentRecorded SettlementStatus = "PAYMENT_RECORDED"
	SettlementConfirmed       SettlementStatus = "CONFIRMED"
	SettlementCancelled       SettlementStatus = "CANCELLED"
)

// ParticipantInput is received when creating or validating an expense split.
type ParticipantInput struct {
	UserID      string `json:"user_id"`
	ShareAmount int64  `json:"share_amount,omitempty"` // Used for EXACT
	BasisPoints int32  `json:"basis_points,omitempty"` // 100.00% = 10000 bps, used for PERCENTAGE
	Shares      int32  `json:"shares,omitempty"`       // Used for SHARES
}

// ParticipantShare represents the final calculated share stored in DB.
type ParticipantShare struct {
	UserID      string `json:"user_id"`
	ShareAmount int64  `json:"share_amount"`
	BasisPoints *int32 `json:"basis_points,omitempty"`
	Shares      *int32 `json:"shares,omitempty"`
}

// Expense represents an expense in the ledger engine.
type Expense struct {
	ID                 string             `json:"id"`
	GroupID            string             `json:"group_id"`
	PaidBy             string             `json:"paid_by"`
	Amount             int64              `json:"amount"`
	Currency           string             `json:"currency"`
	SplitType          SplitType          `json:"split_type"`
	Participants       []ParticipantShare `json:"participants"`
	IsReversal         bool               `json:"is_reversal"`
	ReversesExpenseID  *string            `json:"reverses_expense_id,omitempty"`
}

// Settlement represents a payment recorded between two users in a group.
type Settlement struct {
	ID        string           `json:"id"`
	GroupID   string           `json:"group_id"`
	FromUser  string           `json:"from_user"`
	ToUser    string           `json:"to_user"`
	Amount    int64            `json:"amount"`
	Status    SettlementStatus `json:"status"`
}

// PairwiseDetail reflects direct bilateral obligations.
type PairwiseDetail struct {
	UserA    string `json:"user_a"`
	UserB    string `json:"user_b"`
	NetDebt  int64  `json:"net_debt"` // > 0 means UserB owes UserA; < 0 means UserA owes UserB
}

// RecommendedTransfer represents a simplified transaction to settle group debts.
type RecommendedTransfer struct {
	FromUser string `json:"from_user"`
	ToUser   string `json:"to_user"`
	Amount   int64  `json:"amount"`
}

var (
	ErrInvalidAmount          = errors.New("amount must be positive and within safe limits")
	ErrEmptyParticipants      = errors.New("expense must have at least one participant")
	ErrDuplicateParticipant   = errors.New("duplicate participant found")
	ErrSumMismatch            = errors.New("participant shares sum does not match expense amount")
	ErrInvalidBasisPoints     = errors.New("percentage split must total exactly 10,000 basis points")
	ErrInvalidShares          = errors.New("shares must be positive integers")
	ErrZeroTotalShares        = errors.New("total shares must be greater than zero")
	ErrInvariantViolation     = errors.New("ledger zero-sum invariant violated")
	ErrZeroShareDisallowed    = errors.New("participant share must be greater than zero")
	ErrInvalidSplitType       = errors.New("unsupported split type")
)
