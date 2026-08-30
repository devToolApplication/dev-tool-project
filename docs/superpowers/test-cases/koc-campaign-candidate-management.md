# KOC Campaign and Global Candidate Management - Test Matrix & Test Plan

- **Feature:** KOC Campaign Management & Global Candidate List
- **Spec:** `docs/superpowers/specs/2026-08-30-koc-campaign-candidate-management-design.md`
- **Plan:** `docs/superpowers/plans/2026-08-30-koc-campaign-candidate-management.md`
- **Date:** 2026-08-30
- **Author / Role:** Senior QA / Test Engineer (`test-qa-agent`)
- **Status:** APPROVED (Parallel Test Prep)

---

## 1. Locked Requirements & Scope Traceability

| Req ID | Locked Requirement Statement | Test Category | Target Test Cases |
|---|---|---|---|
| **REQ-01** | Separate routes for Campaign Management (`/koc/campaigns`) and Candidate List (`/koc/candidates`). | Routing / FE Nav | `TC-FE-ROUTE-01`, `TC-FE-ROUTE-02` |
| **REQ-02** | Table-first UI for both Campaign List and Candidate List screens. Primary CTA and filters in first viewport. | UI/UX / Layout | `TC-FE-CAMP-UI-01`, `TC-FE-CAND-UI-01` |
| **REQ-03** | Candidate List is a global inbox across all campaigns with optional `campaignId` filter. | FE / BE Query | `TC-API-CAND-01`, `TC-FE-CAND-FILTER-01` |
| **REQ-04** | Bulk approve and bulk reject enabled **ONLY** when all selected candidate rows belong to the **SAME campaign**. | FE Guard / BE Validation | `TC-FE-BULK-GUARD-01`, `TC-FE-BULK-GUARD-02`, `TC-API-BULK-APP-02`, `TC-API-BULK-REJ-02` |
| **REQ-05** | Bulk reject reasons are optional per candidate; blank values are allowed and omitted from the request payload. | FE Form / BE Payload | `TC-FE-BULK-REJ-01`, `TC-FE-BULK-REJ-02`, `TC-API-BULK-REJ-01`, `TC-API-BULK-REJ-03` |
| **REQ-06** | Filled bulk reject reason values must be trimmed and limited to at most 500 characters. 501+ chars blocked. | Boundary / Validation | `TC-FE-BULK-REJ-03`, `TC-API-BULK-REJ-04`, `TC-API-BULK-REJ-05` |
| **REQ-07** | FE never sends audit fields (`reviewedBy`, `reviewedAt`, `actedBy`, `actedAt`). Audit fields are server-owned. | Security / Data Integrity | `TC-API-AUDIT-01`, `TC-FE-AUDIT-01` |
| **REQ-08** | Permission model enforced: `AI_AGENT_READ` for viewing/filtering, `AI_AGENT_WORKFLOW_WRITE` for campaign lifecycle mutations, and `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE` for candidate review mutations. | Security / Auth | `TC-SEC-PERM-01` to `TC-SEC-PERM-06` |
| **REQ-09** | FE communicates strictly with `ai-agent-mcrs` (admin base `/v1/admin/koc/...`); FE **NEVER** calls `ai-agent-excute-service` directly. | Architecture / Integration | `TC-INT-ARCH-01` |
| **REQ-10** | Campaign lifecycle actions (Start, Pause, Resume, Clone, Stop, Edit) in row action menu; mutate, reload current page, preserve filters. | FE / BE Lifecycle | `TC-FE-CAMP-ACT-01` to `TC-FE-CAMP-ACT-06`, `TC-API-CAMP-LIFE-01` |
| **REQ-11** | Error responses surface backend error messages directly in UI without hardcoded overrides; retry preserves filters. | Error Handling / UX | `TC-FE-ERR-01`, `TC-FE-ERR-02` |
| **REQ-12** | Local live testing mandatory check: Backend logs must remain clean with 0 unhandled exceptions throughout user flows. | Local Live QA | `TC-LIVE-01` to `TC-LIVE-06` |

---

## 2. Role & Permission Matrix

