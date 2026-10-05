package groups

import (
	"crypto/rand"
	"encoding/json"
	"math/big"
	"net/http"
	"strings"
	"time"

	"expense-tracker/backend/database"
	"expense-tracker/backend/internal/memstore"
	"expense-tracker/backend/internal/middleware"
	"expense-tracker/backend/pkg/response"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Handler struct {
	pool *pgxpool.Pool
}

func NewHandler(pool *pgxpool.Pool) *Handler {
	return &Handler{pool: pool}
}

type GroupResponse struct {
	ID            string           `json:"id"`
	Name          string           `json:"name"`
	Description   string           `json:"description"`
	Currency      string           `json:"currency"`
	InviteCode    string           `json:"invite_code"`
	LedgerVersion int64            `json:"ledger_version"`
	CreatedBy     string           `json:"created_by"`
	CreatedAt     time.Time        `json:"created_at"`
	Members       []MemberResponse `json:"members,omitempty"`
}

type MemberResponse struct {
	UserID   string    `json:"user_id"`
	Name     string    `json:"name"`
	Email    string    `json:"email"`
	Role     string    `json:"role"`
	Status   string    `json:"status"`
	JoinedAt time.Time `json:"joined_at"`
}

type CreateGroupRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Currency    string `json:"currency"`
}

type JoinGroupRequest struct {
	InviteCode string `json:"invite_code"`
}

const base62Chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

func generateInviteCode(length int) (string, error) {
	result := make([]byte, length)
	for i := 0; i < length; i++ {
		num, err := rand.Int(rand.Reader, big.NewInt(int64(len(base62Chars))))
		if err != nil {
			return "", err
		}
		result[i] = base62Chars[num.Int64()]
	}
	return string(result), nil
}

func (h *Handler) CreateGroup(w http.ResponseWriter, r *http.Request) {
	userID, _ := middleware.GetUserID(r.Context())

	var req CreateGroupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "INVALID_BODY", "Malformed request body")
		return
	}

	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		response.Error(w, http.StatusBadRequest, "VALIDATION_FAILED", "Group name is required")
		return
	}

	if req.Currency == "" {
		req.Currency = "INR"
	}

	inviteCode, err := generateInviteCode(16)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "CODE_GEN_ERROR", "Failed to generate invite code")
		return
	}

	var group GroupResponse

	if h.pool == nil {
		store := memstore.Get()
		store.Lock()
		grp := &memstore.Group{
			ID:            uuid.NewString(),
			Name:          req.Name,
			Description:   req.Description,
			Currency:      req.Currency,
			InviteCode:    inviteCode,
			LedgerVersion: 1,
			CreatedBy:     userID,
			CreatedAt:     time.Now(),
		}
		store.Groups[grp.ID] = grp
		store.GroupsByCode[grp.InviteCode] = grp
		if store.Members[grp.ID] == nil {
			store.Members[grp.ID] = make(map[string]*memstore.GroupMember)
		}
		store.Members[grp.ID][userID] = &memstore.GroupMember{
			ID:       uuid.NewString(),
			GroupID:  grp.ID,
			UserID:   userID,
			Role:     "OWNER",
			Status:   "ACTIVE",
			JoinedAt: time.Now(),
		}
		store.Activities[grp.ID] = append(store.Activities[grp.ID], &memstore.ActivityRecord{
			ID:        uuid.NewString(),
			GroupID:   grp.ID,
			ActorID:   userID,
			Action:    "GROUP_CREATED",
			Summary:   "Group created",
			CreatedAt: time.Now(),
		})
		store.Unlock()

		group = GroupResponse{
			ID:            grp.ID,
			Name:          grp.Name,
			Description:   grp.Description,
			Currency:      grp.Currency,
			InviteCode:    grp.InviteCode,
			LedgerVersion: grp.LedgerVersion,
			CreatedBy:     grp.CreatedBy,
			CreatedAt:     grp.CreatedAt,
		}
	} else {
		err = database.RunInTx(r.Context(), h.pool, func(tx pgx.Tx) error {
			err := tx.QueryRow(r.Context(),
				`INSERT INTO groups (name, description, currency, invite_code, created_by)
				 VALUES ($1, $2, $3, $4, $5)
				 RETURNING id, name, description, currency, invite_code, ledger_version, created_by, created_at`,
				req.Name, req.Description, req.Currency, inviteCode, userID,
			).Scan(&group.ID, &group.Name, &group.Description, &group.Currency, &group.InviteCode, &group.LedgerVersion, &group.CreatedBy, &group.CreatedAt)
			if err != nil {
				return err
			}

			_, err = tx.Exec(r.Context(),
				`INSERT INTO group_members (group_id, user_id, role, status)
				 VALUES ($1, $2, 'OWNER', 'ACTIVE')`,
				group.ID, userID,
			)
			if err != nil {
				return err
			}

			_, err = tx.Exec(r.Context(),
				`INSERT INTO activity_logs (group_id, actor_id, action, summary)
				 VALUES ($1, $2, 'GROUP_CREATED', 'Group created')`,
				group.ID, userID,
			)
			return err
		})

		if err != nil {
			response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to create group")
			return
		}
	}

	response.JSON(w, http.StatusCreated, group)
}

