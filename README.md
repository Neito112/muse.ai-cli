# muse.ai cli

Đưa một máy Windows vào danh sách máy Muse làm việc được qua SSH — để Muse chạy lệnh, đọc/ghi file và dùng toolchain ngay trên máy đó, thay vì trả lời "không làm được" vì máy ảo thiếu môi trường.

Repo này dùng chung cho mọi người. Script không chứa sẵn key hay thông tin của bất kỳ ai — public key là của riêng bạn, bạn tự nhập khi chạy.

## Chuẩn bị: public key của bạn

Script cần public key SSH của máy ảo Muse của **bạn** (mỗi người một key khác nhau, không dùng chung). Lấy key bằng cách:

- Trên máy ảo Muse: `cat ~/.ssh/id_ed25519.pub` rồi copy cả dòng.
- Chưa có key: chạy `ssh-keygen -t ed25519` rồi cat file `.pub` như trên.

Đây là **public** key (chia sẻ được). Không bao giờ dán private key (file không có đuôi `.pub`) vào đâu cả.

## Lệnh 1 — Onboard máy mới

Dán 1 dòng này vào PowerShell (trên máy Windows cần onboard), bấm Enter. Nó tự tải script về rồi mở PowerShell quyền Admin để chạy. Lúc hỏi quyền Admin thì bấm Yes bằng đúng tài khoản Windows của bạn. Script sẽ hỏi public key — dán key của bạn vào.

```powershell
irm 'https://raw.githubusercontent.com/Neito112/muse.ai-cli/main/onboard-may-moi.ps1' -OutFile "$env:TEMP\onboard-may-moi.ps1"; Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-NoExit','-ExecutionPolicy','Bypass','-File',"$env:TEMP\onboard-may-moi.ps1"
```

Script làm 4 việc: cài OpenSSH Server, bật service sshd, thêm public key máy ảo vào `authorized_keys` (cả file user lẫn file admin), sửa quyền file key. Chạy xong nó in 3 dòng cuối — gửi 3 dòng đó cho Muse (tên máy, tên user, IP tailnet) để Muse kiểm tra SSH từ máy ảo.

Muốn khỏi nhập tay mỗi lần: đặt biến môi trường `MUSE_SSH_PUBLIC_KEY` bằng public key của bạn trước khi chạy, hoặc chạy script với tham số `-PublicKey 'ssh-ed25519 AAAA...'`.

## Lệnh 2 — Sửa lỗi đăng nhập SSH bằng key

Dùng khi đã onboard xong mà Muse vẫn báo `Permission denied (publickey)`. Dán 1 dòng này vào PowerShell quyền Admin (đúng tài khoản của bạn), rồi dán public key khi script hỏi:

```powershell
irm 'https://raw.githubusercontent.com/Neito112/muse.ai-cli/main/fix-ssh-acl.ps1' -OutFile "$env:TEMP\fix-ssh-acl.ps1"; Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-NoExit','-ExecutionPolicy','Bypass','-File',"$env:TEMP\fix-ssh-acl.ps1"
```

Script sửa quyền file key, thêm key vào `C:\ProgramData\ssh\administrators_authorized_keys` (sshd đọc file này với tài khoản admin), khởi động lại sshd rồi in quyền file ra. Chạy xong gửi output cho Muse kiểm tra lại.

## Cách hoạt động

- Máy ảo không nhận kết nối vào (tunnel Tailscale chỉ gọi ra), nên mọi kết nối SSH đều đi từ máy ảo ra máy bạn qua Tailscale.
- Mỗi máy chỉ cần 2 thứ giống nhau: OpenSSH Server đang chạy + public key máy ảo trong `authorized_keys`. Máy mới = chạy lại Lệnh 1.
- Muốn thu hồi quyền của Muse: xóa key khỏi `authorized_keys`, tắt service OpenSSH, hoặc tắt máy.

## Files

- `onboard-may-moi.ps1` — onboard máy mới (cài sshd + thêm key + sửa quyền).
- `fix-ssh-acl.ps1` — sửa lỗi đăng nhập key (sửa quyền + file admin + restart sshd).
