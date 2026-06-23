# Fortress IaC

Fortress IaC is an infrastructure automation solution designed to enforce adult content filtering and SafeSearch across major search engines (Google, Bing, DuckDuckGo). The tool operates by dynamically managing the operating system's `hosts` file and supports both Linux and Windows environments.

## Architecture

The automation script executes during system boot and on a scheduled weekly basis. The execution flow consists of:

1. Identifying and preserving local network configurations via an auxiliary file (`hosts.local`).
2. Downloading the public adult content blocklist from the [StevenBlack/hosts](https://github.com/StevenBlack/hosts) repository.
3. Resolving and injecting DNS endpoints to enforce strict SafeSearch modes.
4. Applying the changes atomically to prevent local routing corruption.
5. Flushing the system's DNS cache.

## Repository Structure

```text
fortress-iac/
├── README.md
├── linux/
│   ├── playbook.yml             # Ansible deployment playbook
│   └── files/                   # Main script and Systemd units
└── windows/
    ├── install.ps1              # Deployment script (Task Scheduler)
    └── fortress-update.ps1      # Main PowerShell script
```

## Getting the Repository

To start the installation in any environment, you must first obtain the project files to your local machine.

**Via Git (Recommended):**
```bash
git clone https://github.com/FelipeArtur/fortress-iac.git
cd fortress-iac
```

**Via Compressed File (ZIP):**
If you don't have Git installed (a common scenario on Windows servers or workstations), you can get the files without relying on the command line:
1. Go to the repository page in your browser.
2. Click the **Code** button and select **Download ZIP**.
3. Extract the file and open the Terminal or PowerShell inside the `fortress-iac` folder.

## Linux Deployment

### Prerequisites
*   `ansible` (For deployment)
*   `curl`
*   `getent`

### Installation

1. Navigate to the Linux directory:
   ```bash
   cd linux
   ```
2. Execute the Ansible playbook with superuser privileges:
   ```bash
   sudo ansible-playbook playbook.yml
   ```
3. Verify the service schedule status:
   ```bash
   systemctl status fortress-update.timer
   ```

## Windows Deployment

### Prerequisites
*   PowerShell 5.1 or higher
*   Administrator privileges

### Installation

1. Open PowerShell as Administrator.
2. Navigate to the Windows directory:
   ```powershell
   cd windows
   ```
3. Execute the installation script:
   ```powershell
   .\install.ps1
   ```
   *Note: If system policies block the execution, use the command `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` beforehand.*

The installer will configure a Scheduled Task running under the `SYSTEM` account, scheduled to execute on machine startup and weekly.

## Managing Custom Local Entries

To preserve local network configurations that shouldn't be overwritten (such as local development server IPs or internal shortcuts), routes must be declared in the corresponding file below. The system will automatically include this content at the beginning of the main `hosts` file on every execution.

*   **Linux:** `/etc/hosts.local`
*   **Windows:** `C:\Windows\System32\drivers\etc\hosts.local`
