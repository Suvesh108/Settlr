package memstore

import (
	"crypto/rand"
	"encoding/json"
	"math/big"
	"os"
	"path/filepath"
	"sync"
	"time"

	"expense-tracker/backend/internal/ledger"
)

type User struct {
	ID              string    `json:"id"`
	Name            string    `json:"name"`
	Email           string    `json:"email"`
	PasswordHash    string    `json:"password_hash"`
	DefaultCurrency string    `json:"default_currency"`
	CreatedAt       time.Time `json:"created_at"`
}

type Group struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	Description   string    `json:"description"`
	Currency      string    `json:"currency"`
	InviteCode    string    `json:"invite_code"`
	LedgerVersion int64     `json:"ledger_version"`
	CreatedBy     string    `json:"created_by"`
	CreatedAt     time.Time `json:"created_at"`
}

type GroupMember struct {
	ID       string    `json:"id"`
	GroupID  string    `json:"group_id"`
	UserID   string    `json:"user_id"`
	Role     string    `json:"role"`
	Status   string    `json:"status"`
	JoinedAt time.Time `json:"joined_at"`
}

type ExpenseRecord struct {
	ID                string                   `json:"id"`
	GroupID           string                   `json:"group_id"`
	PaidBy            string                   `json:"paid_by"`
	Amount            int64                    `json:"amount"`
	Currency          string                   `json:"currency"`
	Description       string                   `json:"description"`
	Category          string                   `json:"category"`
	SplitType         string                   `json:"split_type"`
	ExpenseDate       time.Time                `json:"expense_date"`
	IsReversal        bool                     `json:"is_reversal"`
	IsReversed        bool                     `json:"is_reversed"`
	ReversesExpenseID *string                  `json:"reverses_expense_id,omitempty"`
	CreatedBy         string                   `json:"created_by"`
	CreatedAt         time.Time                `json:"created_at"`
	Participants      []ledger.ParticipantShare `json:"participants"`
}

type SettlementRecord struct {
	ID          string     `json:"id"`
	GroupID     string     `json:"group_id"`
	FromUser    string     `json:"from_user"`
	ToUser      string     `json:"to_user"`
	Amount      int64      `json:"amount"`
	Status      string     `json:"status"`
	RecordedBy  string     `json:"recorded_by"`
	ConfirmedBy *string    `json:"confirmed_by,omitempty"`
	CancelledBy *string    `json:"cancelled_by,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	ConfirmedAt *time.Time `json:"confirmed_at,omitempty"`
	CancelledAt *time.Time `json:"cancelled_at,omitempty"`
}

type ActivityRecord struct {
	ID        string                 `json:"id"`
	GroupID   string                 `json:"group_id"`
	ActorID   string                 `json:"actor_id"`
	Action    string                 `json:"action"`
	Summary   string                 `json:"summary"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
	CreatedAt time.Time              `json:"created_at"`
}

type EncryptedEnvelope struct {
	ID         string    `json:"id"`
	GroupID    string    `json:"group_id"`
	SenderID   string    `json:"sender_id"`
	DeviceID   string    `json:"device_id"`
	Ciphertext string    `json:"ciphertext"`
	IV         string    `json:"iv"`
	KeyVersion int       `json:"key_version"`
	Seq        int64     `json:"seq"`
	CreatedAt  time.Time `json:"created_at"`
}

type diskSnapshot struct {
	Users        map[string]*User                    `json:"users"`
	UsersByEmail map[string]*User                    `json:"users_by_email"`
	Groups       map[string]*Group                   `json:"groups"`
	GroupsByCode map[string]*Group                   `json:"groups_by_code"`
	Members      map[string]map[string]*GroupMember  `json:"members"`
	Expenses     map[string][]*ExpenseRecord         `json:"expenses"`
	Settlements  map[string][]*SettlementRecord      `json:"settlements"`
	Activities   map[string][]*ActivityRecord        `json:"activities"`
	Envelopes    map[string][]*EncryptedEnvelope     `json:"envelopes"`
}

type MemStore struct {
	mu           sync.RWMutex
	dataFile     string
	Users        map[string]*User
	UsersByEmail map[string]*User
	Groups       map[string]*Group
	GroupsByCode map[string]*Group
	Members      map[string]map[string]*GroupMember // groupID -> userID -> Member
	Expenses     map[string][]*ExpenseRecord        // groupID -> list
	Settlements  map[string][]*SettlementRecord     // groupID -> list
	Activities   map[string][]*ActivityRecord       // groupID -> list
	Envelopes    map[string][]*EncryptedEnvelope    // groupID -> list of envelopes
}