func (h *Handler) ListUserGroups(w http.ResponseWriter, r *http.Request) {
	userID, _ := middleware.GetUserID(r.Context())

	var groups []GroupResponse

	if h.pool == nil {
		store := memstore.Get()
		store.RLock()
		for gID, members := range store.Members {
			if m, ok := members[userID]; ok && m.Status == "ACTIVE" {
				if g, exists := store.Groups[gID]; exists {
					var memberList []MemberResponse
					for _, mem := range store.Members[gID] {
						uName := "Member"
						uEmail := ""
						if u, uExists := store.Users[mem.UserID]; uExists {
							uName = u.Name
							uEmail = u.Email
						}
						memberList = append(memberList, MemberResponse{
							UserID:   mem.UserID,
							Name:     uName,
							Email:    uEmail,
							Role:     mem.Role,
							Status:   mem.Status,
							JoinedAt: mem.JoinedAt,
						})
					}

					groups = append(groups, GroupResponse{
						ID:            g.ID,
						Name:          g.Name,
						Description:   g.Description,
						Currency:      g.Currency,
						InviteCode:    g.InviteCode,
						LedgerVersion: g.LedgerVersion,
						CreatedBy:     g.CreatedBy,
						CreatedAt:     g.CreatedAt,
						Members:       memberList,
					})
				}
			}
		}
		store.RUnlock()
	} else {
		rows, err := h.pool.Query(r.Context(),
			`SELECT g.id, g.name, g.description, g.currency, g.invite_code, g.ledger_version, g.created_by, g.created_at
			 FROM groups g
			 JOIN group_members gm ON g.id = gm.group_id
			 WHERE gm.user_id = $1 AND gm.status = 'ACTIVE'
			 ORDER BY g.created_at DESC`,
			userID,
		)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to fetch groups")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var g GroupResponse
			if err := rows.Scan(&g.ID, &g.Name, &g.Description, &g.Currency, &g.InviteCode, &g.LedgerVersion, &g.CreatedBy, &g.CreatedAt); err != nil {
				continue
			}

			mRows, err := h.pool.Query(r.Context(),
				`SELECT gm.user_id, u.name, u.email, gm.role, gm.status, gm.joined_at
				 FROM group_members gm
				 JOIN users u ON gm.user_id = u.id
				 WHERE gm.group_id = $1
				 ORDER BY gm.joined_at ASC`,
				g.ID,
			)
			if err == nil {
				for mRows.Next() {
					var m MemberResponse
					if err := mRows.Scan(&m.UserID, &m.Name, &m.Email, &m.Role, &m.Status, &m.JoinedAt); err == nil {
						g.Members = append(g.Members, m)
					}
				}
				mRows.Close()
			}

			groups = append(groups, g)
		}
	}

	response.JSON(w, http.StatusOK, groups)
}

