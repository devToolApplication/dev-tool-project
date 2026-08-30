# KOC Campaign and Candidate Management Design

## Context

`dev-tool-web` needs two operational screens backed by `ai-agent-mcrs`:

1. Campaign Management list for campaign lifecycle work.
2. Global Candidate List for reviewing and deciding candidates.

The primary rule is separation of concerns:

- business UI stays in the list/detail experience;
- workflow technical details stay out of the primary viewport;
- `dev-tool-web` talks only to `ai-agent-mcrs`, never to execute service directly.

## Scope

### In scope

- Campaign Management list.
- Global Candidate List.
- Campaign create/edit/start/pause/resume/clone/stop entry points.
- Candidate row open/detail entry point.
- Bulk approve and bulk reject for candidates.
- Permission model for read vs write actions.
- Loading, empty, error, success states.
- Responsive and accessibility behavior.

### Out of scope

- Workflow engine internals in the main business UI.
- Agent/provider/node/gateway/retry/timeout fields in the primary list screens.
- Legacy redirects or compatibility shims for old KOC review screens.
- Realtime redesign.

## Locked UX decisions

- Campaign Management and Candidate List remain separate routes.
- Both screens use a table-first layout.
- Campaign List is the entry point for campaign lifecycle operations.
- Candidate List is global by default and can be filtered by campaign.
- Bulk actions are allowed only when the selection belongs to one campaign.
- Bulk reject reasons are optional per candidate.
- Technical workflow configuration is hidden from the primary list screens.

## Screen 1: Campaign Management

### Purpose

Let operators find campaigns quickly and perform lifecycle actions without opening technical workflow screens.

### Primary user goal

Scan campaign status, open campaign detail, and trigger lifecycle actions with minimal friction.

### First viewport

- page title and short subtitle;
- `Create campaign` primary CTA;
- status filter and search;
- campaign table.

Everything else is secondary.

### Table content

Recommended columns:

- Name / code.
- Status.
- Accepted target and progress.
- Funnel counters.
- Last activity.
- Actions.

### Row actions

- Open detail.
- Edit campaign.
- Start.
- Pause.
- Resume.
- Clone.
- Stop.

Lifecycle actions are destructive or stateful, so they stay in a row action menu, not as primary buttons.

### States

- Loading: skeleton rows.
- Empty: no campaigns yet.
- Filter empty: no matching campaigns for current filters.
- Error: inline error state with BE message.
- Success after mutation: reload current page, preserve filters.

### Responsive behavior

- Desktop: full table.
- Tablet/mobile: preserve the same table contract, but collapse secondary columns into row subtext and keep horizontal overflow if needed.
- Primary CTA remains visible above the list.

## Screen 2: Global Candidate List

### Purpose

Give reviewers one global inbox for candidates across campaigns, with fast filtering and bulk decisions.

### Primary user goal

Find candidates, inspect their campaign context, and approve or reject quickly.

### First viewport

- page title and short subtitle;
- search;
- campaign filter;
- decision filter;
- execution status filter;
- candidate table;
- bulk toolbar only when rows are selected.

Advanced filters stay collapsed behind a secondary filter panel.

### Table content

Recommended columns:

- Candidate identity.
- Campaign identity.
- Decision.
- Execution status.
- Followers.
- Screening progress.
- Updated at.
- Reason summary.

### Row actions

- Open candidate detail.

### Bulk actions

#### Bulk approve

- Enabled only when all selected rows belong to the same campaign.
- Confirmation dialog shows the selection count and campaign identity.
- No reason field.

#### Bulk reject

- Enabled only when all selected rows belong to the same campaign.
- Confirmation dialog shows the selection count and campaign identity.
- One reason field per selected candidate.
- Reason is optional.
- If provided, trim the value and validate max 500 chars.
- Blank reason is allowed and omitted from the request.

#### Bulk guard

If selection spans more than one campaign:

- disable the bulk actions;
- show helper text that the selection must be narrowed to one campaign.

No cross-campaign bulk confirmation is allowed.

### States

- Loading: skeleton table rows.
- Empty: no candidates yet.
- Filter empty: no matching candidates for current filters.
- Error: inline error state with BE message.
- Bulk submit: modal-level loading only, not full-page blocking.
- Success after mutation: clear selection, reload current page, keep URL filters.

### Responsive behavior

