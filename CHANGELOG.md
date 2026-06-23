# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Both platforms:** the original `hosts` backup (`hosts.bak`) was overwritten
  on every run, so after the second run the "backup" was an already-fortressed
  file and a restore was useless. The backup is now written only once, on the
  first run, preserving the genuine pre-Fortress file.
- **Windows:** SafeSearch IPs could resolve to empty values because
  `Resolve-DnsName` returned the CNAME record first; now filtered to A records
  with a non-null address, falling back to the hardcoded IP otherwise.
- **Windows:** hosts file was written with a UTF-8 BOM (PowerShell 5.1
  `-Encoding utf8`), which corrupted the first entry; now written without a BOM
  and with normalized CRLF line endings.
- **Windows:** temporary `hosts_final.tmp` was left behind after each run; it is
  now removed.

### Changed
- **Windows installer:** the startup task now waits 3 minutes after boot so the
  network is ready before DNS resolution (parity with the Linux 5-minute boot
  delay).

### Added
- **Custom blocks:** documented using `hosts.local` to block sites the
  StevenBlack list misses (e.g. mirror domains like `en-redgifs.com`), with a
  worked example in `examples/hosts.local.example`. Entries are merged at the
  top of `hosts` every run, so they block and survive refreshes.
- **Windows installer:** disables DNS-over-HTTPS (DoH) via browser policy for
  Edge, Chrome, Brave, and Firefox, so browsers can no longer bypass the
  hosts-based filter. (Browsers will report "managed by your organization" — a
  side effect of any browser policy; revert steps are documented in the README.)
- `LICENSE` (MIT).
- `CHANGELOG.md`, `CONTRIBUTING.md`, `.editorconfig`.
- `examples/hosts.local.example`.
- Expanded README: Quick Start, table of contents, flow diagram, verification
  and uninstall steps for both platforms, and a troubleshooting section.

## [1.0.0]

### Added
- Initial release: cross-platform adult-content filtering and forced SafeSearch
  via `hosts` file management.
- Linux deployment through an Ansible playbook, a systemd service and timer.
- Windows deployment through a PowerShell installer registering a Scheduled Task.
- `hosts.local` support for preserving custom local entries.