func (h *Handler) GetGroup(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")

	var g GroupResponse

	if h.pool == nil {
		store := memstore.Get()
		store.RLock()
		grp, exists := store.Groups[groupID]
		if !exists {
			store.RUnlock()
			response.Error(w, http.StatusNotFound, "NOT_FOUND", "Group not found")
			return
		}
		g = GroupResponse{
			ID:            grp.ID,
			Name:          grp.Name,
			Description:   grp.Description,
			Currency:      grp.Currency,
			InviteCode:    grp.InviteCode,
			LedgerVersion: grp.LedgerVersion,
			CreatedBy:     grp.CreatedBy,
			CreatedAt:     grp.CreatedAt,
		}
		for _, m := range store.Members[groupID] {
			uName := "Member"
			uEmail := ""
			if u, uExists := store.Users[m.UserID]; uExists {
				uName = u.Name
				uEmail = u.Email
			}
			g.Members = append(g.Members, MemberResponse{
				UserID:   m.UserID,
				Name:     uName,
				Email:    uEmail,
				Role:     m.Role,
				Status:   m.Status,
				JoinedAt: m.JoinedAt,
			})
		}
		store.RUnlock()
	} else {
		err := h.pool.QueryRow(r.Context(),
			`SELECT id, name, description, currency, invite_code, ledger_version, created_by, created_at
			 FROM groups WHERE id = $1`,
			groupID,
		).Scan(&g.ID, &g.Name, &g.Description, &g.Currency, &g.InviteCode, &g.LedgerVersion, &g.CreatedBy, &g.CreatedAt)

		if err != nil {
			response.Error(w, http.StatusNotFound, "NOT_FOUND", "Group not found")
			return
		}

		mRows, err := h.pool.Query(r.Context(),
			`SELECT gm.user_id, u.name, u.email, gm.role, gm.status, gm.joined_at
			 FROM group_members gm
			 JOIN users u ON gm.user_id = u.id
			 WHERE gm.group_id = $1
			 ORDER BY gm.joined_at ASC`,
			groupID,
		)
		if err == nil {
			defer mRows.Close()
			for mRows.Next() {
				var m MemberResponse
				if err := mRows.Scan(&m.UserID, &m.Name, &m.Email, &m.Role, &m.Status, &m.JoinedAt); err == nil {
					g.Members = append(g.Members, m)
				}
			}
		}
	}

	response.JSON(w, http.StatusOK, g)
}

func (h *Handler) JoinGroup(w http.ResponseWriter, r *http.Request) {
	userID, _ := middleware.GetUserID(r.Context())

	var req JoinGroupRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "INVALID_BODY", "Malformed request body")
		return
	}

	req.InviteCode = strings.TrimSpace(req.InviteCode)
	if req.InviteCode == "" {
		response.Error(w, http.StatusBadRequest, "VALIDATION_FAILED", "Invite code is required")
		return
	}

	if h.pool == nil {
		store := memstore.Get()
		store.Lock()
		grp, exists := store.GroupsByCode[req.InviteCode]
		if !exists {
			store.Unlock()
			response.Error(w, http.StatusNotFound, "INVALID_CODE", "Invalid invite code")
			return
		}
		if store.Members[grp.ID] == nil {
			store.Members[grp.ID] = make(map[string]*memstore.GroupMember)
		}
		store.Members[grp.ID][userID] = &memstore.GroupMember{
			ID:       uuid.NewString(),
			GroupID:  grp.ID,
			UserID:   userID,
			Role:     "MEMBER",
			Status:   "ACTIVE",
			JoinedAt: time.Now(),
		}
		store.Activities[grp.ID] = append(store.Activities[grp.ID], &memstore.ActivityRecord{
			ID:        uuid.NewString(),
			GroupID:   grp.ID,
			ActorID:   userID,
			Action:    "MEMBER_JOINED",
			Summary:   "A new member joined the group",
			CreatedAt: time.Now(),
		})
		gID := grp.ID
		store.Unlock()

		response.JSON(w, http.StatusOK, map[string]string{
			"group_id": gID,
			"status":   "ACTIVE",
		})
		return
	}

	var groupID string
	err := h.pool.QueryRow(r.Context(),
		`SELECT id FROM groups WHERE invite_code = $1`,
		req.InviteCode,
	).Scan(&groupID)

	if err != nil {
		response.Error(w, http.StatusNotFound, "INVALID_CODE", "Invalid invite code")
		return
	}

	err = database.RunInTx(r.Context(), h.pool, func(tx pgx.Tx) error {
		_, err := tx.Exec(r.Context(),
			`INSERT INTO group_members (group_id, user_id, role, status)
			 VALUES ($1, $2, 'MEMBER', 'ACTIVE')
			 ON CONFLICT (group_id, user_id) 
			 DO UPDATE SET status = 'ACTIVE', left_at = NULL, joined_at = NOW()`,
			groupID, userID,
		)
		if err != nil {
			return err
		}

		_, err = tx.Exec(r.Context(),
			`INSERT INTO activity_logs (group_id, actor_id, action, summary)
			 VALUES ($1, $2, 'MEMBER_JOINED', 'A new member joined the group')`,
			groupID, userID,
		)
		return err
	})

	if err != nil {
		response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to join group")
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{
		"group_id": groupID,
		"status":   "ACTIVE",
	})
}