- Desktop: full table.
- Mobile: compact rows with stacked metadata and a sticky bulk toolbar when selected rows exist.
- Selection checkboxes must stay reachable on small screens.

## API contract

All paths below are relative to the `ai-agent-mcrs` admin API base.

### Campaign list and lifecycle

#### GET `/koc/campaigns/page`

Purpose: load the Campaign Management list.

Auth: `AI_AGENT_READ`

Request:

- `page`
- `size`
- `sort`
- `search`
- `status`

Response:

- paged `CampaignSummary` list.

Errors:

- `400 INVALID_FILTER`
- `401 UNAUTHENTICATED`
- `403 PERMISSION_DENIED`
- `500 SERVER_ERROR`

#### POST `/koc/campaigns`

Purpose: create a campaign.

Auth: `AI_AGENT_WORKFLOW_WRITE`

Request: campaign create payload.

Response: campaign detail.

Errors:

- `400 VALIDATION_ERROR`
- `403 PERMISSION_DENIED`
- `409 DUPLICATE_CODE`
- `422 INVALID_CAMPAIGN_CONFIG`

#### PUT `/koc/campaigns/{campaignId}`

Purpose: edit a campaign.

Auth: `AI_AGENT_WORKFLOW_WRITE`

Request: campaign edit payload.

Response: campaign detail.

Errors:

- `400 VALIDATION_ERROR`
- `403 PERMISSION_DENIED`
- `404 NOT_FOUND`
- `409 INVALID_STATE`

#### POST `/koc/campaigns/{campaignId}/start`
#### POST `/koc/campaigns/{campaignId}/pause`
#### POST `/koc/campaigns/{campaignId}/resume`
#### POST `/koc/campaigns/{campaignId}/clone`
#### POST `/koc/campaigns/{campaignId}/stop`

Purpose: lifecycle actions from the list or detail screen.

Auth: `AI_AGENT_WORKFLOW_WRITE`

Request: no body.

Response: updated campaign detail.

Errors:

- `403 PERMISSION_DENIED`
- `404 NOT_FOUND`
- `409 INVALID_STATE`
- `422 INVALID_LIFECYCLE_TRANSITION`

### Candidate list and review actions

#### GET `/koc/candidates/page`

Purpose: load the global candidate list.

Auth: `AI_AGENT_READ`

Request:

- `page`
- `size`
- `sort`
- `campaignId`
- `search`
- `decision`
- `executionStatus`
- `rejectReason`
- `minFollowers`
- `maxFollowers`

Response:

- paged `CandidateSummary` list.

Errors:

- `400 INVALID_FILTER`
- `403 PERMISSION_DENIED`
- `500 SERVER_ERROR`

#### GET `/koc/candidates/{candidateId}`

Purpose: open candidate detail.

Auth: `AI_AGENT_READ`

Response: candidate detail.

Errors:

- `403 PERMISSION_DENIED`
- `404 NOT_FOUND`

#### POST `/koc/candidates/{candidateId}/reviews`

Purpose: keep existing single-candidate review action.

Auth: `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`

Request: single review payload.

Response: review result.

Errors:

- `400 VALIDATION_ERROR`
- `403 PERMISSION_DENIED`
- `404 NOT_FOUND`
- `409 DUPLICATE_DECISION`
- `422 INVALID_REVIEW_STATE`

#### POST `/koc/candidates/reviews/bulk-approve`

Purpose: approve a same-campaign selection in one request.

Auth: `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`

Request:

```json
{
  "candidateIds": ["candidate-1", "candidate-2"]
}
```

Response: bulk action result with accepted candidates.

Errors:

- `400 VALIDATION_ERROR`
- `403 PERMISSION_DENIED`
- `404 NOT_FOUND`
- `409 DUPLICATE_DECISION`
- `422 CROSS_CAMPAIGN_BULK_NOT_ALLOWED`

#### POST `/koc/candidates/reviews/bulk-reject`

Purpose: reject a same-campaign selection with optional per-candidate reasons.

Auth: `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`

Request:

```json
{
  "candidateIds": ["candidate-1", "candidate-2"],
  "reasons": [
    { "candidateId": "candidate-1", "reason": "Low evidence" }
  ]
}
```

Rules:

- `candidateIds` is required and must not be empty.
- `reasons` is optional.
- Each reason entry is optional in the UI.
- Blank reason values are omitted.
- If a reason is present, trim it and enforce max 500 chars.

