# Graph Report - expense-tracker  (2026-10-04)

## Corpus Check
- Corpus is ~41,240 words - fits in a single context window. You may not need a graph.

## Summary
- 441 nodes · 1108 edges · 16 communities (14 shown, 2 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 25 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Module Cluster 0
- Module Cluster 1
- Module Cluster 2
- Module Cluster 3
- Module Cluster 4
- Module Cluster 5
- Module Cluster 6
- Module Cluster 7
- Module Cluster 8
- Module Cluster 9
- Module Cluster 10
- Module Cluster 11
- Module Cluster 12
- Module Cluster 13
- Module Cluster 14
- Module Cluster 15

## God Nodes (most connected - your core abstractions)
1. `useAuthStore` - 35 edges
2. `useUIStore` - 30 edges
3. `Get()` - 22 edges
4. `react` - 22 edges
5. `Dashboard()` - 21 edges
6. `apiRequest()` - 21 edges
7. `lucide-react` - 19 edges
8. `formatMoney()` - 19 edges
9. `compilerOptions` - 18 edges
10. `main()` - 16 edges

## Surprising Connections (you probably didn't know these)
- `main()` --calls--> `ValidateToken()`  [EXTRACTED]
  backend/cmd/server/main.go → backend/internal/auth/jwt.go
- `TestZeroParticipantPayer_And_ReversalFlow()` --calls--> `FilterActiveExpenses()`  [INFERRED]
  backend/internal/ledger/ledger_test.go → backend/internal/ledger/balance.go
- `TestZeroParticipantPayer_And_ReversalFlow()` --calls--> `CalculateNetBalances()`  [INFERRED]
  backend/internal/ledger/ledger_test.go → backend/internal/ledger/balance.go
- `CalculatePairwiseDebts()` --references--> `PairwiseDetail`  [EXTRACTED]
  backend/internal/ledger/balance.go → backend/internal/ledger/types.go
- `TestZeroParticipantPayer_And_ReversalFlow()` --calls--> `CalculatePairwiseDebts()`  [INFERRED]
  backend/internal/ledger/ledger_test.go → backend/internal/ledger/balance.go

## Import Cycles
- None detected.

## Communities (16 total, 2 thin omitted)

### Community 0 - "Module Cluster 0"
Cohesion: 0.10
Nodes (64): App(), Dashboard(), queryClient, frontend_src_assets_logo, ActivityFeed(), ActivityFeedProps, AuthScreen(), ExpenseList() (+56 more)

### Community 1 - "Module Cluster 1"
Cohesion: 0.07
Nodes (55): ActivityItem, LoginRequest, RegisterRequest, SessionRequest, UserResponse, CalculatePendingReserved(), TestPendingReservation(), ParticipantShare (+47 more)

### Community 2 - "Module Cluster 2"
Cohesion: 0.08
Nodes (40): Handler, Handler, main(), Connect(), RunInTx(), RunMigrations(), NewHandler(), NewHandler() (+32 more)

### Community 3 - "Module Cluster 3"
Cohesion: 0.05
Nodes (39): amount, balance, cancelProfileBtn, closeModalBtn, currencySelector, displayGoalName, expenseChartCanvas, form (+31 more)

### Community 4 - "Module Cluster 4"
Cohesion: 0.05
Nodes (40): dependencies, clsx, lucide-react, react, react-dom, tailwind-merge, @tanstack/react-query, zustand (+32 more)

### Community 5 - "Module Cluster 5"
Cohesion: 0.12
Nodes (28): CalculateNetBalances(), CalculatePairwiseDebts(), FilterActiveExpenses(), TestCalculateSplit_Equal(), TestCalculateSplit_PercentageBasisPoints(), TestCalculateSplit_Shares(), TestGreedySettlement_ComplexGraph(), TestZeroParticipantPayer_And_ReversalFlow() (+20 more)

### Community 6 - "Module Cluster 6"
Cohesion: 0.10
Nodes (19): compilerOptions, allowArbitraryExtensions, allowImportingTsExtensions, erasableSyntaxOnly, jsx, lib, module, moduleDetection (+11 more)

### Community 7 - "Module Cluster 7"
Cohesion: 0.12
Nodes (16): compilerOptions, allowImportingTsExtensions, erasableSyntaxOnly, lib, module, moduleDetection, noEmit, noFallthroughCasesInSwitch (+8 more)

### Community 8 - "Module Cluster 8"
Cohesion: 0.18
Nodes (10): devDependencies, concurrently, name, private, scripts, dev, dev:backend, dev:frontend (+2 more)

### Community 9 - "Module Cluster 9"
Cohesion: 0.22
Nodes (9): Claims, CheckPassword(), HashPassword(), ValidateToken(), RequireAuth(), go_pkg_errors, go_pkg_github_com_golang_jwt_jwt_v5, go_pkg_golang_org_x_crypto_bcrypt (+1 more)

### Community 10 - "Module Cluster 10"
Cohesion: 0.22
Nodes (9): handleNavigation(), init(), initGoalForm(), initStatementService(), removeTransaction(), saveStatementConfig(), updateChart(), updateLocalStorage() (+1 more)

### Community 11 - "Module Cluster 11"
Cohesion: 0.29
Nodes (8): addTransaction(), addTransactionDOM(), changeCurrency(), generateID(), renderTransactions(), updateGoalProgress(), updateSpendVelocity(), updateValues()

### Community 12 - "Module Cluster 12"
Cohesion: 0.33
Nodes (5): plugins, rules, react/only-export-components, react/rules-of-hooks, $schema

### Community 13 - "Module Cluster 13"
Cohesion: 0.33
Nodes (6): closeProfileModalFunc(), handlePictureUpload(), handleUseGeneratedAvatar(), saveProfileName(), updateProfileAvatar(), updateProfilePreview()

## Knowledge Gaps
- **139 isolated node(s):** `expense-tracker/backend`, `RegisterRequest`, `LoginRequest`, `UserResponse`, `SessionRequest` (+134 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 168 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `react` connect `Module Cluster 0` to `Module Cluster 4`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Why does `Get()` connect `Module Cluster 2` to `Module Cluster 1`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `lucide-react` connect `Module Cluster 0` to `Module Cluster 4`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **What connects `expense-tracker/backend`, `RegisterRequest`, `LoginRequest` to the rest of the system?**
  _139 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Module Cluster 0` be split into smaller, more focused modules?**
  _Cohesion score 0.09794553272814142 - nodes in this community are weakly interconnected._
- **Should `Module Cluster 1` be split into smaller, more focused modules?**
  _Cohesion score 0.06701754385964913 - nodes in this community are weakly interconnected._
- **Should `Module Cluster 2` be split into smaller, more focused modules?**
  _Cohesion score 0.08095884215287201 - nodes in this community are weakly interconnected._