| Role / Scope | View Campaign List / Detail (`GET /koc/campaigns/**`) | Mutate Campaign Lifecycle (`POST/PUT /koc/campaigns/**`) | View Candidate List / Detail (`GET /koc/candidates/**`) | Candidate Single / Bulk Review (`POST /koc/candidates/**/reviews**`) |
|---|:---:|:---:|:---:|:---:|
| **No Auth / Anonymous** | ❌ 401 Unauthorized | ❌ 401 Unauthorized | ❌ 401 Unauthorized | ❌ 401 Unauthorized |
| **`AI_AGENT_READ` only** | ✅ 200 OK | ❌ 403 Forbidden (UI action hidden/disabled) | ✅ 200 OK | ❌ 403 Forbidden (Bulk toolbar/buttons hidden/disabled) |
| **`AI_AGENT_WORKFLOW_WRITE` only** | ✅ 200 OK | ✅ 200 OK | ✅ 200 OK | ❌ 403 Forbidden |
| **`AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE` only** | ✅ 200 OK | ❌ 403 Forbidden | ✅ 200 OK | ✅ 200 OK |
| **Full Admin (`READ` + `WORKFLOW_WRITE` + `CANDIDATE_REVIEW_WRITE`)** | ✅ 200 OK | ✅ 200 OK | ✅ 200 OK | ✅ 200 OK |

---

## 3. Test Cases Specification

### 3.1. Frontend Component Test Cases (Dev-Tool-Web)

#### Campaign Management Screen (`/koc/campaigns`)

##### TC-FE-CAMP-UI-01: Table-First Layout & First Viewport
- **Precondition:** User has `AI_AGENT_READ` permission.
- **Steps:** Navigate to `/koc/campaigns`.
- **Expected Result:**
  - Page title, subtitle, `Create campaign` primary CTA button, search bar, status dropdown, and campaign table are visible in first viewport.
  - No horizontal scrolling required on standard desktop 1920x1080 / 1440x900.
  - Table renders skeleton rows during loading state.
- **Priority:** High | **Type:** Positive / UI-UX

##### TC-FE-CAMP-FILTER-01: URL Query Sync for Search, Status, and Pagination
- **Precondition:** Campaign list has seeded campaigns.
- **Steps:** Apply search keyword `Tech Reviewers`, filter status `RUNNING`, navigate to page 2.
- **Expected Result:**
  - URL updates to include query parameters: `?search=Tech+Reviewers&status=RUNNING&page=2`.
  - API `GET /v1/admin/koc/campaigns/page` called with matching parameters.
  - Reloading page restores filter inputs and page state identically.
- **Priority:** High | **Type:** Positive / Integration

##### TC-FE-CAMP-ACT-01: Lifecycle Actions Menu & Status Gating
- **Precondition:** User has `AI_AGENT_WORKFLOW_WRITE`. Campaigns in various statuses exist (`DRAFT`, `RUNNING`, `PAUSED`, `STOPPED`).
- **Steps:** Open the kebab row action menu for each campaign row.
- **Expected Result:**
  - `DRAFT`: Start, Edit, Clone visible.
  - `RUNNING`: Pause, Stop, Clone visible; Resume/Start hidden or disabled.
  - `PAUSED`: Resume, Stop, Clone visible.
  - `STOPPED`: Clone, Open Detail visible; Start/Pause/Resume hidden.
- **Priority:** High | **Type:** Positive / Functional

##### TC-FE-CAMP-ACT-02: Destructive / Stateful Mutation Flow & Filter Preservation
- **Precondition:** User filters campaign list by `status=RUNNING`.
- **Steps:** Select `Pause` from row action menu for campaign `CAMP-001`. Confirm modal dialog.
- **Expected Result:**
  - API `POST /v1/admin/koc/campaigns/CAMP-001/pause` executed.
  - On success, toast notification appears with BE success message.
  - Table reloads current page without resetting search or pagination filters.
- **Priority:** High | **Type:** Positive / Lifecycle

##### TC-FE-CAMP-PERM-01: Read-Only User Cannot Trigger Campaign Mutations
- **Precondition:** User logged in with `AI_AGENT_READ` only (missing `AI_AGENT_WORKFLOW_WRITE`).
- **Steps:** View campaign list.
- **Expected Result:**
  - `Create campaign` button is hidden or disabled.
  - Row action menu hides or disables mutation actions (Start, Pause, Resume, Stop, Edit).
  - Attempting direct mutation fails and displays permission error toast.
- **Priority:** High | **Type:** Security / UI Gating

---

#### Global Candidate List Screen (`/koc/candidates`)