func (h *Handler) LeaveGroup(w http.ResponseWriter, r *http.Request) {
	userID, _ := middleware.GetUserID(r.Context())
	groupID := chi.URLParam(r, "groupId")

	if h.pool == nil {
		store := memstore.Get()
		store.Lock()
		if members, ok := store.Members[groupID]; ok {
			if m, ok := members[userID]; ok {
				m.Status = "LEFT"
			}
		}
		store.Activities[groupID] = append(store.Activities[groupID], &memstore.ActivityRecord{
			ID:        uuid.NewString(),
			GroupID:   groupID,
			ActorID:   userID,
			Action:    "MEMBER_LEFT",
			Summary:   "A member left the group",
			CreatedAt: time.Now(),
		})
		store.Unlock()

		response.JSON(w, http.StatusOK, map[string]string{"status": "LEFT"})
		return
	}

	err := database.RunInTx(r.Context(), h.pool, func(tx pgx.Tx) error {
		_, err := tx.Exec(r.Context(),
			`UPDATE group_members SET status = 'LEFT', left_at = NOW()
			 WHERE group_id = $1 AND user_id = $2`,
			groupID, userID,
		)
		if err != nil {
			return err
		}

		_, err = tx.Exec(r.Context(),
			`INSERT INTO activity_logs (group_id, actor_id, action, summary)
			 VALUES ($1, $2, 'MEMBER_LEFT', 'A member left the group')`,
			groupID, userID,
		)
		return err
	})

	if err != nil {
		response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to leave group")
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"status": "LEFT"})
}

func (h *Handler) DeleteGroup(w http.ResponseWriter, r *http.Request) {
	userID, _ := middleware.GetUserID(r.Context())
	groupID := chi.URLParam(r, "groupId")

	if h.pool == nil {
		store := memstore.Get()
		store.Lock()
		defer store.Unlock()

		grp, exists := store.Groups[groupID]
		if !exists {
			response.Error(w, http.StatusNotFound, "NOT_FOUND", "Group not found")
			return
		}

		// Authorization rule: Only the creator of the group can delete it
		if grp.CreatedBy != userID {
			response.Error(w, http.StatusForbidden, "FORBIDDEN", "Only the person who created this group can delete it")
			return
		}

		delete(store.Groups, groupID)
		delete(store.GroupsByCode, grp.InviteCode)
		delete(store.Members, groupID)
		delete(store.Expenses, groupID)
		delete(store.Settlements, groupID)
		delete(store.Activities, groupID)

		response.JSON(w, http.StatusOK, map[string]string{"status": "DELETED"})
		return
	}

	// Verify creator
	var createdBy string
	err := h.pool.QueryRow(r.Context(), `SELECT created_by FROM groups WHERE id = $1`, groupID).Scan(&createdBy)
	if err != nil {
		response.Error(w, http.StatusNotFound, "NOT_FOUND", "Group not found")
		return
	}

	if createdBy != userID {
		response.Error(w, http.StatusForbidden, "FORBIDDEN", "Only the person who created this group can delete it")
		return
	}

	err = database.RunInTx(r.Context(), h.pool, func(tx pgx.Tx) error {
		_, err := tx.Exec(r.Context(), `DELETE FROM activity_logs WHERE group_id = $1`, groupID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(r.Context(), `DELETE FROM settlement_participants WHERE settlement_id IN (SELECT id FROM settlements WHERE group_id = $1)`, groupID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(r.Context(), `DELETE FROM settlements WHERE group_id = $1`, groupID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(r.Context(), `DELETE FROM expense_participants WHERE expense_id IN (SELECT id FROM expenses WHERE group_id = $1)`, groupID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(r.Context(), `DELETE FROM expenses WHERE group_id = $1`, groupID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(r.Context(), `DELETE FROM group_members WHERE group_id = $1`, groupID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(r.Context(), `DELETE FROM groups WHERE id = $1`, groupID)
		return err
	})

	if err != nil {
		response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to delete group")
		return
	}

	response.JSON(w, http.StatusOK, map[string]string{"status": "DELETED"})
}

