package middleware

import (
	"bytes"
	"context"
	"net/http"
	"time"

	"expense-tracker/backend/pkg/response"
	"github.com/jackc/pgx/v5/pgxpool"
)

type responseCapture struct {
	http.ResponseWriter
	statusCode int
	body       bytes.Buffer
}

func (r *responseCapture) WriteHeader(statusCode int) {
	r.statusCode = statusCode
	r.ResponseWriter.WriteHeader(statusCode)
}

func (r *responseCapture) Write(b []byte) (int, error) {
	r.body.Write(b)
	return r.ResponseWriter.Write(b)
}

// RequireIdempotency intercepts financial POST/PATCH requests when Idempotency-Key header is present
func RequireIdempotency(pool *pgxpool.Pool, operation string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			idempotencyKey := r.Header.Get("Idempotency-Key")
			if idempotencyKey == "" {
				// Proceed normally if client didn't supply an idempotency key
				next.ServeHTTP(w, r)
				return
			}

			userID, ok := GetUserID(r.Context())
			if !ok {
				response.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing user authentication")
				return
			}

			// Check existing valid idempotency record
			var respCode int
			var respBody []byte
			err := pool.QueryRow(r.Context(),
				`SELECT response_code, response_body 
				 FROM idempotency_keys 
				 WHERE user_id = $1 AND operation = $2 AND key = $3 AND expires_at > NOW()`,
				userID, operation, idempotencyKey,
			).Scan(&respCode, &respBody)

			if err == nil {
				// Replay stored response
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("X-Idempotent-Replay", "true")
				w.WriteHeader(respCode)
				_, _ = w.Write(respBody)
				return
			}

			// Capture response
			capture := &responseCapture{
				ResponseWriter: w,
				statusCode:     http.StatusOK,
			}

			next.ServeHTTP(capture, r)

			// Store response if status is successful/terminal
			if capture.statusCode >= 200 && capture.statusCode < 500 {
				expiresAt := time.Now().Add(24 * time.Hour)
				_, _ = pool.Exec(context.Background(),
					`INSERT INTO idempotency_keys (user_id, operation, key, response_code, response_body, expires_at)
					 VALUES ($1, $2, $3, $4, $5, $6)
					 ON CONFLICT (user_id, operation, key) DO UPDATE 
					 SET response_code = EXCLUDED.response_code, response_body = EXCLUDED.response_body, expires_at = EXCLUDED.expires_at`,
					userID, operation, idempotencyKey, capture.statusCode, capture.body.Bytes(), expiresAt,
				)
			}
		})
	}
}

// CleanupExpiredIdempotencyKeys runs periodically
func CleanupExpiredIdempotencyKeys(ctx context.Context, pool *pgxpool.Pool) {
	ticker := time.NewTicker(6 * time.Hour)
	go func() {
		for {
			select {
			case <-ctx.Done():
				ticker.Stop()
				return
			case <-ticker.C:
				_, _ = pool.Exec(context.Background(), `DELETE FROM idempotency_keys WHERE expires_at <= NOW()`)
			}
		}
	}()
}
