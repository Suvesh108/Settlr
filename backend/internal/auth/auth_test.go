package auth

import (
	"context"
	"testing"
)

func TestPasswordHashing(t *testing.T) {
	raw := "supersecret123"
	hash, err := HashPassword(raw)
	if err != nil {
		t.Fatalf("HashPassword failed: %v", err)
	}
	if !CheckPassword(raw, hash) {
		t.Errorf("CheckPassword returned false for valid password")
	}
	if CheckPassword("wrongpassword", hash) {
		t.Errorf("CheckPassword returned true for invalid password")
	}
}

func TestTokenLifecycle(t *testing.T) {
	userID := "usr_test123"
	email := "test@settlr.local"

	token, err := GenerateToken(userID, email)
	if err != nil {
		t.Fatalf("GenerateToken failed: %v", err)
	}

	claims, err := ValidateToken(token)
	if err != nil {
		t.Fatalf("ValidateToken failed: %v", err)
	}

	if claims.UserID != userID || claims.Email != email {
		t.Errorf("Claims mismatch: got (%s, %s), want (%s, %s)", claims.UserID, claims.Email, userID, email)
	}

	// Test invalid token
	_, err = ValidateToken("invalid.token.string")
	if err == nil {
		t.Errorf("ValidateToken accepted invalid token string")
	}
}

func TestContextKeyGetUserID(t *testing.T) {
	ctx := context.WithValue(context.Background(), UserIDKey, "usr_context_test")
	uid, ok := GetUserID(ctx)
	if !ok || uid != "usr_context_test" {
		t.Errorf("GetUserID failed to retrieve user ID from context: got (%v, %v)", uid, ok)
	}

	emptyCtx := context.Background()
	_, okEmpty := GetUserID(emptyCtx)
	if okEmpty {
		t.Errorf("GetUserID returned ok=true on empty context")
	}
}
