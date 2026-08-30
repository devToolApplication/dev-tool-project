# KOC Campaign Candidate Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `autonomous-dev-workflow`. Main orchestrates; subagents execute. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build separate table-first Campaign Management and Global Candidate List screens with same-campaign candidate bulk approve/reject backed by `ai-agent-mcrs`.

**Architecture:** Keep `dev-tool-web` as the only UI client and route all KOC operations through `ai-agent-mcrs`. Add additive candidate review-write scope, additive bulk review endpoints, and reuse existing campaign/candidate domain contracts where possible. Shared route/permission/i18n changes are owned by the relevant FE task and must not be edited by sibling tasks without an integration request.

**Tech Stack:** Angular 21, app-* shared UI wrappers, Spring Boot 3.5, Java 21, MongoDB-backed KOC domain, Keycloak scopes/roles.

---

## Source Inputs

- Spec: `docs/superpowers/specs/2026-08-30-koc-campaign-candidate-management-design.md`
- Role handoff: `.roleSession/koc-campaign-candidate-management/20260830-1705 - thiet-ke-campaign-candidate-management.md`
- FE rules: `web/dev-tool-web/CLAUDE.md`
- BE rules: `services/ai-agent-mcrs/CLAUDE.md`
- Core-lib rules: `libs/develop-tool-core-lib/CLAUDE.md`

## Locked Decisions

- Campaign Management and Candidate List are separate routes.
- Both screens stay table-first.
- Candidate List is a global inbox with optional `campaignId` filter.
- Bulk approve/reject is allowed only when all selected rows share one campaign.
- Bulk reject reason is optional per candidate. Blank values are trimmed and omitted. Filled values must be at most 500 chars.
- FE never sends audit fields.
- New write permission: `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`.
- FE never calls `ai-agent-excute-service` directly.

---

## Execution DAG

```text
REQ-LOCK-01 (done: spec locked)
  -> CONTRACT-LOCK-01 (done: API/data/permission contract locked in spec)
      -> BE-KOC-REVIEW-01
      -> FE-KOC-CANDIDATE-01
      -> FE-KOC-CAMPAIGN-01
      -> QA-KOC-MATRIX-01

BE-KOC-REVIEW-01 -> REVIEW-BE-01 -> QA-KOC-API-01
FE-KOC-CANDIDATE-01 -> REVIEW-FE-CANDIDATE-01 -> QA-KOC-UI-01
FE-KOC-CAMPAIGN-01 -> REVIEW-FE-CAMPAIGN-01 -> QA-KOC-UI-01
QA-KOC-MATRIX-01 -> QA-KOC-API-01
QA-KOC-MATRIX-01 -> QA-KOC-UI-01

REVIEW-BE-01 + REVIEW-FE-CANDIDATE-01 + REVIEW-FE-CAMPAIGN-01
  -> INTEGRATION-KOC-01
  -> QA-KOC-LIVE-01
  -> FINAL-GATE-01
```

## Write Ownership Locks

| Task | Agent | Write paths |
|---|---|---|
| `BE-KOC-REVIEW-01` | `dev-be-agent` | `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koc/**`, `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/koc/**` |
| `FE-KOC-CANDIDATE-01` | `dev-fe-agent` | `web/dev-tool-web/src/app/features/koc-management/pages/candidate-list/**`, `web/dev-tool-web/src/app/features/koc-management/model/koc-candidate*`, `web/dev-tool-web/src/app/features/koc-management/model/koc-common.model.ts`, `web/dev-tool-web/src/app/features/koc-management/services/koc-candidate-api.service.ts`, `web/dev-tool-web/src/app/core/auth/permission.service.ts` |
| `FE-KOC-CAMPAIGN-01` | `dev-fe-agent` | `web/dev-tool-web/src/app/features/koc-management/pages/campaign-list/**`, `web/dev-tool-web/src/app/features/koc-management/model/koc-campaign-list.config.ts` |
| `QA-KOC-MATRIX-01` | `test-qa-agent` | `docs/superpowers/test-cases/koc-campaign-candidate-management.md` |
| Review tasks | reviewer/general-purpose | read-only |
| `INTEGRATION-KOC-01` | main/subagent fan-in | only files explicitly requested by completed tasks |

Shared-file rule: if a worker needs a path outside its write ownership, it must return an `integration_request`; it must not edit the file.

---

## Task `BE-KOC-REVIEW-01`: Candidate review-write scope and bulk review API

