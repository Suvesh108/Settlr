package middleware

import (
	"context"
	"net/http"
	"strings"

	"expense-tracker/backend/internal/auth"
	"expense-tracker/backend/internal/memstore"
	"expense-tracker/backend/pkg/response"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type contextKey string

const (
	UserIDKey contextKey = "user_id"
	EmailKey  contextKey = "email"
)

func RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			// Check cookie fallback
			cookie, err := r.Cookie("access_token")
			if err == nil {
				authHeader = "Bearer " + cookie.Value
			}
		}

		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			response.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing or invalid authorization header")
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		claims, err := auth.ValidateToken(tokenStr)
		if err != nil {
			response.Error(w, http.StatusUnauthorized, "INVALID_TOKEN", "Token is expired or invalid")
			return
		}

		ctx := context.WithValue(r.Context(), UserIDKey, claims.UserID)
		ctx = context.WithValue(ctx, EmailKey, claims.Email)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// RequireGroupMember ensures that the authenticated user is an ACTIVE member of the group specified in the URL params
func RequireGroupMember(pool *pgxpool.Pool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID, ok := GetUserID(r.Context())
			if !ok {
				response.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "User identity missing")
				return
			}

			groupID := chi.URLParam(r, "groupId")
			if groupID == "" {
				response.Error(w, http.StatusBadRequest, "BAD_REQUEST", "groupId parameter required")
				return
			}

			if pool == nil {
				// Memstore validation
				store := memstore.Get()
				store.RLock()
				member, exists := store.Members[groupID][userID]
				store.RUnlock()
				if !exists || member.Status != "ACTIVE" {
					response.Error(w, http.StatusForbidden, "FORBIDDEN_NOT_GROUP_MEMBER", "You must be an active member of this group")
					return
				}
				next.ServeHTTP(w, r)
				return
			}

			var status string
			err := pool.QueryRow(r.Context(),
				`SELECT status FROM group_members WHERE group_id = $1 AND user_id = $2`,
				groupID, userID,
			).Scan(&status)

			if err != nil || status != "ACTIVE" {
				response.Error(w, http.StatusForbidden, "FORBIDDEN_NOT_GROUP_MEMBER", "You must be an active member of this group")
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

func GetUserID(ctx context.Context) (string, bool) {
	val, ok := ctx.Value(UserIDKey).(string)
	return val, ok
}
