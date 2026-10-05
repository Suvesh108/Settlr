package database

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

func Connect(ctx context.Context) (*pgxpool.Pool, error) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:postgres@localhost:5432/expensetracker?sslmode=disable"
	}

	config, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		return nil, fmt.Errorf("error parsing db config: %w", err)
	}

	config.MaxConns = 25
	config.MinConns = 5
	config.MaxConnLifetime = 1 * time.Hour
	config.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("unable to connect to database: %w", err)
	}

	pingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()

	if err := pool.Ping(pingCtx); err != nil {
		return nil, fmt.Errorf("database ping failed: %w", err)
	}

	log.Println("[Database] Connected successfully to PostgreSQL pool")
	return pool, nil
}

// RunMigrations executes SQL migrations
func RunMigrations(ctx context.Context, pool *pgxpool.Pool, migrationPath string) error {
	content, err := os.ReadFile(migrationPath)
	if err != nil {
		// Try relative to working directory or binary
		altPath := filepath.Join("database", "migrations", filepath.Base(migrationPath))
		content, err = os.ReadFile(altPath)
		if err != nil {
			return fmt.Errorf("could not read migration file: %w", err)
		}
	}

	_, err = pool.Exec(ctx, string(content))
	if err != nil {
		return fmt.Errorf("migration execution error: %w", err)
	}

	log.Println("[Database] Schema migrations applied successfully")
	return nil
}

// RunInTx executes a closure safely within a database transaction
func RunInTx(ctx context.Context, pool *pgxpool.Pool, fn func(tx pgx.Tx) error) error {
	tx, err := pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.ReadCommitted})
	if err != nil {
		return err
	}

	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback(ctx)
			panic(p)
		}
	}()

	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}

	return tx.Commit(ctx)
}
