# ⚡ Settlr — Intelligent Financial Ledger & Debt Settlement System

[![GitHub Repository](https://img.shields.io/badge/GitHub-Suvesh108%2FSettlr-181717?logo=github)](https://github.com/Suvesh108/Settlr)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Settlr is a mathematically strict, real-time financial ledger and group debt settlement platform engineered with Go, PostgreSQL, React 19, Motion, and local-first IndexedDB durability.

---

## 🏛️ Core Architectural Invariants

> **"Users record what happened. The system calculates who owes whom."**

* **Pure Financial Ledger Engine (`backend/internal/ledger`)**: Debts are computed dynamically; only verified transactions, payments, and participant shares are stored.
* **Minor Currency Units**: All currency amounts stored as `BIGINT` minor units (paise / cents) with integer arithmetic to eliminate floating-point precision loss.
* **Immutable Reversals**: Expenses are never silently modified or deleted; corrections occur via audit-compliant reversal events balancing the books.
* **Pairwise & Optimized Settlements**:
  * **Direct Bilateral Matrix (`/balances/pairwise`)**: Canonical bilateral obligations ($A \leftrightarrow B$) with transparent accounting breakdown.
  * **Greedy Settlement Minimization (`/settlements/recommended`)**: Simplified group-wide cash-flow transfers minimizing total transaction count.
* **Concurrency & Double-Spend Protection**:
  * Serialized settlement confirmations via row-level locks (`SELECT ... FOR UPDATE`).
  * Idempotency key tracking across all financial mutation endpoints.
* **Local-First & Offline Resilience**:
  * Dexie IndexedDB caching for seamless offline operations.
  * Dual-mode architecture: runs with PostgreSQL in cloud/production or in-memory persistence locally with zero required external setup.

---

## 🚀 Quick Start

### 1. (Optional) Start PostgreSQL
```bash
docker compose up -d postgres
```
*(If Docker/Postgres is not running, Settlr automatically starts with in-memory persistence).*

### 2. Run Both Backend & Frontend Concurrently
From the root directory:
```bash
npm run dev
```

This concurrently launches:
- **Go API & WebSocket Server**: `http://localhost:8080`
- **React Frontend**: `http://localhost:5173`

---

## 🧪 Testing the Financial Engine

Run the table-driven test suite for split edge cases, basis points, reversals, and greedy settlement minimization:
```bash
cd backend
go test -v ./...
```
