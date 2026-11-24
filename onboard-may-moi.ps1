# onboard-may-moi.ps1
# ============================================================
# Đưa một máy Windows vào danh sách máy Muse làm việc được qua SSH.
#
# PHƯƠNG PHÁP (áp dụng cho MỌI máy, không chỉ một máy cụ thể):
#   Thay vì mang mọi môi trường về máy ảo, Muse ĐI TỚI máy nào
#   CÓ môi trường đó và làm việc tại chỗ, qua SSH.
#   Mỗi máy chỉ cần 2 thứ giống nhau:
#     1. OpenSSH Server đang chạy
#     2. Public key của máy ảo Muse nằm trong authorized_keys
#   Xong 2 thứ đó, Muse dùng được toolchain của chính máy đó
#   (Flutter, Android SDK, Blender, Node, ...) — máy ảo không cần
#   có gì hết. Máy mới = chạy lại đúng file này, 2 phút.
#
# PUBLIC KEY (bắt buộc — KHÔNG có sẵn trong script):
#   Script cần public key SSH của máy ảo Muse của BẠN (mỗi người
#   một key khác nhau, không dùng chung). Lấy key bằng cách:
#     - Trên máy ảo Muse:  cat ~/.ssh/id_ed25519.pub
#     - Chưa có key:      ssh-keygen -t ed25519 (rồi cat file .pub)
#   Chạy script với key:  .\onboard-may-moi.ps1 -PublicKey 'ssh-ed25519 AAAA...'
#   Hoặc để script tự hỏi và dán key vào khi nó hỏi.
#   Key này là PUBLIC key (chia sẻ được) — không phải private key.
#   KHÔNG BAO GIỜ dán private key (file không có đuôi .pub) vào đây.
#
# CÁCH DÙNG:
#   - Chạy file này bằng PowerShell với quyền Administrator
#     (chuột phải > "Run with PowerShell" và chọn chạy Admin,
#     hoặc mở PowerShell Admin rồi gọi file).
#   - Máy phải đang chạy Tailscale (để máy ảo tới được qua tailnet).
#   - Chạy xong, gửi cho Muse 3 thứ in ở cuối: tên máy, tên user,
#     IP tailnet. Muse sẽ kiểm tra từ máy ảo (thấy banner SSH và
#     đăng nhập bằng key được) rồi ghi nhận máy này.
#
# Linux (Ubuntu/Debian) — chạy 3 lệnh này thay vì file .ps1
# (thay <PUBLIC_KEY> bằng public key của máy ảo Muse của bạn):
#   sudo apt update && sudo apt install -y openssh-server
#   sudo systemctl enable --now ssh
#   mkdir -p ~/.ssh && echo '<PUBLIC_KEY>' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
#   tailscale ip -4
# ============================================================

#Requires -RunAsAdministrator
param([string]$PublicKey = '')
$ErrorActionPreference = 'Stop'

if (-not $PublicKey) { $PublicKey = $env:MUSE_SSH_PUBLIC_KEY }
if (-not $PublicKey) {
    Write-Host 'Can public key SSH cua may ao Muse cua ban (lay bang: cat ~/.ssh/id_ed25519.pub)'
    $PublicKey = Read-Host 'Public key'
}
if ($PublicKey -notmatch '^ssh-(ed25519|rsa|ecdsa|dss) \S+') {
    Write-Error 'Public key khong dung dinh dang (phai bat dau bang ssh-ed25519 / ssh-rsa ...). Dung lai.'
    exit 1
}
$vmKey = $PublicKey.Trim()

# 1. Cài OpenSSH Server nếu chưa có
$cap = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
if (-not $cap -or $cap.State -ne 'Installed') {
    Write-Host 'Dang cai OpenSSH Server...'
    Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
} else {
    Write-Host 'OpenSSH Server da co.'
}

# 2. Bật service, chạy cùng Windows
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
Write-Host ('sshd: ' + (Get-Service sshd).Status)

# 3. Thêm public key máy ảo vào authorized_keys (không thêm trùng)
$sshDir = "$env:USERPROFILE\.ssh"
$authKeys = "$sshDir\authorized_keys"
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Force $sshDir | Out-Null }
if (-not (Test-Path $authKeys)) { New-Item -ItemType File -Force $authKeys | Out-Null }
$existing = Get-Content $authKeys -ErrorAction SilentlyContinue
if ($existing -notcontains $vmKey) {
    Add-Content -Path $authKeys -Value $vmKey
    Write-Host 'Da them public key.'
} else {
    Write-Host 'Public key da co san.'
}

# 4. Sửa quyền file key (OpenSSH for Windows từ chối key nếu quyền quá mở)
#    Dùng nối chuỗi + nháy đơn: PowerShell 5.1 bẻ gãy "$env:USERNAME:(OI)(CI)F".
#    Kiểm tra $LASTEXITCODE vì stderr của icacls không làm dừng script.
$u = $env:USERNAME
icacls $sshDir /inheritance:r /grant:r ($u + ':(OI)(CI)F') /grant:r 'SYSTEM:(OI)(CI)F'
if ($LASTEXITCODE -ne 0) { Write-Warning 'icacls .ssh THAT BAI.' } else { Write-Host 'Da sua quyen .ssh.' }
icacls $authKeys /inheritance:r /grant:r ($u + ':F') /grant:r 'SYSTEM:F'
if ($LASTEXITCODE -ne 0) { Write-Warning 'icacls authorized_keys THAT BAI.' } else { Write-Host 'Da sua quyen authorized_keys.' }

# 4b. Nếu user là admin, sshd đọc key ở C:\ProgramData\ssh\administrators_authorized_keys
#     (không đọc file trong .ssh của user). Thêm key vào đó luôn cho chắc.
$adminKeys = 'C:\ProgramData\ssh\administrators_authorized_keys'
if (-not (Test-Path 'C:\ProgramData\ssh')) { New-Item -ItemType Directory -Force 'C:\ProgramData\ssh' | Out-Null }
if (-not (Test-Path $adminKeys)) { New-Item -ItemType File -Force $adminKeys | Out-Null }
$existingAdmin = Get-Content $adminKeys -ErrorAction SilentlyContinue
if ($existingAdmin -notcontains $vmKey) {
    Add-Content -Path $adminKeys -Value $vmKey
    Write-Host 'Da them public key vao administrators_authorized_keys.'
} else {
    Write-Host 'Public key da co trong administrators_authorized_keys.'
}
icacls $adminKeys /inheritance:r /grant:r 'SYSTEM:F' /grant:r 'BUILTIN\Administrators:F'
if ($LASTEXITCODE -ne 0) { Write-Warning 'icacls administrators_authorized_keys THAT BAI.' } else { Write-Host 'Da sua quyen administrators_authorized_keys.' }

# 5. Kiểm tra cổng 22 đang nghe
$test = Test-NetConnection -ComputerName localhost -Port 22
if ($test.TcpTestSucceeded) { Write-Host 'Cong 22 dang nghe: OK' } else { Write-Warning 'Cong 22 chua nghe duoc — kiem tra lai service sshd.' }

# 6. In thông tin để gửi Muse
$tailnetIp = ''
try { $tailnetIp = (tailscale ip -4).Trim() } catch { $tailnetIp = '(khong lay duoc — mo app Tailscale xem IP)' }
Write-Host ''
Write-Host '=== GUI CHO MUSE ==='
Write-Host "May: $env:COMPUTERNAME"
Write-Host "User: $env:USERNAME"
Write-Host "IP tailnet: $tailnetIp"
Write-Host '======================'