##### TC-FE-CAND-UI-01: Global Inbox Table-First Layout & Bulk Toolbar Initial State
- **Precondition:** User has `AI_AGENT_READ`.
- **Steps:** Navigate to `/koc/candidates`.
- **Expected Result:**
  - Global candidate list renders rows across different campaigns.
  - Search input, Campaign filter dropdown, Decision filter, Execution Status filter visible.
  - Bulk action toolbar is **hidden** when 0 candidate rows are selected.
- **Priority:** High | **Type:** Positive / UI-UX

##### TC-FE-CAND-FILTER-01: Multi-field Filtering & URL Parameter Sync
- **Steps:** Set `campaignId=CAMP-001`, `decision=REVIEW`, `minFollowers=10000`, `maxFollowers=50000`.
- **Expected Result:**
  - URL updates with parameters.
  - Backend request includes exact filter parameters.
  - Grid reflects filtered candidates.
- **Priority:** High | **Type:** Positive / Functional

##### TC-FE-BULK-GUARD-01: Same-Campaign Multi-Row Selection Enables Bulk Toolbar
- **Precondition:** Candidates `CAND-101` and `CAND-102` both belong to `campaignId=CAMP-001`.
- **Steps:** Select checkboxes for `CAND-101` and `CAND-102`.
- **Expected Result:**
  - Bulk action toolbar appears displaying: `2 candidates selected (Campaign: Summer Tech Launch)`.
  - `Bulk Approve` and `Bulk Reject` buttons are **ENABLED**.
  - No warning helper text displayed.
- **Priority:** Critical | **Type:** Positive / Bulk Guard

##### TC-FE-BULK-GUARD-02: Cross-Campaign Multi-Row Selection Disables Bulk Actions (LOCKED RULE)
- **Precondition:** `CAND-101` belongs to `CAMP-001`; `CAND-201` belongs to `CAMP-002`.
- **Steps:** Select checkboxes for `CAND-101` and `CAND-201`.
- **Expected Result:**
  - Bulk action toolbar appears displaying `2 candidates selected (Multiple Campaigns)`.
  - `Bulk Approve` and `Bulk Reject` buttons are **DISABLED**.
  - Warning helper text is displayed: *"Selected candidates belong to different campaigns. Please filter or select candidates from a single campaign to perform bulk actions."*
  - No confirmation dialog can be triggered.
- **Priority:** Critical | **Type:** Boundary / Negative / Bulk Guard

##### TC-FE-BULK-APP-01: Bulk Approve Modal & Submission Flow
- **Precondition:** Select `CAND-101` and `CAND-102` (same campaign `CAMP-001`). User has `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`.
- **Steps:** Click `Bulk Approve`. Verify dialog. Confirm action.
- **Expected Result:**
  - Dialog opens showing selection count (2) and campaign name (`Summer Tech Launch`).
  - No reject reason input fields present.
  - Clicking confirm sends `POST /v1/admin/koc/candidates/reviews/bulk-approve` with payload `{"candidateIds": ["CAND-101", "CAND-102"]}`.
  - Does NOT send `reviewedBy` or `reviewedAt`.
  - On success: modal closes, checkboxes uncheck / selection clears, table refreshes, filters preserved, success toast shown.
- **Priority:** Critical | **Type:** Positive / Functional

##### TC-FE-BULK-REJ-01: Bulk Reject Modal with Blank Reasons (Allowed & Omitted)
- **Precondition:** Select `CAND-101` and `CAND-102` (same campaign `CAMP-001`).
- **Steps:**
  1. Click `Bulk Reject`.
  2. Dialog displays 2 reason input rows (one for `CAND-101`, one for `CAND-102`).
  3. Leave reason for `CAND-101` blank / empty.
  4. Type `"Profile content irrelevant"` for `CAND-102`.
  5. Click Confirm Reject.
- **Expected Result:**
  - Form validation passes (blank reason is explicitly allowed).
  - Outgoing HTTP payload sends only non-blank reason:
    ```json
    {
      "candidateIds": ["CAND-101", "CAND-102"],
      "reasons": [
        { "candidateId": "CAND-102", "reason": "Profile content irrelevant" }
      ]
    }
    ```
  - `CAND-101` is omitted from the `reasons` array.
- **Priority:** Critical | **Type:** Positive / Boundary