Response: bulk action result with rejected candidates.

Errors:

- `400 VALIDATION_ERROR`
- `403 PERMISSION_DENIED`
- `404 NOT_FOUND`
- `409 DUPLICATE_DECISION`
- `422 CROSS_CAMPAIGN_BULK_NOT_ALLOWED`

## Data contract

### CampaignSummary

| Field | Meaning | Required | Notes |
|---|---|---:|---|
| campaignId | Stable campaign identifier | Yes | Canonical route/filter key |
| name | Human-readable campaign name | Yes | Display in list |
| code | Short campaign code | Yes | Helpful for scanning |
| status | Campaign lifecycle status | Yes | `DRAFT`, `READY`, `RUNNING`, `PAUSED`, `COMPLETED`, `STOPPED`, `BLOCKED` |
| acceptedTarget | Target accepted count | Yes | Used for progress |
| counters | Funnel counters | Yes | `discovered`, `unique`, `screened`, `rejected`, `review`, `accepted`, `waiting` |
| lastActivityAt | Last meaningful update time | No | Sort and recency signal |

### CandidateSummary

| Field | Meaning | Required | Notes |
|---|---|---:|---|
| candidateId | Stable candidate identifier | Yes | Canonical route key |
| campaignId | Owning campaign | Yes | Bulk guard and filtering key |
| campaignName | Human-readable campaign name | No | Optional display aid for global list |
| displayName | Candidate identity | Yes | Main list label |
| decision | Human decision state | Yes | `ACCEPTED`, `REJECTED`, `REVIEW`, `SCREENING`, `WAITING` |
| executionStatus | Runtime status | Yes | Workflow/runtime status |
| followers | Audience size | No | Optional score field |
| screeningProgress | Screening percent | No | 0-100 when present |
| reason | Decision or screening reason summary | No | Optional list summary only |
| updatedAt | Last update time | No | Sort and recency signal |

### Audit and ownership rules

- `reviewedBy` and `reviewedAt` are server-owned.
- FE does not send `reviewedBy`, `reviewedAt`, `actedBy`, or `actedAt`.
- `lastActivityAt` is derived from the newest meaningful campaign change.
- List screens do not expose workflow engine internals.

## Permission model

| Action | Permission |
|---|---|
| View campaign list | `AI_AGENT_READ` |
| View candidate list | `AI_AGENT_READ` |
| Open campaign detail | `AI_AGENT_READ` |
| Open candidate detail | `AI_AGENT_READ` |
| Create/edit/start/pause/resume/clone/stop campaign | `AI_AGENT_WORKFLOW_WRITE` |
| Single candidate review | `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE` |
| Bulk approve/reject candidates | `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE` |

## Error behavior

FE should show the backend message directly when available.

Standardized error codes:

- `400 VALIDATION_ERROR`
- `403 PERMISSION_DENIED`
- `404 NOT_FOUND`
- `409 INVALID_STATE` or `409 DUPLICATE_DECISION`
- `422 CROSS_CAMPAIGN_BULK_NOT_ALLOWED`
- `500 SERVER_ERROR`

List screens keep the current URL filters on error and let the user retry from the same state.

## Compatibility

- Campaign list and candidate list changes are additive.
- Existing list routes stay separate.
- Existing detail routes stay available.
- New bulk endpoints are added without replacing single-candidate review.
- Optional `campaignName` on candidate summary is additive only.
- The new Keycloak scope is additive and isolates candidate review writes from campaign lifecycle writes.

## Testing

### FE

- Campaign list loads from URL filters.
- Campaign lifecycle actions call the correct API and reload the current page.
- Candidate list loads from URL filters.
- Selection enables bulk toolbar.
- Cross-campaign selection disables bulk actions.
- Bulk reject modal allows blank reason and validates only filled values.
- Success clears selection and preserves filters.
- Error state surfaces BE message.

### BE contract

- Campaign list pagination and filters are stable.
- Candidate list pagination and filters are stable.
- Bulk approve rejects mixed-campaign selection.
- Bulk reject accepts blank reasons.
- Single and bulk review actions require the new review-write scope.

## Decision summary

- Separate campaign and candidate routes.
- Table-first on both screens.
- Global candidate list with campaign filter.
- Same-campaign-only bulk actions.
- Bulk reject reason optional.
- New review-write scope for candidate decision actions.

## Next step

Use this spec as the input for the implementation plan.
