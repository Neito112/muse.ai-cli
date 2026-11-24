# onboard-may-moi.ps1
# ============================================================
# Đưa một máy Windows vào danh sách máy Ni-Oh làm việc được.
#
# PHƯƠNG PHÁP (áp dụng cho MỌI máy, không chỉ một máy cụ thể):
#   Vấn đề trước giờ: máy ảo không có môi trường (Flutter, Android
#   SDK, Blender, ...) nên Ni-Oh hay phải trả lời "không làm được".
#   Cách sửa không phải là mang mọi môi trường về máy ảo, mà là
#   Ni-Oh ĐI TỚI máy nào CÓ môi trường đó và làm việc tại chỗ,
#   qua SSH. Mỗi máy chỉ cần 2 thứ giống nhau:
#     1. OpenSSH Server đang chạy
#     2. Public key của máy ảo nằm trong authorized_keys của user
#   Xong 2 thứ đó, Ni-Oh dùng được toolchain của chính máy đó.
#   Máy mới = chạy lại đúng file này, 2 phút. Không cần sửa gì
#   thêm ở phía Ni-Oh ngoài việc ghi nhận máy mới.
#
# CÁCH DÙNG:
#   - Chạy file này bằng PowerShell với quyền Administrator
#     (chuột phải > "Run with PowerShell" và chọn chạy Admin,
#     hoặc mở PowerShell Admin rồi gọi file).
#   - Máy phải đang chạy Tailscale (để Ni-Oh tới được qua tailnet).
#   - Chạy xong, nhắn Ni-Oh 3 thứ in ở cuối: tên máy, tên user,
#     IP tailnet. Ni-Oh sẽ kiểm tra từ máy ảo (thấy banner SSH và
#     đăng nhập bằng key được) rồi ghi nhận máy này.
#   - Sau đó, việc gì cần môi trường của máy này thì cứ giao cho
#     Ni-Oh, Ni-Oh tự SSH sang đó làm.
#
# Linux (Ubuntu/Debian) — chạy 3 lệnh này thay vì file .ps1:
#   sudo apt update && sudo apt install -y openssh-server
#   sudo systemctl enable --now ssh
#   mkdir -p ~/.ssh && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJktvvGGS8a2VzvWCj9lYnjUsTWs+Rul8mRwOVNXvWa6 hatch' >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
#   tailscale ip -4
#
# LƯU Ý: file này do Ni-Oh soạn trên máy ảo Linux, CHƯA thử trên
# Windows. Lỗi thì chụp log gửi Ni-Oh sửa.
# ============================================================

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$vmKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJktvvGGS8a2VzvWCj9lYnjUsTWs+Rul8mRwOVNXvWa6 hatch'

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
    Write-Host 'Da them key may ao.'
} else {
    Write-Host 'Key may ao da co san.'
}

# 4. Sửa quyền file key (OpenSSH for Windows từ chối key nếu quyền quá mở)
#    Dùng nối chuỗi + nháy đơn: PowerShell 5.1 bẻ gãy "$env:USERNAME:(OI)(CI)F"
#    (lỗi 'Invalid parameter' — đã gặp trên NEITO-HOME 24/11).
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
    Write-Host 'Da them key may ao vao administrators_authorized_keys.'
} else {
    Write-Host 'Key may ao da co trong administrators_authorized_keys.'
}
icacls $adminKeys /inheritance:r /grant:r 'SYSTEM:F' /grant:r 'BUILTIN\Administrators:F'
if ($LASTEXITCODE -ne 0) { Write-Warning 'icacls administrators_authorized_keys THAT BAI.' } else { Write-Host 'Da sua quyen administrators_authorized_keys.' }

# 5. Kiểm tra cổng 22 đang nghe
$test = Test-NetConnection -ComputerName localhost -Port 22
if ($test.TcpTestSucceeded) { Write-Host 'Cong 22 dang nghe: OK' } else { Write-Warning 'Cong 22 chua nghe duoc — kiem tra lai service sshd.' }

# 6. In thông tin để gửi Ni-Oh
$tailnetIp = ''
try { $tailnetIp = (tailscale ip -4).Trim() } catch { $tailnetIp = '(khong lay duoc — mo app Tailscale xem IP)' }
Write-Host ''
Write-Host '=== GUI CHO NI-OH ==='
Write-Host "May: $env:COMPUTERNAME"
Write-Host "User: $env:USERNAME"
Write-Host "IP tailnet: $tailnetIp"
Write-Host '======================'