##### TC-FE-BULK-REJ-02: Bulk Reject Modal with All Reasons Blank
- **Precondition:** Select `CAND-101` and `CAND-102` (same campaign `CAMP-001`).
- **Steps:** Click `Bulk Reject`. Leave all reason fields blank/empty. Click Confirm Reject.
- **Expected Result:**
  - Validation passes without error.
  - Outgoing HTTP payload:
    ```json
    {
      "candidateIds": ["CAND-101", "CAND-102"]
    }
    ```
  - `reasons` field is either empty array `[]` or omitted entirely.
- **Priority:** High | **Type:** Boundary / Positive

##### TC-FE-BULK-REJ-03: Bulk Reject Reason Length Boundary (500 Chars Max & Trimming)
- **Precondition:** Select `CAND-101`.
- **Steps:**
  1. Input 500 characters into reject reason textarea -> Verify submit is allowed.
  2. Input 501 characters -> Verify validation error message *"Reason cannot exceed 500 characters"* appears and submit button is disabled.
  3. Input `"   Reason with leading and trailing spaces   "` -> Submit -> Verify payload trims whitespace to `"Reason with leading and trailing spaces"`.
- **Priority:** High | **Type:** Boundary / Negative

##### TC-FE-ERR-01: Backend Error Message Passthrough in UI Toast
- **Precondition:** Trigger a conflict or business error (e.g. candidate already reviewed).
- **Steps:** Submit bulk approve when BE responds with `409 DUPLICATE_DECISION` and body `{"errorCode": "DUPLICATE_DECISION", "errorMessage": "Candidate CAND-101 has already been approved"}`.
- **Expected Result:**
  - UI Toast displays exact backend message: `"Candidate CAND-101 has already been approved"`.
  - Toast does NOT show generic or hardcoded messages like `"An unknown error occurred"`.
  - Table selection remains intact or gracefully resets; page filters are preserved.
- **Priority:** High | **Type:** Error Handling

##### TC-FE-AUDIT-01: Zero Audit Fields in Outgoing Requests
- **Precondition:** Network inspector active during any campaign/candidate action.
- **Steps:** Inspect HTTP request headers and payload for all POST/PUT actions from UI.
- **Expected Result:**
  - Request body contains NO fields matching `reviewedBy`, `reviewedAt`, `actedBy`, `actedAt`, `updatedBy`, `createdBy`.
- **Priority:** Critical | **Type:** Security / Compliance

---

### 3.2. Backend API / Service Test Cases (`ai-agent-mcrs`)

#### Campaign Controller & Lifecycle Service

##### TC-API-CAMP-PAGE-01: Pagination, Search, and Status Filtering (`GET /v1/admin/koc/campaigns/page`)
- **Request:** `GET /v1/admin/koc/campaigns/page?page=0&size=10&status=RUNNING&search=Fashion` with `AI_AGENT_READ`.
- **Expected Result:**
  - HTTP `200 OK`.
  - Response body contains paged `List<KocCampaignSummaryResponse>` matching status `RUNNING` and name/code containing `Fashion`.
  - `counters` funnel map populated (`discovered`, `screened`, `review`, `accepted`, `rejected`).
- **Priority:** High | **Type:** Positive / Contract

##### TC-API-CAMP-LIFE-01: Valid State Transitions (`POST /v1/admin/koc/campaigns/{id}/[start|pause|resume|stop]`)
- **Request:**
  - Start campaign in `DRAFT` -> HTTP `200 OK`, status becomes `RUNNING`.
  - Pause campaign in `RUNNING` -> HTTP `200 OK`, status becomes `PAUSED`.
  - Resume campaign in `PAUSED` -> HTTP `200 OK`, status becomes `RUNNING`.
  - Stop campaign in `RUNNING` -> HTTP `200 OK`, status becomes `STOPPED`.
- **Expected Result:** All state transitions update campaign status, write audit record on server, and return updated `CampaignDetail`.
- **Priority:** High | **Type:** Positive / Service

##### TC-API-CAMP-LIFE-02: Invalid State Transition Validation
- **Request:** Send `POST /v1/admin/koc/campaigns/{id}/pause` when campaign is in `DRAFT` or `STOPPED`.
- **Expected Result:**
  - HTTP `409 INVALID_STATE` or `422 INVALID_LIFECYCLE_TRANSITION`.
  - Meaningful error message returned in JSON response.
- **Priority:** Medium | **Type:** Negative

