# Contributing to Fortress IaC

Thanks for your interest in improving Fortress IaC. This guide covers how to set
up, test, and lint changes to the Linux and Windows engines.

## Project layout

| Path | Purpose |
| --- | --- |
| `linux/files/fortress-update` | Main engine (bash) |
| `linux/files/*.service`, `*.timer` | systemd units |
| `linux/playbook.yml` | Ansible deployment |
| `windows/fortress-update.ps1` | Main engine (PowerShell) |
| `windows/install.ps1` | Scheduled Task installer |
| `examples/hosts.local.example` | Sample custom local-entries file |

Both engines implement the same six-step flow (see the README's *How It Works*).
Keep their behavior in sync: a change to one platform usually needs the matching
change on the other.

## Testing safely

The scripts rewrite the system `hosts` file. **Test in a throwaway VM or
container**, never directly on a machine you depend on. A run always backs up the
current file to `hosts.bak`, so recovery is `cp hosts.bak hosts`.

### Linux
```bash
# Lint
shellcheck linux/files/fortress-update
ansible-lint linux/playbook.yml

# Dry run the playbook (no changes applied)
sudo ansible-playbook linux/playbook.yml --check

# Run the engine once, manually
sudo linux/files/fortress-update
```

### Windows
```powershell
# Lint (install once: Install-Module PSScriptAnalyzer -Scope CurrentUser)
Invoke-ScriptAnalyzer .\windows\fortress-update.ps1
Invoke-ScriptAnalyzer .\windows\install.ps1

# Run the engine once, manually (PowerShell as Administrator)
.\windows\fortress-update.ps1
```

## Conventions

- **Idempotent & atomic:** every run must produce the same result and must never
  leave the `hosts` file in a partial state. Write to a temp file, then replace.
- **No BOM on Windows:** write the `hosts` file as UTF-8 without a BOM
  (`System.Text.UTF8Encoding($false)`), with CRLF line endings.
- **Fallbacks:** DNS resolution must degrade to the hardcoded fallback IPs when
  the network is unavailable (e.g. early at boot).
- **English:** keep code comments, script output, and documentation in English.
- **Commit messages:** use [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`).
- **Changelog:** add a note under `## [Unreleased]` in `CHANGELOG.md` for any
  user-visible change.

## Pull requests

1. Fork and branch from `main`.
2. Make the change on **both** platforms when applicable.
3. Lint and test in a VM/container.
4. Update `CHANGELOG.md` and, if behavior changed, the README.
5. Open the PR with a clear description of what and why.
