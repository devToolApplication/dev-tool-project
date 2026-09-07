# gstack + GSD + Superpowers Workflow

> Triết lý: *"gstack thinks, GSD stabilizes, Superpowers executes."*

---

## Mô hình 3 tầng

| Tầng | Công cụ | Vai trò |
|---|---|---|
| Quyết định | **gstack** | Đội cố vấn đa chiều — xác định *nên làm gì* trước khi code |
| Ngữ cảnh | **GSD** | Neo giữ mục tiêu, ranh giới, trạng thái dự án — chống *context rot* |
| Thực thi | **Superpowers** | Chu trình TDD khép kín — quy định *cách xây dựng* phần mềm |

---

## Bước 1 — Quyết định (gstack)

### 1a. Thách thức ý tưởng ban đầu
**Skill:** `office-hours`
```
/office-hours

[Mô tả ý tưởng/feature muốn làm, vấn đề đang gặp, mục tiêu kỳ vọng]
```

### 1b. Kiểm tra tính hợp lý sản phẩm
**Skill:** `plan-ceo-review`
```
/plan-ceo-review

[Dán plan hoặc mô tả feature vừa xác định ở bước office-hours]
```

### 1c. Chốt kiến trúc kỹ thuật
**Skill:** `plan-eng-review`
```
/plan-eng-review

[Dán plan đã qua CEO review — kiến trúc, luồng dữ liệu, tech stack]
```

### 1d. Review thiết kế UI (nếu có giao diện)
**Skill:** `plan-design-review`
```
/plan-design-review

[Dán plan + mô tả UI/UX cần thiết kế]
```

---

## Bước 2 — Cố định ngữ cảnh (GSD / context-save)

### 2a. Lưu context sau khi quyết định xong
**Skill:** `context-save`
```
/context-save

Lưu lại toàn bộ context:
- Feature: [tên]
- Quyết định kiến trúc: [từ eng-review]
- Quyết định sản phẩm: [từ ceo-review]
- Out of scope: [những gì KHÔNG làm]
- Next action: [bước thực thi tiếp theo]
```

### 2b. Khôi phục context ở phiên sau
**Skill:** `context-restore`
```
/context-restore
```

> **GSD files chuẩn:** `PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `M001-ROADMAP.md`

---

## Bước 3 — Thực thi (Superpowers)

### 3a. Viết plan
**Skill:** `writing-plans`
```
/writing-plans

[Dán spec/requirements từ bước 1-2]
```

### 3b. Thực thi plan
**Skill:** `executing-plans`
```
/executing-plans

[Plan đã viết ở bước 3a]
```

### 3c. TDD — viết test trước, code sau
**Skill:** `test-driven-development`
```
/test-driven-development

[Mô tả behavior cần implement, acceptance criteria]
```

### 3d. Yêu cầu code review
**Skill:** `requesting-code-review`
```
/requesting-code-review
```

### 3e. Nhận và xử lý review
**Skill:** `receiving-code-review`
```
/receiving-code-review
```

### 3f. Xác nhận hoàn thành trước khi đóng
**Skill:** `verification-before-completion`
```
/verification-before-completion
```

### 3g. Hoàn tất branch
**Skill:** `finishing-a-development-branch`
```
/finishing-a-development-branch
```

### 3h. Song song hóa (nếu task lớn)
**Skill:** `dispatching-parallel-agents` hoặc `subagent-driven-development`
```
/dispatching-parallel-agents

[Mô tả các subtask độc lập cần chạy song song]
```

---

## Flow đầy đủ

```
/office-hours                  ← thách thức ý tưởng
/plan-ceo-review               ← kiểm tra product sense
/plan-eng-review               ← chốt kỹ thuật
/plan-design-review            ← (nếu có UI)
/context-save                  ← đóng băng ngữ cảnh
---
/writing-plans                 ← viết plan thực thi
/executing-plans               ← implement
/test-driven-development       ← TDD Red-Green-Refactor
/requesting-code-review        ← yêu cầu review
/receiving-code-review         ← xử lý feedback
/verification-before-completion ← xác nhận done
/finishing-a-development-branch ← đóng branch
```

---

## Heuristics chọn công cụ

| Tình huống | Dùng |
|---|---|
| Yêu cầu còn mơ hồ | Bắt đầu bằng `office-hours` |
| Dự án dài, nhiều phiên | `context-save` / GSD để chống drift |
| Cần hoàn thành feature chuẩn | Superpowers làm backbone |
| Task lớn, chia song song | `dispatching-parallel-agents` |

---

## Điểm yếu cần biết

- **gstack**: tốn token cao (>10k/task), dễ loãng nếu bật hết roles
- **Superpowers**: thủ tục nặng, không phù hợp fix nhỏ
- **GSD**: không tự code/test/tạo PR nếu dùng độc lập
- **Không cài cả 3 cùng lúc** mù quáng — chọn lọc skill cụ thể để tránh xung đột auto-trigger

---

*Nguồn: https://dev.to/imaginex/a-claude-code-skills-stack-how-to-combine-superpowers-gstack-and-gsd-without-the-chaos-44b3*
