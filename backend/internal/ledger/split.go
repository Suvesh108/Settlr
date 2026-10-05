package ledger

import (
	"sort"
)

// CalculateSplit validates and allocates shares deterministically for any SplitType.
func CalculateSplit(amount int64, splitType SplitType, inputs []ParticipantInput) ([]ParticipantShare, error) {
	if amount <= 0 || amount > MaxTransactionAmount {
		return nil, ErrInvalidAmount
	}
	if len(inputs) == 0 {
		return nil, ErrEmptyParticipants
	}

	// Verify no duplicate participant IDs
	seen := make(map[string]struct{}, len(inputs))
	for _, p := range inputs {
		if p.UserID == "" {
			return nil, ErrEmptyParticipants
		}
		if _, exists := seen[p.UserID]; exists {
			return nil, ErrDuplicateParticipant
		}
		seen[p.UserID] = struct{}{}
	}

	switch splitType {
	case SplitEqual:
		return calculateEqualSplit(amount, inputs)
	case SplitExact:
		return calculateExactSplit(amount, inputs)
	case SplitPercentage:
		return calculatePercentageSplit(amount, inputs)
	case SplitShares:
		return calculateSharesSplit(amount, inputs)
	default:
		return nil, ErrInvalidSplitType
	}
}

func calculateEqualSplit(amount int64, inputs []ParticipantInput) ([]ParticipantShare, error) {
	n := int64(len(inputs))
	base := amount / n
	rem := amount % n

	// Sort deterministically by UserID ascending
	sorted := make([]ParticipantInput, len(inputs))
	copy(sorted, inputs)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].UserID < sorted[j].UserID
	})

	result := make([]ParticipantShare, len(sorted))
	var totalAllocated int64
	for i, p := range sorted {
		share := base
		if int64(i) < rem {
			share++
		}
		if share <= 0 {
			return nil, ErrZeroShareDisallowed
		}
		result[i] = ParticipantShare{
			UserID:      p.UserID,
			ShareAmount: share,
		}
		totalAllocated += share
	}

	if totalAllocated != amount {
		return nil, ErrSumMismatch
	}
	return result, nil
}

func calculateExactSplit(amount int64, inputs []ParticipantInput) ([]ParticipantShare, error) {
	var totalAllocated int64
	result := make([]ParticipantShare, len(inputs))

	for i, p := range inputs {
		if p.ShareAmount <= 0 {
			return nil, ErrZeroShareDisallowed
		}
		result[i] = ParticipantShare{
			UserID:      p.UserID,
			ShareAmount: p.ShareAmount,
		}
		totalAllocated += p.ShareAmount
	}

	if totalAllocated != amount {
		return nil, ErrSumMismatch
	}
	return result, nil
}

func calculatePercentageSplit(amount int64, inputs []ParticipantInput) ([]ParticipantShare, error) {
	var totalBps int32
	for _, p := range inputs {
		if p.BasisPoints <= 0 {
			return nil, ErrZeroShareDisallowed
		}
		totalBps += p.BasisPoints
	}
	if totalBps != 10000 {
		return nil, ErrInvalidBasisPoints
	}

	type tempPct struct {
		input ParticipantInput
		base  int64
	}

	temps := make([]tempPct, len(inputs))
	var baseSum int64

	for i, p := range inputs {
		// Safe integer multiplication: amount <= 10^11, BasisPoints <= 10000 => product <= 10^15 (fits well in int64)
		baseShare := (amount * int64(p.BasisPoints)) / 10000
		temps[i] = tempPct{input: p, base: baseShare}
		baseSum += baseShare
	}

	rem := amount - baseSum

	// Sort remainder candidates by basis points descending, tie-break by UserID ascending
	sort.Slice(temps, func(i, j int) bool {
		if temps[i].input.BasisPoints == temps[j].input.BasisPoints {
			return temps[i].input.UserID < temps[j].input.UserID
		}
		return temps[i].input.BasisPoints > temps[j].input.BasisPoints
	})

	result := make([]ParticipantShare, len(temps))
	var totalAllocated int64

	for i, t := range temps {
		share := t.base
		if int64(i) < rem {
			share++
		}
		if share <= 0 {
			return nil, ErrZeroShareDisallowed
		}
		bps := t.input.BasisPoints
		result[i] = ParticipantShare{
			UserID:      t.input.UserID,
			ShareAmount: share,
			BasisPoints: &bps,
		}
		totalAllocated += share
	}

	if totalAllocated != amount {
		return nil, ErrSumMismatch
	}
	return result, nil
}

func calculateSharesSplit(amount int64, inputs []ParticipantInput) ([]ParticipantShare, error) {
	var totalShares int64
	for _, p := range inputs {
		if p.Shares <= 0 {
			return nil, ErrInvalidShares
		}
		totalShares += int64(p.Shares)
	}
	if totalShares <= 0 {
		return nil, ErrZeroTotalShares
	}

	type tempShare struct {
		input ParticipantInput
		base  int64
	}

	temps := make([]tempShare, len(inputs))
	var baseSum int64

	for i, p := range inputs {
		baseShare := (amount * int64(p.Shares)) / totalShares
		temps[i] = tempShare{input: p, base: baseShare}
		baseSum += baseShare
	}

	rem := amount - baseSum

	// Sort remainder candidates by shares descending, tie-break by UserID ascending
	sort.Slice(temps, func(i, j int) bool {
		if temps[i].input.Shares == temps[j].input.Shares {
			return temps[i].input.UserID < temps[j].input.UserID
		}
		return temps[i].input.Shares > temps[j].input.Shares
	})

	result := make([]ParticipantShare, len(temps))
	var totalAllocated int64

	for i, t := range temps {
		share := t.base
		if int64(i) < rem {
			share++
		}
		if share <= 0 {
			return nil, ErrZeroShareDisallowed
		}
		sh := t.input.Shares
		result[i] = ParticipantShare{
			UserID:      t.input.UserID,
			ShareAmount: share,
			Shares:      &sh,
		}
		totalAllocated += share
	}

	if totalAllocated != amount {
		return nil, ErrSumMismatch
	}
	return result, nil
}
