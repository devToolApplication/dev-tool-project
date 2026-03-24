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
