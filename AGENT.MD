# Codex Environment Bootstrap Notes

## Mục tiêu
Đảm bảo môi trường Codex sẵn sàng để phát triển và chạy dự án, có đủ công cụ và quyền truy cập cần thiết.

## 1) Chuẩn bị công cụ bắt buộc
Kiểm tra nhanh các công cụ trước khi làm việc:

```bash
git --version
node --version
npm --version
mvn -version
java -version
```

Yêu cầu tối thiểu:
- Git đã cài đặt.
- Node.js + npm đã cài đặt.
- Maven đã cài đặt.
- Java runtime/JDK tương thích với Maven project.

## 2) Credentials: dùng biến môi trường đã inject trong Codex
**Nguồn credential mặc định là ENV đã được inject sẵn vào môi trường Codex.**
Không nhập tay hoặc hardcode credentials vào repo.

### GitHub
- Lấy từ biến môi trường đã inject (ví dụ):
  - `GITHUB_USERNAME`
  - `GITHUB_PASSWORD` hoặc `GITHUB_TOKEN`
- Dùng các giá trị ENV này để authenticate khi cần thao tác GitHub/`gh`.

Ví dụ (ưu tiên token nếu có):

```bash
# Kiểm tra biến đã có
printenv GITHUB_USERNAME
printenv GITHUB_TOKEN

# Đăng nhập gh bằng token từ ENV
echo "$GITHUB_TOKEN" | gh auth login --with-token
gh auth status
```

> Lưu ý bảo mật: Không commit username/password/token vào file mã nguồn.

## 3) Đồng bộ code mới nhất cho toàn bộ submodule
Project có nhiều git submodule. Sau khi clone hoặc khi bootstrap môi trường, luôn chạy:

```bash
git submodule sync --recursive
git submodule update --init --recursive
git submodule foreach --recursive 'git fetch --all --prune && git pull --ff-only || true'
```

Nếu cần đảm bảo submodule tracking branch mới nhất từ remote:

```bash
git submodule update --remote --recursive
```

## 4) Keycloak credentials cho FE login
- Lấy từ ENV đã inject trong Codex (ví dụ):
  - `KEYCLOAK_USERNAME`
  - `KEYCLOAK_PASSWORD`
- Sử dụng trực tiếp các biến này để đăng nhập FE/test flow.

Ví dụ:

```bash
printenv KEYCLOAK_USERNAME
printenv KEYCLOAK_PASSWORD
```

## 5) Checklist bootstrap nhanh
- [ ] Đã xác nhận GitHub username/password (hoặc token) có trong ENV của Codex.
- [ ] Đã xác nhận Keycloak username/password có trong ENV của Codex.
- [ ] Đã login GitHub thành công bằng ENV credentials.
- [ ] Đã init/update toàn bộ submodule.
- [ ] Đã xác thực npm, maven, java hoạt động.

## 6) Lưu ý để sinh AGENTS.md (cho repo có git submodule)
Repository có sử dụng git submodules (có thể nested).
Agent **không được** coi repo là đầy đủ nếu chỉ có repo chính.

### ⚠️ Bắt buộc về submodule
Luôn yêu cầu agent:

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

Phải kiểm tra lại bằng:

```bash
git submodule status --recursive
```

Nếu submodule chưa được init → phải dừng và xử lý trước khi làm gì khác.

### 🎯 Định nghĩa “task hoàn thành”
Task chỉ được coi là thành công khi:

- tất cả submodule (kể cả nested) đã được clone đầy đủ
- code trong submodule có thể truy cập và đọc được
- project build / run / test thành công với submodule
- không bỏ qua logic nằm trong submodule

### ❌ Những hành vi không được phép
Không được:

- bỏ qua submodule
- giả định submodule là optional
- mock/stub thay cho submodule nếu chưa được yêu cầu
- chỉ sửa repo chính trong khi bug nằm ở submodule

### 🛠 Khi submodule lỗi
Agent phải:

1. check `.gitmodules`
2. check URL submodule
3. sync lại:
   ```bash
   git submodule sync --recursive
   ```
4. update lại:
   ```bash
   git submodule update --init --recursive
   ```
5. Nếu lỗi auth → dùng credential có sẵn trong environment
6. Không được in token/secret ra log

### 🧠 Nguyên tắc xử lý code
Submodule là một phần của hệ thống, không phải dependency phụ.
Nếu feature/bug liên quan → phải đọc và có thể sửa submodule.
Không được workaround bằng cách né submodule.

### ✅ Checklist trước khi kết thúc
- [ ] Repo chính OK
- [ ] Tất cả submodule đã init
- [ ] Recursive submodule OK
- [ ] Code submodule đã được xét tới nếu liên quan
- [ ] Project build/test/run thành công

### 🔥 1 câu chốt để AI hiểu đúng

> If submodules are not initialized and available, the task is incomplete even if the main repository is present.
