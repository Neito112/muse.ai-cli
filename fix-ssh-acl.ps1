# fix-ssh-acl.ps1
# ============================================================
# Sửa lỗi đăng nhập SSH bằng key trên máy Windows.
#
# DÙNG KHI NÀO:
#   Đã chạy onboard-may-moi.ps1 xong, sshd đang chạy, cổng 22 nghe,
#   key đã nằm trong authorized_keys, nhưng Ni-Oh vẫn báo
#   "Permission denied (publickey)" khi SSH từ máy ảo sang.
#
# NGUYÊN NHÂN THƯỜNG GẶP:
#   1. Lệnh sửa quyền file (icacls) trong bản onboard cũ bị
#      PowerShell 5.1 bẻ gãy cú pháp nên quyền chưa sửa được.
#   2. User là admin: sshd trên Windows đọc key ở
#      C:\ProgramData\ssh\administrators_authorized_keys,
#      không đọc file trong .ssh của user.
#
# CÁCH DÙNG:
#   Chạy file này bằng PowerShell với quyền Administrator
#   (đúng tài khoản Windows của bạn). Chạy xong gửi output
#   cho Ni-Oh để kiểm tra lại từ máy ảo.
# ============================================================

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$vmKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJktvvGGS8a2VzvWCj9lYnjUsTWs+Rul8mRwOVNXvWa6 hatch'
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
    Write-Host 'Da them key may ao vao administrators_authorized_keys.'
} else {
    Write-Host 'Key may ao da co trong administrators_authorized_keys.'
}
icacls $adminKeys /inheritance:r /grant:r 'SYSTEM:F' /grant:r 'BUILTIN\Administrators:F'
if ($LASTEXITCODE -ne 0) { Write-Warning 'icacls administrators_authorized_keys THAT BAI.' } else { Write-Host 'Da sua quyen administrators_authorized_keys.' }

# 3. Khởi động lại sshd và in quyền file ra để kiểm tra
Restart-Service sshd
Write-Host '--- quyen file authorized_keys ---'
icacls "$env:USERPROFILE\.ssh\authorized_keys"
Write-Host '--- quyen file administrators_authorized_keys ---'
icacls $adminKeys
Write-Host 'XONG - gui output nay cho Ni-Oh de kiem tra lai.'
