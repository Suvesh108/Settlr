package syncbox

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"expense-tracker/backend/internal/memstore"
	"expense-tracker/backend/internal/middleware"
	"expense-tracker/backend/internal/websocket"
	"expense-tracker/backend/pkg/response"
)

type EnvelopePayload struct {
	DeviceID   string `json:"device_id"`
	Ciphertext string `json:"ciphertext"` // AES-GCM encrypted event payload from client
	IV         string `json:"iv"`         // Initial vector / nonce for client decryption
	KeyVersion int    `json:"key_version"`
}

type PushEnvelopeRequest struct {
	Envelopes []EnvelopePayload `json:"envelopes"`
}

type Handler struct {
	pool *pgxpool.Pool
	hub  *websocket.Hub
}

func NewHandler(pool *pgxpool.Pool, hub *websocket.Hub) *Handler {
	return &Handler{pool: pool, hub: hub}
}

func (h *Handler) verifyMembership(ctx context.Context, groupID, userID string) error {
	if h.pool != nil {
		var status string
		err := h.pool.QueryRow(ctx,
			`SELECT status FROM group_members WHERE group_id = $1 AND user_id = $2`,
			groupID, userID,
		).Scan(&status)
		if err != nil || status != "ACTIVE" {
			return errors.New("not active member")
		}
		return nil
	}

	store := memstore.Get()
	store.RLock()
	defer store.RUnlock()
	members := store.Members[groupID]
	if members == nil || members[userID] == nil || members[userID].Status != "ACTIVE" {
		return errors.New("not active member")
	}
	return nil
}

// PushEnvelopes receives opaque encrypted envelopes from a device (e.g. Mumbai, Srinagar, or Bangalore)
// and stores them into the group mailbox without knowing or decrypting their contents.
func (h *Handler) PushEnvelopes(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")
	userID, ok := middleware.GetUserID(r.Context())
	if !ok || userID == "" {
		response.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "User identity required")
		return
	}

	var req PushEnvelopeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "BAD_REQUEST", "Malformed envelope payload")
		return
	}

	if len(req.Envelopes) == 0 {
		response.Error(w, http.StatusBadRequest, "BAD_REQUEST", "At least one envelope required")
		return
	}

	if err := h.verifyMembership(r.Context(), groupID, userID); err != nil {
		response.Error(w, http.StatusForbidden, "FORBIDDEN", "Must be an active member of this group")
		return
	}

	store := memstore.Get()
	store.Lock()
	defer store.Unlock()

	pushed := make([]*memstore.EncryptedEnvelope, 0, len(req.Envelopes))
	currSeq := store.GetNextEnvelopeSeq(groupID)

	for _, env := range req.Envelopes {
		envelope := &memstore.EncryptedEnvelope{
			ID:         "env_" + strconv.FormatInt(time.Now().UnixNano(), 36) + "_" + memstore.GenerateCode(4),
			GroupID:    groupID,
			SenderID:   userID,
			DeviceID:   env.DeviceID,
			Ciphertext: env.Ciphertext,
			IV:         env.IV,
			KeyVersion: env.KeyVersion,
			Seq:        currSeq,
			CreatedAt:  time.Now(),
		}
		currSeq++
		store.AddEnvelope(envelope)
		pushed = append(pushed, envelope)
	}

	// Broadcast push event via WebSocket to notify online peers in room to pull new envelopes
	if h.hub != nil {
		h.hub.Broadcast(groupID, "sync.envelopes_pushed", map[string]interface{}{
			"count": len(pushed),
			"from":  userID,
		})
	}

	response.JSON(w, http.StatusCreated, map[string]interface{}{
		"pushed_count": len(pushed),
		"envelopes":    pushed,
	})
}

// PullEnvelopes allows any member (after reconnecting or waking up) to retrieve all
// encrypted envelopes that occurred after their last known sequence number (`since_seq`).
func (h *Handler) PullEnvelopes(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")
	userID, ok := middleware.GetUserID(r.Context())
	if !ok || userID == "" {
		response.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "User identity required")
		return
	}

	sinceSeqStr := r.URL.Query().Get("since_seq")
	sinceSeq, _ := strconv.ParseInt(sinceSeqStr, 10, 64)

	if err := h.verifyMembership(r.Context(), groupID, userID); err != nil {
		response.Error(w, http.StatusForbidden, "FORBIDDEN", "Must be an active member of this group")
		return
	}

	store := memstore.Get()
	store.RLock()
	defer store.RUnlock()

	envelopes := store.GetEnvelopesSince(groupID, sinceSeq)

	response.JSON(w, http.StatusOK, map[string]interface{}{
		"group_id":  groupID,
		"since_seq": sinceSeq,
		"envelopes": envelopes,
	})
}