**Agent:** `dev-be-agent`

**Design dependencies:** `CONTRACT-LOCK-01`

**Runtime dependencies:** none for unit tests.

**Required workflow:** `PREPARE -> IMPLEMENT(TDD) -> SELF_TEST -> SELF_REVIEW -> FINAL_VERIFY -> HANDOFF`

**Required skills by workflow:** `test-driven-development`, `verification-before-completion`, `self-code-review`; use `systematic-debugging` on failing tests.

**Files:**

- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koc/api/candidate/KocCandidateController.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koc/application/review/KocReviewService.java`
- Modify: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koc/api/candidate/response/KocCandidateSummaryResponse.java`
- Create if absent: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koc/api/review/request/KocBulkReviewRequest.java`
- Create if absent: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koc/api/review/request/KocBulkRejectReasonRequest.java`
- Create if absent: `services/ai-agent-mcrs/src/main/java/com/lamld/aiAgent/modules/koc/api/review/response/KocBulkReviewResponse.java`
- Modify: `services/ai-agent-mcrs/src/test/java/com/lamld/aiAgent/modules/koc/application/review/KocReviewServiceTest.java`
- Modify or create controller security tests only if the project already has MVC/security test patterns under `services/ai-agent-mcrs/src/test/java`.

**Forbidden writes:**

- `libs/develop-tool-core-lib/**` unless no service-local permission expression is possible.
- `web/dev-tool-web/**`.

**Acceptance criteria:**

- `POST /v1/admin/koc/candidates/{candidateId}/reviews` requires `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE` or an accepted equivalent mapped authority.
- `POST /v1/admin/koc/candidates/reviews/bulk-approve` accepts non-empty `candidateIds` and approves them.
- `POST /v1/admin/koc/candidates/reviews/bulk-reject` accepts non-empty `candidateIds` plus optional `reasons`.
- Blank bulk reject reasons are allowed and omitted before service logic persists/records them.
- Filled bulk reject reasons are trimmed and rejected when longer than 500 chars.
- Mixed-campaign candidate IDs fail with `CROSS_CAMPAIGN_BULK_NOT_ALLOWED` or the closest existing 422 business exception pattern.
- Single-candidate existing behavior is not weakened unless the spec explicitly says so; bulk optional reason must not accidentally make single review reason optional.
- `KocCandidateSummaryResponse` adds optional `campaignName` only if service query can provide it without breaking existing response construction.

**Verification commands:**

```bash
cd services/ai-agent-mcrs
./mvnw -Dtest=KocReviewServiceTest test
```

If Windows shell lacks `./mvnw`, run:

```powershell
cd services/ai-agent-mcrs; .\mvnw.cmd -Dtest=KocReviewServiceTest test
```

**Expected handoff:** task-result contract with changed files, tests run, self-review findings/fixes, and integration requests.

---

## Task `FE-KOC-CANDIDATE-01`: Global Candidate List table, selection, and bulk actions

**Agent:** `dev-fe-agent`

**Design dependencies:** `CONTRACT-LOCK-01`

**Runtime dependencies:** `BE-KOC-REVIEW-01` blocks only live/integration verification, not component implementation.

**Required workflow:** `PREPARE -> IMPLEMENT(TDD) -> SELF_TEST -> SELF_UI_CODE_REVIEW -> FINAL_VERIFY -> HANDOFF`

**Required skills by workflow:** `test-driven-development`, `verification-before-completion`, `self-code-review`; use `systematic-debugging` on failures.

**Files:**

- Modify: `web/dev-tool-web/src/app/features/koc-management/pages/candidate-list/candidate-list.component.ts`
- Modify: `web/dev-tool-web/src/app/features/koc-management/pages/candidate-list/candidate-list.component.html`
- Modify: `web/dev-tool-web/src/app/features/koc-management/pages/candidate-list/candidate-list.component.scss`
- Modify: `web/dev-tool-web/src/app/features/koc-management/pages/candidate-list/candidate-list.component.spec.ts`
- Modify: `web/dev-tool-web/src/app/features/koc-management/model/koc-candidate.model.ts`
- Create if useful: `web/dev-tool-web/src/app/features/koc-management/model/koc-candidate-list.config.ts`
- Modify: `web/dev-tool-web/src/app/features/koc-management/model/koc-common.model.ts`
- Modify: `web/dev-tool-web/src/app/features/koc-management/services/koc-candidate-api.service.ts`
- Modify: `web/dev-tool-web/src/app/core/auth/permission.service.ts`

