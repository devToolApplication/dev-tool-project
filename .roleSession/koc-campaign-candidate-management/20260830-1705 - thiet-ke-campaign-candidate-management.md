# Thiết kế Campaign Management và Global Candidate List

## Input

User yêu cầu lên plan thiết kế màn hình quản lý campaign và danh sách candidate ở `dev-tool-web` và `ai-agent-mcrs`, theo `/brainstorming`.

Các quyết định đã chốt:

- Campaign Management và Candidate List tách riêng route.
- Candidate List là global inbox toàn hệ thống, có filter `campaignId`.
- Campaign Management MVP gồm list/filter/open detail/create/edit/start/pause/resume/clone/stop.
- Layout table-first cho cả hai màn hình.
- Candidate List có bulk approve/reject.
- Bulk reject có reason optional theo từng candidate.
- Bulk action chỉ cho cùng một campaign.
- Tạo scope Keycloak mới: `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`.

## Output

Đã viết spec tại:

- `docs/superpowers/specs/2026-08-30-koc-campaign-candidate-management-design.md`

Nội dung spec gồm:

- UI scope cho Campaign Management.
- UI scope cho Global Candidate List.
- Bulk approve/reject behavior.
- API contract `dev-tool-web` ↔ `ai-agent-mcrs`.
- Data contract CampaignSummary/CandidateSummary.
- Permission model gồm scope mới `AI_AGENT_KOC_CANDIDATE_REVIEW_WRITE`.
- Error behavior.
- FE/BE test expectations.

## Next Role

Architect/Dev BE/Dev FE.

Action tiếp theo sau khi user review và approve spec:

1. Invoke `writing-plans` để tạo implementation plan.
2. Plan cần chia tối thiểu các phần:
   - Keycloak scope + BE permission guard.
   - `ai-agent-mcrs` API bulk approve/reject.
   - `dev-tool-web` API service/model updates.
   - Campaign list action/permission cleanup.
   - Candidate list selection + bulk toolbar + modals.
   - Tests targeted.