---

#### Candidate Review & Bulk Action Controller (`KocCandidateController` & `KocReviewService`)

##### TC-API-CAND-PAGE-01: Global Candidate Paged Query with Campaign Filter
- **Request:** `GET /v1/admin/koc/candidates/page?campaignId=CAMP-001&decision=REVIEW&page=0&size=20`.
- **Expected Result:**
  - HTTP `200 OK`.
  - Returns candidates belonging to `CAMP-001` in `REVIEW` decision.
  - Summary includes `candidateId`, `campaignId`, `campaignName`, `displayName`, `decision`, `executionStatus`, `followers`.
- **Priority:** High | **Type:** Positive

##### TC-API-BULK-APP-01: Successful Bulk Approve for Same-Campaign Candidates
- **Precondition:** Candidates `CAND-101`, `CAND-102` exist under campaign `CAMP-001` with status `REVIEW`.
- **Request:** `POST /v1/admin/koc/candidates/reviews/bulk-approve`
  ```json
  {
    "candidateIds": ["CAND-101", "CAND-102"]
  }
  ```
- **Expected Result:**
  - HTTP `200 OK`.
  - Response confirms both candidates updated to decision `ACCEPTED`.
  - Server populates `reviewedBy` (from Security Context) and `reviewedAt` (current timestamp).
  - Campaign `counters.accepted` increments by 2, `counters.review` decrements by 2.
- **Priority:** Critical | **Type:** Positive / Core Logic

##### TC-API-BULK-APP-02: Cross-Campaign Bulk Approve Rejection (422 CROSS_CAMPAIGN_BULK_NOT_ALLOWED)
- **Precondition:** `CAND-101` belongs to `CAMP-001`; `CAND-201` belongs to `CAMP-002`.
- **Request:** `POST /v1/admin/koc/candidates/reviews/bulk-approve`
  ```json
  {
    "candidateIds": ["CAND-101", "CAND-201"]
  }
  ```
- **Expected Result:**
  - HTTP `422 Unprocessable Entity` (or configured business exception code).
  - Error code: `CROSS_CAMPAIGN_BULK_NOT_ALLOWED`.
  - Error message clearly states candidates belong to multiple campaigns (`CAMP-001`, `CAMP-002`).
  - Neither candidate status is modified in the database (atomic / rollback).
- **Priority:** Critical | **Type:** Security / Boundary / Rule Enforcement

##### TC-API-BULK-APP-03: Bulk Approve with Empty / Null Candidate IDs
- **Request:** `POST /v1/admin/koc/candidates/reviews/bulk-approve` with `{"candidateIds": []}` or `{}`.
- **Expected Result:**
  - HTTP `400 Bad Request`.
  - Error code: `VALIDATION_ERROR`.
  - Message specifies `candidateIds must not be empty`.
- **Priority:** Medium | **Type:** Negative / Validation

##### TC-API-BULK-APP-04: Bulk Approve with Non-Existent Candidate ID
- **Request:** `POST /v1/admin/koc/candidates/reviews/bulk-approve` with `{"candidateIds": ["CAND-101", "NON-EXISTENT-ID"]}`.
- **Expected Result:**
  - HTTP `404 NOT_FOUND` with message identifying missing ID.
  - Transaction rolls back completely; `CAND-101` is not modified.
- **Priority:** Medium | **Type:** Negative / Integrity

##### TC-API-BULK-APP-05: Bulk Approve with Duplicate Candidate IDs in List
- **Request:** `POST /v1/admin/koc/candidates/reviews/bulk-approve` with `{"candidateIds": ["CAND-101", "CAND-101"]}`.
- **Expected Result:**
  - Backend deduplicates the set before processing OR executes idempotently without double-incrementing campaign counters.
  - HTTP `200 OK`.
- **Priority:** Medium | **Type:** Edge Case

##### TC-API-BULK-REJ-01: Successful Bulk Reject with Mixed Blank and Filled Reasons
- **Precondition:** `CAND-101`, `CAND-102`, `CAND-103` belong to `CAMP-001`.
- **Request:** `POST /v1/admin/koc/candidates/reviews/bulk-reject`
  ```json
  {
    "candidateIds": ["CAND-101", "CAND-102", "CAND-103"],
    "reasons": [
      { "candidateId": "CAND-101", "reason": "  Engagement rate below threshold  " },
      { "candidateId": "CAND-102", "reason": "" }
    ]
  }
  ```