**Forbidden writes:**

- `web/dev-tool-web/src/app/features/koc-management/pages/campaign-list/**`
- `web/dev-tool-web/src/app/features/koc-management/model/koc-campaign-list.config.ts`
- `services/**`
- direct PrimeNG usage.

**Acceptance criteria:**

- Candidate List uses `app-table` selection/bulk action support or returns a documented integration request if `app-table` is missing a required hook.
- URL filters keep working: `campaignId`, `search`, `decision`, `executionStatus`, `rejectReason`, `minFollowers`, `maxFollowers`, pagination.
- Bulk toolbar appears only when selected rows exist.
- Bulk approve/reject actions are disabled when selected rows span multiple campaigns and helper text explains the same-campaign rule.
- Bulk approve uses `ConfirmDialogService` and calls `KocCandidateApiService.bulkApproveCandidates({ candidateIds })`.
- Bulk reject uses `app-dialog` with one input/textarea per selected candidate.
- Bulk reject reason is optional: empty/blank strings do not block submit and are omitted from request `reasons`.
- Filled bulk reject reason over 500 chars blocks submit with i18n validation text.
- Success clears selection, reloads the current page, and preserves URL filters.
- Error toast/message uses BE response message when available; no hardcoded replacement message.
- User-visible text uses the project i18n pattern.
- No direct `ai-agent-excute-service` calls.

**Verification commands:**

```bash
cd web/dev-tool-web
npm test -- --runInBand candidate-list
```

If the project uses Vitest/Karma command names instead, inspect `package.json` and run the narrowest existing equivalent for `candidate-list.component.spec.ts`, then run the normal type/build check:

```bash
cd web/dev-tool-web
npm run build
```

**Expected handoff:** task-result contract with changed files, commands, screenshots only if easy/local, self-review findings/fixes, and integration requests.

---

## Task `FE-KOC-CAMPAIGN-01`: Campaign Management row actions and permission cleanup

**Agent:** `dev-fe-agent`

**Design dependencies:** `CONTRACT-LOCK-01`

**Runtime dependencies:** existing campaign endpoints block only live verification.

**Required workflow:** `PREPARE -> IMPLEMENT(TDD) -> SELF_TEST -> SELF_UI_CODE_REVIEW -> FINAL_VERIFY -> HANDOFF`

**Files:**

- Modify: `web/dev-tool-web/src/app/features/koc-management/pages/campaign-list/campaign-list.component.ts`
- Modify: `web/dev-tool-web/src/app/features/koc-management/pages/campaign-list/campaign-list.component.html`
- Modify: `web/dev-tool-web/src/app/features/koc-management/pages/campaign-list/campaign-list.component.scss`
- Modify: `web/dev-tool-web/src/app/features/koc-management/pages/campaign-list/campaign-list.component.spec.ts`
- Modify: `web/dev-tool-web/src/app/features/koc-management/model/koc-campaign-list.config.ts`

**Forbidden writes:**

- `web/dev-tool-web/src/app/features/koc-management/pages/candidate-list/**`
- `web/dev-tool-web/src/app/features/koc-management/services/koc-candidate-api.service.ts`
- `web/dev-tool-web/src/app/core/auth/permission.service.ts` unless returned as integration request first.
- `services/**`.

**Acceptance criteria:**

- Campaign list remains table-first and keeps search/status/page filters.
- Primary CTA for create campaign is visible in first viewport if route already exists.
- Row actions include open detail, edit, start, pause, resume, clone, stop.
- Lifecycle action visibility respects campaign status and existing API service methods.
- Lifecycle actions require existing workflow-write permission in UI gating if current codebase exposes a permission helper in the component pattern.
- Stateful/destructive actions stay in row action menu and use existing confirmation/error patterns.
- Success after mutation reloads current page and preserves filters.
- User-visible text uses project i18n pattern.

**Verification commands:**

```bash
cd web/dev-tool-web
npm test -- --runInBand campaign-list
npm run build
```

Use the narrowest equivalent test command if this repo does not use Jest-style flags.

**Expected handoff:** task-result contract with changed files, tests, self-review findings/fixes, and integration requests.

---

## Task `QA-KOC-MATRIX-01`: Test matrix and deterministic test data plan

**Agent:** `test-qa-agent`

**Design dependencies:** `CONTRACT-LOCK-01`

**Runtime dependencies:** none.

