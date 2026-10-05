package auth

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"expense-tracker/backend/internal/memstore"
	"expense-tracker/backend/pkg/response"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Handler struct {
	pool *pgxpool.Pool
}

func NewHandler(pool *pgxpool.Pool) *Handler {
	return &Handler{pool: pool}
}

type RegisterRequest struct {
	Name            string `json:"name"`
	Email           string `json:"email"`
	Password        string `json:"password"`
	DefaultCurrency string `json:"default_currency"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type UserResponse struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	Email           string `json:"email"`
	DefaultCurrency string `json:"default_currency"`
	Token           string `json:"token,omitempty"`
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "INVALID_BODY", "Malformed request body")
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	req.Name = strings.TrimSpace(req.Name)
	if req.Email == "" || req.Name == "" || len(req.Password) < 6 {
		response.Error(w, http.StatusBadRequest, "VALIDATION_FAILED", "Valid name, email, and password (min 6 chars) are required")
		return
	}

	if req.DefaultCurrency == "" {
		req.DefaultCurrency = "INR"
	}

	pwHash, err := HashPassword(req.Password)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "SERVER_ERROR", "Failed to hash password")
		return
	}

	var userID string

	if h.pool == nil {
		store := memstore.Get()
		store.UsersByEmail[req.Email] = nil // lock check
		if existing, exists := store.UsersByEmail[req.Email]; exists && existing != nil {
			response.Error(w, http.StatusConflict, "EMAIL_EXISTS", "A user with this email already exists")
			return
		}
		userID = uuid.NewString()
		u := &memstore.User{
			ID:              userID,
			Name:            req.Name,
			Email:           req.Email,
			PasswordHash:    pwHash,
			DefaultCurrency: req.DefaultCurrency,
			CreatedAt:       time.Now(),
		}
		store.Users[userID] = u
		store.UsersByEmail[req.Email] = u
	} else {
		err = h.pool.QueryRow(r.Context(),
			`INSERT INTO users (name, email, password_hash, default_currency)
			 VALUES ($1, $2, $3, $4)
			 RETURNING id`,
			req.Name, req.Email, pwHash, req.DefaultCurrency,
		).Scan(&userID)

		if err != nil {
			if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique") {
				response.Error(w, http.StatusConflict, "EMAIL_EXISTS", "A user with this email already exists")
				return
			}
			response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to create user account")
			return
		}
	}

	token, err := GenerateToken(userID, req.Email)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "TOKEN_ERROR", "Failed to issue auth token")
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "access_token",
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		Secure:   false,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   86400,
	})

	response.JSON(w, http.StatusCreated, UserResponse{
		ID:              userID,
		Name:            req.Name,
		Email:           req.Email,
		DefaultCurrency: req.DefaultCurrency,
		Token:           token,
	})
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.Error(w, http.StatusBadRequest, "INVALID_BODY", "Malformed request body")
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))

	var user UserResponse
	var pwHash string

	if h.pool == nil {
		store := memstore.Get()
		u, exists := store.UsersByEmail[req.Email]
		if !exists || u == nil || !CheckPassword(req.Password, u.PasswordHash) {
			response.Error(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Incorrect email or password")
			return
		}
		user = UserResponse{
			ID:              u.ID,
			Name:            u.Name,
			Email:           u.Email,
			DefaultCurrency: u.DefaultCurrency,
		}
	} else {
		err := h.pool.QueryRow(r.Context(),
			`SELECT id, name, email, default_currency, password_hash 
			 FROM users 
			 WHERE email = $1`,
			req.Email,
		).Scan(&user.ID, &user.Name, &user.Email, &user.DefaultCurrency, &pwHash)

		if err != nil || !CheckPassword(req.Password, pwHash) {
			response.Error(w, http.StatusUnauthorized, "INVALID_CREDENTIALS", "Incorrect email or password")
			return
		}
	}

	token, err := GenerateToken(user.ID, user.Email)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "TOKEN_ERROR", "Failed to issue auth token")
		return
	}

	http.SetCookie(w, &http.Cookie{
		Name:     "access_token",
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		Secure:   false,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   86400,
	})

	user.Token = token
	response.JSON(w, http.StatusOK, user)
}

func (h *Handler) GetMe(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value("user_id").(string)

	var user UserResponse
	if h.pool == nil {
		store := memstore.Get()
		u, exists := store.Users[userID]
		if !exists {
			response.Error(w, http.StatusNotFound, "NOT_FOUND", "User not found")
			return
		}
		user = UserResponse{
			ID:              u.ID,
			Name:            u.Name,
			Email:           u.Email,
			DefaultCurrency: u.DefaultCurrency,
		}
	} else {
		err := h.pool.QueryRow(r.Context(),
			`SELECT id, name, email, default_currency FROM users WHERE id = $1`,
			userID,
		).Scan(&user.ID, &user.Name, &user.Email, &user.DefaultCurrency)

		if err != nil {
			response.Error(w, http.StatusNotFound, "NOT_FOUND", "User not found")
			return
		}
	}

	response.JSON(w, http.StatusOK, user)
}

type SessionRequest struct {
	Name            string `json:"name,omitempty"`
	Email           string `json:"email,omitempty"`
	DefaultCurrency string `json:"default_currency,omitempty"`
}

// GetOrCreateSession creates or returns an active user session without requiring password login.
// This supports local open-source single-user and multi-user environments with zero required telemetry or forced credentials.
func (h *Handler) GetOrCreateSession(w http.ResponseWriter, r *http.Request) {
	var req SessionRequest
	_ = json.NewDecoder(r.Body).Decode(&req)

	name := strings.TrimSpace(req.Name)
	if name == "" {
		name = "User"
	}
	email := strings.TrimSpace(strings.ToLower(req.Email))
	if email == "" {
		email = strings.ToLower(name) + "@local"
	}
	currency := strings.TrimSpace(req.DefaultCurrency)
	if currency == "" {
		currency = "INR"
	}

	var user UserResponse

	if h.pool == nil {
		store := memstore.Get()
		store.Lock()
		
		// 1. Look up user by email
		var existing *memstore.User
		if u, ok := store.UsersByEmail[email]; ok && u != nil {
			existing = u
		}

		// 2. Fallback: look up user by case-insensitive name if not found by email
		if existing == nil {
			for _, u := range store.Users {
				if strings.EqualFold(strings.TrimSpace(u.Name), name) {
					existing = u
					break
				}
			}
		}

		// If user exists, reuse their exact ID and sync name/email index
		if existing != nil {
			if existing.Name != name {
				existing.Name = name
			}
			store.UsersByEmail[email] = existing
			user = UserResponse{
				ID:              existing.ID,
				Name:            existing.Name,
				Email:           existing.Email,
				DefaultCurrency: existing.DefaultCurrency,
			}
		} else {
			userID := "usr_" + uuid.NewString()[:8]
			newUser := &memstore.User{
				ID:              userID,
				Name:            name,
				Email:           email,
				PasswordHash:    "nopassword",
				DefaultCurrency: currency,
				CreatedAt:       time.Now(),
			}
			store.Users[userID] = newUser
			store.UsersByEmail[email] = newUser
			user = UserResponse{
				ID:              newUser.ID,
				Name:            newUser.Name,
				Email:           newUser.Email,
				DefaultCurrency: newUser.DefaultCurrency,
			}
		}
		store.Unlock()
	} else {
		err := h.pool.QueryRow(r.Context(),
			`INSERT INTO users (name, email, password_hash, default_currency)
			 VALUES ($1, $2, 'nopassword', $3)
			 ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name
			 RETURNING id, name, email, default_currency`,
			name, email, currency,
		).Scan(&user.ID, &user.Name, &user.Email, &user.DefaultCurrency)

		if err != nil {
			response.Error(w, http.StatusInternalServerError, "DB_ERROR", "Failed to initialize user session")
			return
		}
	}

	token, err := GenerateToken(user.ID, user.Email)
	if err != nil {
		response.Error(w, http.StatusInternalServerError, "TOKEN_ERROR", "Failed to issue session token")
		return
	}

	user.Token = token
	response.JSON(w, http.StatusOK, user)
}

