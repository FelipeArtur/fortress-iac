# Fortress IaC

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-lightgrey)
![Linux: Ansible](https://img.shields.io/badge/Linux-Ansible%20%2B%20systemd-EE0000?logo=ansible&logoColor=white)
![Windows: PowerShell](https://img.shields.io/badge/Windows-PowerShell%205.1%2B-5391FE?logo=powershell&logoColor=white)

**Fortress IaC** is a lightweight, cross-platform infrastructure-as-code tool that enforces **adult-content filtering** and **forced SafeSearch** on a machine — without any paid service, browser extension, or third-party agent.

It works by managing the operating system's `hosts` file: it blocks adult domains using the public [StevenBlack/hosts](https://github.com/StevenBlack/hosts) blocklist and pins major search engines (Google, Bing, DuckDuckGo) to their strict/SafeSearch endpoints. Once installed it runs automatically at boot and weekly, so the protection stays current and survives reboots.

Designed for parental control, shared/family computers, kiosks, and managed workstations on both **Linux** and **Windows**.

> [!IMPORTANT]
> **Scope & limitations.** This is a host-level control, not a tamper-proof filter.
> - A user with **administrator/root** rights can disable it (revert the `hosts` file or remove the scheduler).
> - Browsers using **DNS-over-HTTPS (DoH)** or **encrypted DNS** bypass the `hosts` file. For full coverage, disable DoH in the browser or enforce filtering at the network/router level.
> - It does not filter HTTPS content inside an allowed site, nor non-web traffic.
>
> Treat it as one layer of defense, not a complete solution.

---

## Quick Start

**Linux** (Ansible + systemd):
```bash
git clone https://github.com/FelipeArtur/fortress-iac.git
cd fortress-iac/linux
sudo ansible-playbook playbook.yml
```

**Windows** (PowerShell as Administrator):
```powershell
git clone https://github.com/FelipeArtur/fortress-iac.git
cd fortress-iac\windows
.\install.ps1
```

That's it — filtering applies immediately and re-runs at every boot and weekly. See [Verify it works](#verify-it-works) and [Uninstall](#uninstall-linux) below.

---

## Table of Contents

- [How It Works](#how-it-works)
- [Repository Structure](#repository-structure)
- [Getting the Repository](#getting-the-repository)
- [Linux Deployment](#linux-deployment)
- [Windows Deployment](#windows-deployment)
- [Managing Custom Local Entries](#managing-custom-local-entries)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## How It Works

On every run the engine performs an atomic, idempotent rebuild of the `hosts` file:

1. **Preserve local entries.** On first run it captures the existing `hosts` into an auxiliary `hosts.local` file (see [Custom Local Entries](#managing-custom-local-entries)); on later runs that file is merged back at the top, so your custom routes are never lost.
2. **Download the blocklist** from the StevenBlack `alternates/porn` matrix.
3. **Resolve SafeSearch endpoints** for Google, Bing, and DuckDuckGo (with hardcoded fallback IPs if DNS is unavailable, e.g. early at boot).
4. **Assemble** local entries + blocklist + SafeSearch overrides into a single file.
5. **Apply atomically** — on the first run the original `hosts` is saved to `hosts.bak` (kept untouched afterwards), then the file is replaced in one move to avoid partial/corrupt routing.
6. **Flush the DNS cache** so changes take effect immediately.

Every run fully rebuilds the file from `hosts.local` plus a freshly downloaded blocklist — nothing is appended — so **repeated runs never accumulate stale or duplicate entries**, the original backup is preserved, and temporary files are removed each time. The whole flow is automated by a **systemd timer** (Linux) or a **Scheduled Task** (Windows), running at startup and once a week.

```text
        ┌──────────────┐      ┌──────────────────┐      ┌─────────────────┐
        │ boot / weekly │ ───▶ │ fortress-update   │ ───▶ │ atomic rebuild   │
        │   scheduler    │      │ (bash / PowerShell)│      │ of /etc/hosts    │
        └──────────────┘      └──────────────────┘      └─────────────────┘
                                        │                          │
                          hosts.local + StevenBlack list +   backup → hosts.bak
                              SafeSearch IP overrides          + flush DNS cache
```

---

## Repository Structure

```text
fortress-iac/
├── README.md                    # This file
├── LICENSE                      # MIT
├── CHANGELOG.md                 # Version history
├── CONTRIBUTING.md              # Dev/test guide
├── .editorconfig                # Consistent formatting across editors
├── examples/
│   └── hosts.local.example      # Sample custom local-entries file
├── linux/
│   ├── playbook.yml             # Ansible deployment playbook
│   └── files/
│       ├── fortress-update      # Main engine (bash)
│       ├── fortress-update.service
│       └── fortress-update.timer
└── windows/
    ├── install.ps1              # Deployment (Task Scheduler)
    └── fortress-update.ps1      # Main engine (PowerShell)
```

---

## Getting the Repository

The [Quick Start](#quick-start) clones via Git. If you don't have Git (common on Windows), download the ZIP instead:

1. Open the repository page in your browser.
2. Click **Code → Download ZIP**.
3. Extract it and open a terminal/PowerShell inside the `fortress-iac` folder.

---

## Linux Deployment

### Prerequisites
- `ansible` (for deployment)
- `curl`
- `getent` (part of `glibc`, present on virtually every distro)

### Installation
1. Enter the Linux directory:
   ```bash
   cd linux
   ```
2. Run the playbook with root privileges:
   ```bash
   sudo ansible-playbook playbook.yml
   ```
3. Confirm the timer is active:
   ```bash
   systemctl status fortress-update.timer
   ```

The playbook installs the engine to `/usr/local/sbin/fortress-update` and enables a systemd timer that fires **5 minutes after boot** and **weekly**.

### Verify it works
```bash
sudo /usr/local/sbin/fortress-update   # run once on demand
grep -m1 StevenBlack /etc/hosts        # blocklist present?
getent hosts www.google.com            # should resolve to a forcesafesearch IP
systemctl list-timers fortress-update.timer
```

### Uninstall (Linux)
```bash
sudo systemctl disable --now fortress-update.timer
sudo rm /etc/systemd/system/fortress-update.{service,timer}
sudo systemctl daemon-reload
sudo rm /usr/local/sbin/fortress-update
sudo cp /etc/hosts.bak /etc/hosts        # restore the pre-Fortress hosts file
sudo resolvectl flush-caches 2>/dev/null || true
```

---

## Windows Deployment

### Prerequisites
- PowerShell **5.1+**
- Administrator privileges

### Installation
1. Open **PowerShell as Administrator**.
2. Enter the Windows directory:
   ```powershell
   cd windows
   ```
3. Run the installer:
   ```powershell
   .\install.ps1
   ```
   > If execution is blocked by policy, run this first (current session only):
   > ```powershell
   > Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   > ```

The installer registers a Scheduled Task (`Fortress-IaC-Update`) under the **SYSTEM** account that runs **at startup (3-minute delay so the network is ready)** and **weekly (Sunday 03:00)**, then runs it once immediately.

It also **disables DNS-over-HTTPS (DoH)** via policy for Edge, Chrome, Brave, and Firefox — otherwise those browsers resolve domains over encrypted DNS and ignore the hosts file, defeating the filter. As a side effect, the browsers will report *"managed by your organization"* and the secure-DNS toggle becomes greyed out; this is expected and is what keeps the filter from being bypassed. See [Troubleshooting](#troubleshooting) to revert it.

### Verify it works
```powershell
Get-Content $env:windir\System32\drivers\etc\hosts | Select-String "StevenBlack" | Select-Object -First 1
Resolve-DnsName www.google.com   # should map to a forcesafesearch IP
Get-ScheduledTask -TaskName "Fortress-IaC-Update"
```

### Uninstall (Windows)
```powershell
Unregister-ScheduledTask -TaskName "Fortress-IaC-Update" -Confirm:$false
Copy-Item "$env:windir\System32\drivers\etc\hosts.bak" "$env:windir\System32\drivers\etc\hosts" -Force
Clear-DnsClientCache
```

---

## Managing Custom Local Entries

The `hosts.local` file is your override layer. Its contents are merged at the **top** of the main `hosts` file on every run, so they always take precedence and are never lost when the blocklist refreshes.

- **Linux:** `/etc/hosts.local`
- **Windows:** `C:\Windows\System32\drivers\etc\hosts.local`

On first run, if no `hosts.local` exists, your current `hosts` file is copied into it so nothing is lost. See [`examples/hosts.local.example`](examples/hosts.local.example) for the format.

Two uses:

**1. Preserve local routes** — dev server IPs, internal shortcuts, etc.:
```text
192.168.1.10   dev.local
```

**2. Add your own blocks** — sites the StevenBlack list misses, such as **mirror domains** (language-prefixed variants, brand-new sites). Point them at `0.0.0.0`:
```text
0.0.0.0  unwanted-site.example
0.0.0.0  www.unwanted-site.example
```

> Hosts files have **no wildcards** — list every domain (and `www.` variant) explicitly. After editing, re-apply and flush:
> ```bash
> sudo /usr/local/sbin/fortress-update && sudo resolvectl flush-caches   # Linux
> ```
> ```powershell
> .\fortress-update.ps1 ; ipconfig /flushdns                              # Windows
> ```
> For broad, mirror-proof category blocking that a static list can't keep up with, point your OS/router at a family DNS resolver (e.g. Cloudflare for Families `1.1.1.3`) — see [Troubleshooting](#troubleshooting).

---

## Troubleshooting

**SafeSearch / blocklist not enforced — sites still load.**
Browsers with **DNS-over-HTTPS** ignore the `hosts` file. On **Windows** the installer disables DoH automatically (Edge, Chrome, Brave, Firefox) via policy. On **Linux**, or if you skipped that, disable it manually (Chrome/Edge: *Settings → Privacy → Use secure DNS = Off*; Firefox: *Settings → Privacy → DNS over HTTPS = Off*) or enforce filtering at the router. After any change, flush the cache (`Clear-DnsClientCache` / `resolvectl flush-caches`) and fully restart the browser (browsers also keep their own DNS cache and live connections).

**Browser says "managed by your organization" after install (Windows).**
Expected — the installer sets the DoH-off browser policy, and any browser policy triggers that banner. It does **not** mean a remote organization controls your machine (verify with `dsregcmd /status`: all `NO` = no org). To revert, delete the policy values — but DoH will then be re-enabled and can bypass the filter:
```powershell
Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Edge"        -Name DnsOverHttpsMode -ErrorAction SilentlyContinue
Remove-ItemProperty "HKLM:\SOFTWARE\Policies\Google\Chrome"         -Name DnsOverHttpsMode -ErrorAction SilentlyContinue
Remove-ItemProperty "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"   -Name DnsOverHttpsMode -ErrorAction SilentlyContinue
Remove-Item "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS" -Recurse -ErrorAction SilentlyContinue
```

**Windows: changes to `hosts` get reverted or blocked.**
Windows Defender's **Controlled Folder Access** and some antivirus "tamper protection" features guard the `hosts` file. If edits are blocked, add `powershell.exe` (or the script) to the allowed apps, or temporarily disable Controlled Folder Access while installing.

**The list didn't update at boot.**
On Linux the timer waits 5 min after boot; on Windows the task waits 3 min — both so the network is up before DNS resolution. If the network is still down at that point, the script uses built-in fallback IPs for SafeSearch (the blocklist download is skipped until the next successful run).

**I want to undo everything.**
Restore the backup (`hosts.bak`) — see the Uninstall sections above.

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to test the scripts locally, the linters used (`shellcheck`, `PSScriptAnalyzer`, `ansible-lint`), and the coding conventions.

---

## License

Released under the [MIT License](LICENSE). © 2026 Felipe Artur.
