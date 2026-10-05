-- Migration: 001_init.sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Automatic timestamp trigger
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    default_currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Groups table
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    invite_code VARCHAR(32) UNIQUE NOT NULL,
    ledger_version BIGINT NOT NULL DEFAULT 1,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS trg_groups_updated_at ON groups;
CREATE TRIGGER trg_groups_updated_at BEFORE UPDATE ON groups FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Group Memberships
CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('OWNER', 'ADMIN', 'MEMBER')),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'LEFT', 'REMOVED')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_group_status ON group_members(group_id, status);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
DROP TRIGGER IF EXISTS trg_group_members_updated_at ON group_members;
CREATE TRIGGER trg_group_members_updated_at BEFORE UPDATE ON group_members FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Expenses table
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    paid_by UUID NOT NULL REFERENCES users(id),
    amount BIGINT NOT NULL CHECK (amount > 0 AND amount <= 100000000000),
    currency VARCHAR(3) NOT NULL,
    description VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'GENERAL',
    split_type VARCHAR(20) NOT NULL CHECK (split_type IN ('EQUAL', 'EXACT', 'PERCENTAGE', 'SHARES')),
    expense_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_reversal BOOLEAN NOT NULL DEFAULT FALSE,
    is_reversed BOOLEAN NOT NULL DEFAULT FALSE,
    reverses_expense_id UUID UNIQUE REFERENCES expenses(id),
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expenses_group_non_reversal ON expenses(group_id, id) WHERE is_reversal IS FALSE AND is_reversed IS FALSE;
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON expenses(paid_by);
CREATE INDEX IF NOT EXISTS idx_expenses_created_at ON expenses(group_id, created_at DESC);
DROP TRIGGER IF EXISTS trg_expenses_updated_at ON expenses;
CREATE TRIGGER trg_expenses_updated_at BEFORE UPDATE ON expenses FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Expense Participants
CREATE TABLE IF NOT EXISTS expense_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    share_amount BIGINT NOT NULL CHECK (share_amount > 0),
    basis_points INT CHECK (basis_points IS NULL OR (basis_points > 0 AND basis_points <= 10000)),
    shares INT CHECK (shares IS NULL OR shares > 0),
    UNIQUE(expense_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_expense_participants_expense_id ON expense_participants(expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_participants_user_id ON expense_participants(user_id);

-- Settlements table
CREATE TABLE IF NOT EXISTS settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    from_user UUID NOT NULL REFERENCES users(id),
    to_user UUID NOT NULL REFERENCES users(id),
    amount BIGINT NOT NULL CHECK (amount > 0 AND amount <= 100000000000),
    status VARCHAR(20) NOT NULL DEFAULT 'PAYMENT_RECORDED' CHECK (status IN ('PAYMENT_RECORDED', 'CONFIRMED', 'CANCELLED')),
    recorded_by UUID NOT NULL REFERENCES users(id),
    confirmed_by UUID REFERENCES users(id),
    cancelled_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    CHECK (from_user <> to_user)
);

CREATE INDEX IF NOT EXISTS idx_settlements_group_status ON settlements(group_id, status);
CREATE INDEX IF NOT EXISTS idx_settlements_pairwise ON settlements(group_id, from_user, to_user, status);
DROP TRIGGER IF EXISTS trg_settlements_updated_at ON settlements;
CREATE TRIGGER trg_settlements_updated_at BEFORE UPDATE ON settlements FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Terminal state protection trigger for settlements
CREATE OR REPLACE FUNCTION trg_enforce_settlement_state()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IN ('CONFIRMED', 'CANCELLED') THEN
        RAISE EXCEPTION 'Cannot modify settlement in terminal status: %', OLD.status;
    END IF;
    IF OLD.status = 'PAYMENT_RECORDED' AND NEW.status NOT IN ('CONFIRMED', 'CANCELLED') THEN
        RAISE EXCEPTION 'Invalid settlement transition from % to %', OLD.status, NEW.status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_settlement_state_transition ON settlements;
CREATE TRIGGER trg_settlement_state_transition
BEFORE UPDATE OF status ON settlements
FOR EACH ROW
EXECUTE FUNCTION trg_enforce_settlement_state();

-- Scoped Idempotency Keys with Expiration
CREATE TABLE IF NOT EXISTS idempotency_keys (
    user_id UUID NOT NULL REFERENCES users(id),
    operation VARCHAR(100) NOT NULL,
    key VARCHAR(255) NOT NULL,
    response_code INT NOT NULL,
    response_body JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY(user_id, operation, key)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires_at ON idempotency_keys(expires_at);

-- Activity Logs
CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    summary VARCHAR(255) NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_group_created ON activity_logs(group_id, created_at DESC);

-- Canonical View for Active Expenses
CREATE OR REPLACE VIEW v_active_expenses AS
SELECT e.*
FROM expenses e
WHERE e.is_reversal = FALSE
  AND e.is_reversed = FALSE;
