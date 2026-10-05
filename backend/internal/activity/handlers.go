package activity

import (
	"encoding/json"
	"net/http"
	"time"

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

type ActivityItem struct {
	ID        string                 `json:"id"`
	GroupID   string                 `json:"group_id"`
	ActorID   string                 `json:"actor_id"`
	ActorName string                 `json:"actor_name"`
	Action    string                 `json:"action"`
	Summary   string                 `json:"summary"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
	CreatedAt time.Time              `json:"created_at"`
}

func (h *Handler) ListActivity(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")

	var activities []ActivityItem

	if h.pool == nil {
		store := memstore.Get()
		store.RLock()
		for _, a := range store.Activities[groupID] {
			actName := "Member"
			if u, exists := store.Users[a.ActorID]; exists {
				actName = u.Name
			}
			activities = append(activities, ActivityItem{
				ID:        a.ID,
				GroupID:   a.GroupID,
				ActorID:   a.ActorID,
				ActorName: actName,
				Action:    a.Action,
				Summary:   a.Summary,
				Metadata:  a.Metadata,
				CreatedAt: a.CreatedAt,
			})
		}
		store.RUnlock()
	} else {
		rows, err := h.pool.Query(r.Context(),
			`SELECT a.id, a.group_id, a.actor_id, u.name, a.action, a.summary, a.metadata, a.created_at
			 FROM activity_logs a
			 JOIN users u ON a.actor_id = u.id
			 WHERE a.group_id = $1
			 ORDER BY a.created_at DESC
			 LIMIT 100`,
			groupID,
		)
		if err != nil {
			response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to fetch activity logs")
			return
		}
		defer rows.Close()

		for rows.Next() {
			var item ActivityItem
			var rawMeta []byte
			if err := rows.Scan(&item.ID, &item.GroupID, &item.ActorID, &item.ActorName, &item.Action, &item.Summary, &rawMeta, &item.CreatedAt); err == nil {
				if len(rawMeta) > 0 {
					_ = json.Unmarshal(rawMeta, &item.Metadata)
				}
				activities = append(activities, item)
			}
		}
	}

	response.JSON(w, http.StatusOK, activities)
}
