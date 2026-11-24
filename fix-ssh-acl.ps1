# fix-ssh-acl.ps1
# ============================================================
# Sửa lỗi đăng nhập SSH bằng key trên máy Windows.
#
# DÙNG KHI NÀO:
#   Đã chạy onboard-may-moi.ps1 xong, sshd đang chạy, cổng 22 nghe,
#   key đã nằm trong authorized_keys, nhưng Muse vẫn báo
#   "Permission denied (publickey)" khi SSH từ máy ảo sang.
#
# NGUYÊN NHÂN THƯỜNG GẶP:
#   1. Lệnh sửa quyền file (icacls) trong bản onboard cũ bị
#      PowerShell 5.1 bẻ gãy cú pháp nên quyền chưa sửa được.
#   2. User là admin: sshd trên Windows đọc key ở
#      C:\ProgramData\ssh\administrators_authorized_keys,
#      không đọc file trong .ssh của user.
#
# PUBLIC KEY (bắt buộc — KHÔNG có sẵn trong script):
#   Cần public key SSH của máy ảo Muse của BẠN (mỗi người một key
#   khác nhau). Lấy bằng: cat ~/.ssh/id_ed25519.pub trên máy ảo.
#   Chạy: .\fix-ssh-acl.ps1 -PublicKey 'ssh-ed25519 AAAA...'
#   Hoặc để script tự hỏi và dán key vào khi nó hỏi.
#   Đây là PUBLIC key — KHÔNG BAO GIỜ dán private key vào đây.
#
# CÁCH DÙNG:
#   Chạy file này bằng PowerShell với quyền Administrator
#   (đúng tài khoản Windows của bạn). Chạy xong gửi output
#   cho Muse để kiểm tra lại từ máy ảo.
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
$u = $env:USERNAME

# 1. Sửa quyền .ssh và authorized_keys của user
#    (dùng nối chuỗi + nháy đơn: PowerShell 5.1 bẻ gãy "$env:USERNAME:(OI)(CI)F")
icacls "$env:USERPROFILE\.ssh" /inheritance:r /grant:r ($u + ':(OI)(CI)F') /grant:r 'SYSTEM:(OI)(CI)F'
if ($LASTEXITCODE -ne 0) { Write-Warning 'icacls .ssh THAT BAI.' } else { Write-Host 'Da sua quyen .ssh.' }
icacls "$env:USERPROFILE\.ssh\authorized_keys" /inheritance:r /grant:r ($u + ':F') /grant:r 'SYSTEM:F'
if ($LASTEXITCODE -ne 0) { Write-Warning 'icacls authorized_keys THAT BAI.' } else { Write-Host 'Da sua quyen authorized_keys.' }

# 2. Thêm key vào administrators_authorized_keys (cho tài khoản admin)
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

# 3. Khởi động lại sshd và in quyền file ra để kiểm tra
Restart-Service sshd
Write-Host '--- quyen file authorized_keys ---'
icacls "$env:USERPROFILE\.ssh\authorized_keys"
Write-Host '--- quyen file administrators_authorized_keys ---'
icacls $adminKeys
Write-Host 'XONG - gui output nay cho Muse de kiem tra lai.'
