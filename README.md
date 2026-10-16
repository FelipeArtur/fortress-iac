# Fortress IaC

Archived historical project, licensed under [MIT](LICENSE).

Fortress IaC was a personal experiment in adult-domain filtering and
SafeSearch mappings through the operating system's `hosts` file. It preceded
my AsusDebian home-server project, where I moved the filtering approach to
network DNS. AsusDebian is maintained separately.

This repository preserves the Linux and Windows implementations for reference.
It is no longer maintained and receives no security updates. New installations
are not recommended.

## Historical implementation

- Linux: Ansible installed a Bash updater and a systemd service and timer.
- Windows: PowerShell installed a startup and weekly task running as SYSTEM.
- Both engines combined local entries, the StevenBlack blocklist and SafeSearch
  mappings, preserving an initial `hosts.bak`.

The code remains available in `linux/` and `windows/`. The MIT license permits
reuse; any reuse requires an independent review of the privileged operations.

## Known security and recovery limits

A static `hosts` list cannot guarantee content filtering. Administrators can
change it, and applications using other resolution paths can bypass it.
Encrypted DNS behavior depends on the application; disabling DoH does not
establish complete coverage. Allowed domains can still serve unwanted content.

The archived implementation also has unresolved risks:

- The Linux updater runs as root and writes predictable files in `/tmp`, which
  permits interference through pre-created files or symbolic links. Moving
  from `/tmp` to `/etc` also does not guarantee an atomic replacement across
  filesystems. Its download does not reject HTTP error responses or validate
  the blocklist before applying it.
- The Windows SYSTEM task executes the script from its clone directory without
  establishing a protected installation directory. Users able to modify that
  script can affect code executed as SYSTEM.
- Windows installation changes machine-wide browser policies without preserving
  their previous values. Uninstallation can remove existing settings and
  restoring an old `hosts.bak` can discard later local changes.
- `windows/nuke.ps1` discards custom hosts entries, deletes `hosts.bak` and
  attempts to stop the DNS Client service. It can continue after errors and
  must not be treated as a safe recovery procedure.

These findings come from source review, not runtime testing. No installer,
updater or reset script was run during the archival review. Do not disable
endpoint protection or DNS services to run this archive.

## Existing installations

Archiving this repository does not remove an existing installation or stop its
scheduled updates. Before changing one, inspect its scheduler, current `hosts`
file, saved copies and browser policies. Recovery must preserve the machine's
current local entries and any independently managed policies.

## History

[CHANGELOG.md](CHANGELOG.md) retains the development record. Earlier installation
documentation is available in Git history and describes an unsupported version.
[CONTRIBUTING.md](CONTRIBUTING.md) describes the archival status and safe inspection.