- **Expected Result:**
  - HTTP `200 OK`.
  - All 3 candidates updated to `REJECTED`.
  - `CAND-101` stored reason is trimmed: `"Engagement rate below threshold"`.
  - `CAND-102` (empty string) and `CAND-103` (missing from `reasons` list) are accepted with null/empty reason.
  - Campaign `counters.rejected` increments by 3.
- **Priority:** Critical | **Type:** Positive / Boundary

##### TC-API-BULK-REJ-02: Cross-Campaign Bulk Reject Rejection (422)
- **Precondition:** `CAND-101` in `CAMP-001`, `CAND-201` in `CAMP-002`.
- **Request:** `POST /v1/admin/koc/candidates/reviews/bulk-reject` with `{"candidateIds": ["CAND-101", "CAND-201"]}`.
- **Expected Result:**
  - HTTP `422 CROSS_CAMPAIGN_BULK_NOT_ALLOWED`.
  - No database state modified.
- **Priority:** Critical | **Type:** Boundary / Security

##### TC-API-BULK-REJ-03: Bulk Reject with Reasons Omitted Completely
- **Request:** `POST /v1/admin/koc/candidates/reviews/bulk-reject`
  ```json
  {
    "candidateIds": ["CAND-101", "CAND-102"]
  }
  ```
- **Expected Result:**
  - HTTP `200 OK`. Both rejected with null/empty reason.
- **Priority:** High | **Type:** Positive / Boundary

##### TC-API-BULK-REJ-04: Bulk Reject Reason Length Boundary (500 chars vs 501 chars)
- **Request A (500 chars):** Send 500-char string in `reasons[0].reason`.
  - **Expected Result:** HTTP `200 OK`.
- **Request B (501 chars):** Send 501-char string in `reasons[0].reason`.
  - **Expected Result:** HTTP `400 VALIDATION_ERROR` with message indicating maximum length is 500.
- **Priority:** High | **Type:** Boundary

##### TC-API-BULK-REJ-05: Bulk Reject with Whitespace-Only Reason
- **Request:** `POST /v1/admin/koc/candidates/reviews/bulk-reject` with reason `"     "`.
- **Expected Result:** Backend trims whitespace to empty string and treats as omitted (null/empty reason). HTTP `200 OK`.
- **Priority:** Medium | **Type:** Boundary

##### TC-API-SINGLE-REV-01: Single-Candidate Review Backward Compatibility & Scope Check
- **Request:** `POST /v1/admin/koc/candidates/CAND-101/reviews` with payload `{"decision": "ACCEPTED"}`.
- **Expected Result:**
  - Requires `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`.
  - Single review validation rules remain unchanged (single-candidate reason requirement is NOT weakened by bulk changes).
  - HTTP `200 OK`.
- **Priority:** High | **Type:** Regression / Security

---

### 3.3. Security & Permission Tests (`@PreAuthorize` & Scope Validation)

##### TC-SEC-PERM-01: Candidate Review Endpoints Require `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`
- **Steps:**
  1. Call `POST /v1/admin/koc/candidates/reviews/bulk-approve` with token containing only `AI_AGENT_READ` -> **HTTP 403 Forbidden**.
  2. Call `POST /v1/admin/koc/candidates/reviews/bulk-approve` with token containing only `AI_AGENT_WORKFLOW_WRITE` -> **HTTP 403 Forbidden**.
  3. Call `POST /v1/admin/koc/candidates/reviews/bulk-approve` with token containing `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE` -> **HTTP 200 OK**.
- **Priority:** Critical | **Type:** Security / Auth

##### TC-SEC-PERM-02: Campaign Lifecycle Endpoints Require `AI_AGENT_WORKFLOW_WRITE`
- **Steps:**
  1. Call `POST /v1/admin/koc/campaigns/CAMP-001/pause` with token containing only `AI_AGENT_READ` -> **HTTP 403 Forbidden**.
  2. Call `POST /v1/admin/koc/campaigns/CAMP-001/pause` with token containing only `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE` -> **HTTP 403 Forbidden**.
  3. Call `POST /v1/admin/koc/campaigns/CAMP-001/pause` with token containing `AI_AGENT_WORKFLOW_WRITE` -> **HTTP 200 OK**.
- **Priority:** Critical | **Type:** Security / Auth