**Required workflow:** `READ_REQUIREMENTS -> PARALLEL_TEST_PREP -> TEST_MATRIX -> DESIGN_TESTS -> PREPARE_DATA -> SELF_REVIEW_COVERAGE -> REPORT`

**Files:**

- Create: `docs/superpowers/test-cases/koc-campaign-candidate-management.md`

**Forbidden writes:**

- `web/**`
- `services/**`
- production code.

**Acceptance criteria:**

- Trace each locked spec requirement to at least one test.
- Include FE component tests, BE API/service tests, permission tests, and local live E2E checklist.
- Include edge cases: empty selection, duplicate IDs, missing candidate, mixed campaigns, blank reject reason, 501-char reject reason, BE error message display, page reload preserves filters.
- Include role/scope matrix for `AI_AGENT_READ`, `AI_AGENT_WORKFLOW_WRITE`, `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`.
- Include deterministic candidate fixture plan with same-campaign and cross-campaign rows.

**Verification commands:** none required, doc review only.

**Expected handoff:** task-result contract with test matrix path and coverage self-review.

---

## Rolling Independent Reviews

### `REVIEW-BE-01`

**Agent:** reviewer/general-purpose acting as independent reviewer.

**Starts after:** `BE-KOC-REVIEW-01` self-gate PASS.

**Read-only scope:** BE diff, spec, BE rules.

**Fail gate on:** missing scope enforcement, cross-campaign guard gap, optional reason mishandling, audit fields accepted from FE, swallowed errors, untested business behavior.

### `REVIEW-FE-CANDIDATE-01`

**Agent:** reviewer/general-purpose acting as independent reviewer.

**Starts after:** `FE-KOC-CANDIDATE-01` self-gate PASS.

**Read-only scope:** Candidate List diff, app-table usage, i18n, a11y, permission gating, API calls.

**Fail gate on:** direct third-party UI component use, hardcoded user text, cross-campaign actions enabled, blank reason blocked, stale selection after success, direct execute-service calls.

### `REVIEW-FE-CAMPAIGN-01`

**Agent:** reviewer/general-purpose acting as independent reviewer.

**Starts after:** `FE-KOC-CAMPAIGN-01` self-gate PASS.

**Read-only scope:** Campaign List diff, action visibility, i18n, permission gating, API calls.

**Fail gate on:** lifecycle actions shown in invalid states, filters not preserved, non-shared UI components, route/action mismatch.

---

## Integration Task `INTEGRATION-KOC-01`

**Starts after:** all implementation tasks and rolling reviews PASS or return bounded integration requests.

**Purpose:** Apply only fan-in changes that could not safely be done by parallel workers.

**Likely fan-in files:**

- `web/dev-tool-web/src/app/features/koc-management/koc-management.routes.ts`
- i18n dictionary files if shared and not owned by a single FE task.
- shared table method `clearSelection()` only if Candidate List cannot clear selection through existing inputs/state.

**Acceptance criteria:**

- No behavior redesign.
- Shared edits are minimal and trace to explicit integration requests.
- Affected BE and FE tests are rerun because shared code invalidates previous evidence.

---

## Local Live QA Task `QA-KOC-LIVE-01`

**Agent:** `test-qa-agent`

**Starts after:** integration PASS and local services can run.

**Acceptance criteria:**

- Start required local BE/FE services using existing project commands only.
- Exercise Campaign List filter/open/lifecycle UI where safe.
- Exercise Candidate List same-campaign bulk approve/reject with blank and filled reason.
- Confirm mixed-campaign selection blocks before submit.
- Confirm backend logs have no exceptions/errors for tested flows.
- Stop dev server after testing.

**Blocked is allowed only if:** required local dependencies/secrets/data are unavailable. The report must state the missing dependency and which unit/integration evidence still passed.

---

## Final Gate `FINAL-GATE-01`

Feature is complete only when all current evidence is PASS:

- BE implementation self-gate PASS.
- FE Candidate implementation self-gate PASS.
- FE Campaign implementation self-gate PASS.
- Independent reviews PASS.
- Integration checks PASS.
- QA matrix complete.
- Local live QA PASS or explicitly BLOCKED by unavailable external dependency with actionable unblocker.
- No unresolved BLOCKER/HIGH findings.

## Lazy Alternative

Skip campaign-list cleanup for this pass and ship only candidate bulk review. Add campaign action cleanup when operators report lifecycle friction. Current selected scope includes both, so the DAG keeps both tasks.
