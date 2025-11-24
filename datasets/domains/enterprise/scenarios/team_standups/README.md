# Team Standups Scenario

This scenario captures the messy, interconnected reality of engineering team standups. It tests an agent's ability to infer **state**, **blockers**, and **dependencies** from conversational updates.

## Data Profile
- **Type:** Daily Standup (Engram)
- **Context:** Engineering team sprint kickoff
- **Key Elements:**
  - Explicit Dependencies (`blocked_by` edges)
  - Emotional Context (`frustrated`, `confident`)
  - Technical State (Migration versions, API specs)

## Challenging Example Questions

These questions are designed to fail on simple keyword-search RAG and succeed on Graph+Time aware systems.

### 1. Dependency Chain Analysis (Graph Traversal)
> "Why specifically is the frontend refactor delayed, and who needs to talk to whom to fix it?"

*   **Why it's hard:** Requires tracing: `Alex` -> `blocked_by` -> `Mike` -> `API Contract`.
*   **Expected Answer:** Alex is blocked because the token refresh endpoint isn't finalized. He needs to sync with Mike Rodriguez (scheduled for 2pm) to get the new API contract.

### 2. Temporal State Inference (State Reconciliation)
> "What is the current status of the database migration, and what is the immediate next step?"

*   **Why it's hard:** The "status" isn't a single field. It's a composite of Jessica's update ("scripts ready") and Sarah's decision ("needs more testing").
*   **Expected Answer:** The migration is in the *testing phase*. Scripts are written for Postgres 17->18, but schema validation is needed. Next step: Jessica pairs with Carlos on rollback procedures tomorrow.

### 3. Risk Detection (Sentiment + Logic)
> "Are there any risks to the deployment timeline based on the team's updates?"

*   **Why it's hard:** No one explicitly said "Risk." The agent must infer risk from Jessica's `concerned` emotion regarding the schema changes and the need for "extra testing time."
*   **Expected Answer:** Yes, the database migration carries risk. Jessica expressed concern about the `pgvector` schema changes, which has pushed the staging deploy target to Friday.

### 4. Entity Disambiguation
> "What metrics are we tracking for the new Auth Service?"

*   **Why it's hard:** "Auth Service" is mentioned by Sarah (deployment) and Carlos (monitoring). The answer requires combining information from different moments.
*   **Expected Answer:** We are tracking P95 latency thresholds and error rates using Prometheus dashboards.

## Run This Scenario
```bash
rem db load --file daily_standup_monday_engram.yaml --user-id enterprise-demo
rem ask --user-id enterprise-demo "Why is the frontend team blocked?"
```
