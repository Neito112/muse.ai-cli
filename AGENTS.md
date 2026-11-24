# AGENTS.md — muse.ai cli

This repo onboards a Windows PC so a Muse agent (running on a Linux VM) can work on that PC over SSH. Read this file when a user hands you this repo and asks you to set up remote access to their PC.

## The idea (read this first)

The agent's VM usually lacks the toolchains the user has on their PC (Flutter, Android SDK, Blender, Node, ...). Instead of installing everything on the VM, the agent works ON the PC that has the environment, over SSH. Every PC gets the same two things:

1. OpenSSH Server running
2. The VM's SSH public key in the PC's `authorized_keys`

Once those two are in place, the agent runs commands on the PC via SSH and uses the PC's own toolchain. A new PC = run the same one-liner again.

## What you (the agent) need before starting

- The VM's SSH **public** key. Get it with:
  `cat ~/.ssh/id_ed25519.pub`
  If there is no key yet, create one first:
  `ssh-keygen -t ed25519` (accept defaults, no passphrase), then cat the `.pub` file.
- The user must be at their Windows PC (or able to run a command there). They run the one-liner below in PowerShell as Administrator. You cannot run it for them — it needs an interactive admin PowerShell on their PC.
- The PC must be running Tailscale (so the VM can reach it over the tailnet).

## Step 1 — Give the user the one-liner

Send the user this exact one-liner (PowerShell, run as Administrator on their PC). It downloads `onboard-may-moi.ps1` from this repo and runs it. The script will ask for the VM's public key — the user pastes the key you gave them.

```powershell
irm 'https://raw.githubusercontent.com/Neito112/muse.ai-cli/main/onboard-may-moi.ps1' -OutFile "$env:TEMP\onboard-may-moi.ps1"; Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-NoExit','-ExecutionPolicy','Bypass','-File',"$env:TEMP\onboard-may-moi.ps1"
```

(If you forked this repo, replace `Neito112/muse.ai-cli` with your fork's owner/repo in the URL.)

What the script does on the PC: installs OpenSSH Server, starts sshd, adds the VM's public key to `authorized_keys` (both the user file and the admin file `C:\ProgramData\ssh\administrators_authorized_keys`), fixes the file permissions (icacls), checks port 22, then prints three lines.

## Step 2 — Collect the three lines

After the script finishes, ask the user for the three lines it prints:

- Machine name (e.g. `NEITO-HOME`)
- Windows username (e.g. `Neito`)
- Tailnet IP (e.g. `100.77.164.36`)

Save these — they are how you address the machine from now on.

## Step 3 — Verify SSH from your VM

SSH to the tailnet IP as that user, using the VM's private key. Adapt the connection method to your own VM's network:

- If your VM reaches the tailnet directly: `ssh -i ~/.ssh/id_ed25519 <user>@<tailnet-ip> <command>`
- If your VM needs a proxy to reach the tailnet (e.g. an egress CONNECT proxy), route SSH through it.
- If your shell runs as root but HOME points elsewhere, pass the key explicitly with `-i <full path to id_ed25519>` — never assume ssh finds the key on its own.

A successful check prints the remote machine's output (e.g. `hostname`) and exits 0. Do NOT mark the machine as onboarded until this succeeds.

Notes:
- The PC's default SSH shell is cmd.exe. Chain commands with `&`, not `;`. For PowerShell, invoke it explicitly: `powershell -NoProfile -Command "..."`.
- First connection to a new tailnet IP may need the user's approval (proxy/firewall). If the connection is refused or times out, ask the user to check that Tailscale is running and sshd is up.

## Step 4 — Use the machine

Once verified, run work on the PC via SSH. The agent's VM stays the brain; the PC is the hands (its toolchain, its files). Prefer running builds/tests on the PC when the work needs its environment. Keep the VM's key out of chat and out of files — only the public key ever goes to the PC.

## If SSH login fails after onboarding

Give the user the fix one-liner (PowerShell as Administrator). It repairs the key file permissions, adds the key to the admin authorized_keys, and restarts sshd:

```powershell
irm 'https://raw.githubusercontent.com/Neito112/muse.ai-cli/main/fix-ssh-acl.ps1' -OutFile "$env:TEMP\fix-ssh-acl.ps1"; Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-NoExit','-ExecutionPolicy','Bypass','-File',"$env:TEMP\fix-ssh-acl.ps1"
```

Then re-run Step 3. Common causes: PowerShell 5.1 mangled the icacls arguments (this script works around it), or the account is an admin so sshd reads the admin authorized_keys file instead of the user's.

## Revoking access

To stop the agent reaching a PC: delete the key from `authorized_keys` (and the admin file), stop the OpenSSH service, or turn the PC off / leave the tailnet.

## Files

- `onboard-may-moi.ps1` — onboard a new PC.
- `fix-ssh-acl.ps1` — repair key login.
- `README.md` — the human-facing version of the same instructions.