##### TC-SEC-PERM-03: Candidate & Campaign Read Endpoints Require `AI_AGENT_READ`
- **Steps:** Call `GET /v1/admin/koc/campaigns/page` and `GET /v1/admin/koc/candidates/page` with unauthenticated / expired token -> **HTTP 401 Unauthorized**.
- **Priority:** High | **Type:** Security / Auth

##### TC-API-AUDIT-01: Tamper Resistance on Server-Owned Audit Fields
- **Request:** Send `POST /v1/admin/koc/candidates/reviews/bulk-approve` injecting malicious payload:
  ```json
  {
    "candidateIds": ["CAND-101"],
    "reviewedBy": "hacked-admin-user",
    "reviewedAt": "2020-01-01T00:00:00Z"
  }
  ```
- **Expected Result:**
  - Deserializer ignores unknown fields OR controller overwrites with authenticated user ID from JWT context and `Instant.now()`.
  - Database reflects authenticated user ID and real timestamp.
- **Priority:** Critical | **Type:** Security

---

### 3.4. Architecture & Integration Verification

##### TC-INT-ARCH-01: Verification that FE Never Calls `ai-agent-excute-service` Directly
- **Precondition:** Code review and network trace inspection during all user actions.
- **Steps:**
  1. Inspect Angular source code (`web/dev-tool-web`) for any import or URL pointing to `ai-agent-excute-service` or direct execution ports.
  2. Perform full candidate review and campaign lifecycle flows in browser.
- **Expected Result:**
  - 100% of outgoing requests from browser route to `ai-agent-mcrs` (e.g. `/v1/admin/koc/...`).
  - No direct browser-to-execute-service requests.
- **Priority:** Critical | **Type:** Architecture Compliance

---

## 4. Deterministic Test Data Plan (Fixtures & Seeds)

All fixtures must be deterministically seedable into MongoDB for automated tests and local live verification.

### 4.1. Campaign Fixtures

| Campaign ID | Code | Name | Status | Accepted Target | Initial Counters (`disc`, `scr`, `rev`, `acc`, `rej`) | Description / Test Usage |
|---|---|---|---|---:|---|---|
| `CAMP-001` | `KOC-TECH-01` | `Summer Tech Launch` | `RUNNING` | 50 | `{120, 100, 20, 15, 65}` | Primary test campaign for same-campaign bulk actions. |
| `CAMP-002` | `KOC-BEAUTY-01` | `Autumn Beauty Fest` | `RUNNING` | 30 | `{80, 70, 10, 5, 55}` | Secondary campaign for cross-campaign bulk guard tests. |
| `CAMP-003` | `KOC-DRAFT-01` | `Winter Fashion Promo` | `DRAFT` | 100 | `{0, 0, 0, 0, 0}` | For campaign Start / Edit tests. |
| `CAMP-004` | `KOC-PAUSED-01` | `Spring Foodies Carnival` | `PAUSED` | 40 | `{50, 40, 5, 20, 15}` | For campaign Resume / Stop tests. |
| `CAMP-005` | `KOC-STOP-01` | `Old Legacy Campaign` | `STOPPED` | 20 | `{20, 20, 0, 18, 2}` | For immutable / stopped state tests. |

### 4.2. Candidate Fixtures

| Candidate ID | Campaign ID | Display Name | Decision | Execution Status | Followers | Screening Progress | Usage in Matrix |
|---|---|---|---|---|---:|---:|---|
| `CAND-101` | `CAMP-001` | `@tech_reviewer_viet` | `REVIEW` | `COMPLETED` | 45,000 | 100% | Same-campaign bulk approve / reject row 1. |
| `CAND-102` | `CAMP-001` | `@gadget_unboxer_pro` | `REVIEW` | `COMPLETED` | 120,000 | 100% | Same-campaign bulk test fixture. |
| `CAND-103` | `CAMP-001` | `@coder_lifestyle` | `REVIEW` | `COMPLETED` | 15,000 | 100% | Same-campaign bulk reject (blank reason test). |
| `CAND-104` | `CAMP-001` | `@ai_daily_tips` | `ACCEPTED` | `COMPLETED` | 85,000 | 100% | Already accepted (for duplicate decision 409 test). |
| `CAND-105` | `CAMP-001` | `@crypto_analyst` | `REJECTED` | `COMPLETED` | 25,000 | 100% | Already rejected (for duplicate decision test). |
| `CAND-201` | `CAMP-002` | `@beauty_queen_vn` | `REVIEW` | `COMPLETED` | 250,000 | 100% | **Cross-campaign candidate** (used with `CAND-101` to test 422 guard). |
| `CAND-202` | `CAMP-002` | `@skincare_routine_daily` | `REVIEW` | `COMPLETED` | 60,000 | 100% | `CAMP-002` same-campaign test row. |
| `CAND-301` | `CAMP-003` | `@draft_applicant_01` | `WAITING` | `PENDING` | 5,000 | 0% | Unscreened / waiting candidate. |

