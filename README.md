# ni-oh-onboard

Đưa một máy Windows vào danh sách máy Ni-Oh làm việc được qua SSH — để Ni-Oh chạy lệnh, đọc/ghi file và dùng toolchain ngay trên máy đó, thay vì trả lời "không làm được" vì máy ảo thiếu môi trường.

## Lệnh 1 — Onboard máy mới

Dán 1 dòng này vào PowerShell (trên máy Windows cần onboard), bấm Enter. Nó tự tải script về rồi mở PowerShell quyền Admin để chạy. Lúc hỏi quyền Admin thì bấm Yes bằng đúng tài khoản Windows của bạn.

```powershell
irm 'https://raw.githubusercontent.com/Neito112/ni-oh-onboard/main/onboard-may-moi.ps1' -OutFile "$env:TEMP\onboard-may-moi.ps1"; Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-NoExit','-ExecutionPolicy','Bypass','-File',"$env:TEMP\onboard-may-moi.ps1"
```

Script làm 4 việc: cài OpenSSH Server, bật service sshd, thêm public key máy ảo vào `authorized_keys` (cả file user lẫn file admin), sửa quyền file key. Chạy xong nó in 3 dòng cuối — gửi 3 dòng đó cho Ni-Oh (tên máy, tên user, IP tailnet) để Ni-Oh kiểm tra SSH từ máy ảo.

## Lệnh 2 — Sửa lỗi đăng nhập SSH bằng key

Dùng khi đã onboard xong mà Ni-Oh vẫn báo `Permission denied (publickey)`. Dán 1 dòng này vào PowerShell quyền Admin (đúng tài khoản của bạn):

```powershell
irm 'https://raw.githubusercontent.com/Neito112/ni-oh-onboard/main/fix-ssh-acl.ps1' -OutFile "$env:TEMP\fix-ssh-acl.ps1"; Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-NoExit','-ExecutionPolicy','Bypass','-File',"$env:TEMP\fix-ssh-acl.ps1"
```

Script sửa quyền file key, thêm key vào `C:\ProgramData\ssh\administrators_authorized_keys` (sshd đọc file này với tài khoản admin), khởi động lại sshd rồi in quyền file ra. Chạy xong gửi output cho Ni-Oh kiểm tra lại.

## Cách hoạt động

- Máy ảo không nhận kết nối vào (tunnel Tailscale chỉ gọi ra), nên mọi kết nối SSH đều đi từ máy ảo ra máy bạn qua Tailscale.
- Mỗi máy chỉ cần 2 thứ giống nhau: OpenSSH Server đang chạy + public key máy ảo trong `authorized_keys`. Máy mới = chạy lại Lệnh 1.
- Muốn thu hồi quyền của Ni-Oh: xóa key khỏi `authorized_keys`, tắt service OpenSSH, hoặc tắt máy.

## Files

- `onboard-may-moi.ps1` — onboard máy mới (cài sshd + thêm key + sửa quyền).
- `fix-ssh-acl.ps1` — sửa lỗi đăng nhập key (sửa quyền + file admin + restart sshd).