func (s *MemStore) Lock() {
	s.mu.Lock()
}

func (s *MemStore) Unlock() {
	s.SaveToDisk()
	s.mu.Unlock()
}

func (s *MemStore) RLock()   { s.mu.RLock() }
func (s *MemStore) RUnlock() { s.mu.RUnlock() }

func (s *MemStore) SaveToDisk() {
	if s.dataFile == "" {
		return
	}
	snapshot := diskSnapshot{
		Users:        s.Users,
		UsersByEmail: s.UsersByEmail,
		Groups:       s.Groups,
		GroupsByCode: s.GroupsByCode,
		Members:      s.Members,
		Expenses:     s.Expenses,
		Settlements:  s.Settlements,
		Activities:   s.Activities,
		Envelopes:    s.Envelopes,
	}
	data, err := json.MarshalIndent(snapshot, "", "  ")
	if err == nil {
		_ = os.WriteFile(s.dataFile, data, 0644)
	}
}

func (s *MemStore) LoadFromDisk() {
	if s.dataFile == "" {
		return
	}
	data, err := os.ReadFile(s.dataFile)
	if err != nil {
		return
	}
	var snapshot diskSnapshot
	if err := json.Unmarshal(data, &snapshot); err == nil {
		if snapshot.Users != nil {
			s.Users = snapshot.Users
		}
		if snapshot.UsersByEmail != nil {
			s.UsersByEmail = snapshot.UsersByEmail
		}
		if snapshot.Groups != nil {
			s.Groups = snapshot.Groups
		}
		if snapshot.GroupsByCode != nil {
			s.GroupsByCode = snapshot.GroupsByCode
		}
		if snapshot.Members != nil {
			s.Members = snapshot.Members
		}
		if snapshot.Expenses != nil {
			s.Expenses = snapshot.Expenses
		}
		if snapshot.Settlements != nil {
			s.Settlements = snapshot.Settlements
		}
		if snapshot.Activities != nil {
			s.Activities = snapshot.Activities
		}
		if snapshot.Envelopes != nil {
			s.Envelopes = snapshot.Envelopes
		}
	}
}

func (s *MemStore) GetNextEnvelopeSeq(groupID string) int64 {
	envs := s.Envelopes[groupID]
	if len(envs) == 0 {
		return 1
	}
	return envs[len(envs)-1].Seq + 1
}

func (s *MemStore) AddEnvelope(env *EncryptedEnvelope) {
	if s.Envelopes == nil {
		s.Envelopes = make(map[string][]*EncryptedEnvelope)
	}
	s.Envelopes[env.GroupID] = append(s.Envelopes[env.GroupID], env)
}

func (s *MemStore) GetEnvelopesSince(groupID string, sinceSeq int64) []*EncryptedEnvelope {
	envs := s.Envelopes[groupID]
	if len(envs) == 0 {
		return []*EncryptedEnvelope{}
	}
	res := make([]*EncryptedEnvelope, 0)
	for _, e := range envs {
		if e.Seq > sinceSeq {
			res = append(res, e)
		}
	}
	return res
}

var globalStore *MemStore
var once sync.Once

func Get() *MemStore {
	once.Do(func() {
		dataFile := "settlr_local_store.json"
		if exe, err := os.Executable(); err == nil {
			dataFile = filepath.Join(filepath.Dir(exe), "settlr_local_store.json")
		}

		globalStore = &MemStore{
			dataFile:     dataFile,
			Users:        make(map[string]*User),
			UsersByEmail: make(map[string]*User),
			Groups:       make(map[string]*Group),
			GroupsByCode: make(map[string]*Group),
			Members:      make(map[string]map[string]*GroupMember),
			Expenses:     make(map[string][]*ExpenseRecord),
			Settlements:  make(map[string][]*SettlementRecord),
			Activities:   make(map[string][]*ActivityRecord),
			Envelopes:    make(map[string][]*EncryptedEnvelope),
		}
		globalStore.LoadFromDisk()
	})
	return globalStore
}

func GenerateCode(length int) string {
	const chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
	result := make([]byte, length)
	for i := 0; i < length; i++ {
		num, _ := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
		result[i] = chars[num.Int64()]
	}
	return string(result)
}