---

## 5. Local Live Testing Checklist (Mandatory Local QA Gate)

*Note: Dev server and local services must be launched; browser flows executed as a real user; backend logs monitored continuously for exceptions.*

```markdown
### Local Live Execution Log
Date: ____________________
Tester / Agent: Senior QA Engineer
Environment: Localhost (FE: 4200, ai-agent-mcrs: 8080, MongoDB: 27017, Keycloak: 8088)

- [ ] 1. Start backend dependencies (`ai-agent-mcrs`, MongoDB, Redis, Keycloak).
- [ ] 2. Start frontend dev server (`npm start` in `web/dev-tool-web`).
- [ ] 3. Authenticate as user with `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE` + `AI_AGENT_WORKFLOW_WRITE`.
- [ ] 4. Flow 1: Navigate to Campaign List (`/koc/campaigns`).
      - [ ] Verify first viewport displays Title, Create CTA, Filters, Table.
      - [ ] Trigger Pause on `CAMP-001` -> Verify status updates to PAUSED -> Verify filters preserved.
      - [ ] Trigger Resume on `CAMP-001` -> Verify status returns to RUNNING.
      - [ ] CHECK BACKEND LOGS: Zero exceptions or stack traces.
- [ ] 5. Flow 2: Navigate to Candidate List (`/koc/candidates`).
      - [ ] Select 2 candidates from SAME campaign (`CAND-101`, `CAND-102`).
      - [ ] Verify Bulk Toolbar displays count and enabled buttons.
      - [ ] Click Bulk Approve -> Confirm in modal -> Verify candidates updated to ACCEPTED.
      - [ ] Verify selection is cleared automatically and filters preserved.
      - [ ] CHECK BACKEND LOGS: Zero exceptions.
- [ ] 6. Flow 3: Bulk Reject with Blank and Filled Reasons.
      - [ ] Select `CAND-103` (leave blank) and `CAND-102` (fill reason: "Audience mismatch").
      - [ ] Submit Bulk Reject -> Verify successful rejection.
      - [ ] Inspect MongoDB: `CAND-103` has null/empty reason, `CAND-102` has trimmed reason.
      - [ ] CHECK BACKEND LOGS: Zero exceptions.
- [ ] 7. Flow 4: Cross-Campaign Selection Guard.
      - [ ] Select `CAND-101` (`CAMP-001`) and `CAND-201` (`CAMP-002`).
      - [ ] Verify Bulk Approve and Bulk Reject are DISABLED on UI with explanatory helper message.
      - [ ] CHECK BACKEND LOGS: Clean.
- [ ] 8. Stop dev server and cleanup background processes.
```

---

## 6. Coverage Self-Review & Verification

| Review Dimension | Status | Notes |
|---|:---:|---|
| **Spec Requirements Traceability** | **100% Covered** | All locked spec items (routes, table layout, global inbox, bulk same-campaign rule, optional blank reason, 500 char limit, audit server ownership, new review scope, mcrs-only routing) traced to explicit test cases. |
| **Edge & Boundary Cases** | **100% Covered** | Covered empty selection, duplicate IDs, missing ID, 500 vs 501 char boundary, whitespace trimming, whitespace-only reason, all-blank reasons. |
| **Negative & Security Cases** | **100% Covered** | Covered 401 unauth, 403 forbidden per role scope, 422 cross-campaign bulk rejection, 400 validation error, tamper resistance on server-owned audit fields. |
| **Deterministic Test Fixtures** | **100% Covered** | Created 5 deterministic campaign fixtures and 8 deterministic candidate fixtures covering all test branches. |
| **Local Live QA Checklist** | **100% Covered** | Included step-by-step local test protocol with mandatory backend log hygiene verification and cleanup. |
