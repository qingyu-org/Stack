# Mono Dash

Language: English | [简体中文](README.zh-CN.md)

Mono Dash is an open-source, third-party mobile management client for
[1Panel](https://github.com/1Panel-dev/1Panel).

Connect to your own 1Panel servers and manage daily operations from your phone
with a focused, native interface.

> Mono Dash is an independent third-party client. It is not an official 1Panel
> product and is not affiliated with, endorsed by, or sponsored by 1Panel.

## Features

- Monitor CPU, memory, disk, network traffic, load, uptime, and host details
- Manage websites, domains, HTTPS certificates, logs, and website configuration
- Browse, upload, download, edit, move, compress, decompress, share, and delete
  server files
- Work with databases, containers, images, compose projects, and app updates
- View system, login, operation, SSH, website, container, and task logs
- Open terminal sessions and manage SSH-related settings
- Manage backups, snapshots, cron jobs, firewall rules, processes, runtimes, and
  toolbox tasks
- Add unlimited 1Panel servers and switch between them from a mobile-first
  interface
- **1Panel Professional multi-node support**: adding a Pro panel automatically
  detects its license and child nodes, groups them into one card, and routes
  every request to the selected node with 1Panel's `CurrentNode` header
- **Read-only Pro dashboards** for WAF, website monitoring, operations reports,
  tamper protection, and resource sync (shown when the panel exposes the APIs)
- Manual edition override in the panel editor for panels where auto-detection is
  not appropriate

## Open Source

Mono Dash is developed as an open-source project. You can review the source
code, follow development, report issues, and contribute through this repository.

- Source code: <https://github.com/willow-god/Mono-Dash>
- Upstream: <https://github.com/nowubh/Mono-Dash>

## Unlimited Servers

This fork removes the upstream one-server limit and the in-app purchase flow.
All server slots and the Professional feature entries are available without an
account, activation code, or license purchase. Access to 1Panel Professional
APIs still depends on the license and permissions of the panel you connect to.

## Privacy and Data

Mono Dash stores server connection settings on your device and connects directly
to the 1Panel servers you configure. Mono Dash does not operate a backend for
collecting your 1Panel server data.

Read the full policies:

- [Privacy Policy](PRIVACY.md) | [隐私政策](PRIVACY.zh-CN.md)
- [Terms of Use](TERMS.md) | [使用条款](TERMS.zh-CN.md)

## Important Notice

Use Mono Dash only with servers you own, administer, or are authorized to
access. Server management actions can affect websites, databases, containers,
files, backups, firewall rules, scheduled jobs, and other production resources.
Review destructive operations carefully and keep independent backups of
important data.

Mono Dash depends on the 1Panel API and may not be compatible with every 1Panel
version, plugin, server configuration, or deployment environment.

## Development

This repository contains the Flutter client source code.

### Requirements

- Flutter SDK with Dart compatible with `^3.11.1`
- Xcode for iOS builds
- Android Studio and Android SDK for Android builds

### Run Locally

```bash
flutter pub get
flutter run
```

### Checks

```bash
flutter analyze
flutter test
```

## Project Links

- Repository: <https://github.com/willow-god/Mono-Dash>
- Privacy Policy: <https://github.com/willow-god/Mono-Dash/blob/main/PRIVACY.md>
- Terms of Use: <https://github.com/willow-god/Mono-Dash/blob/main/TERMS.md>
- 1Panel: <https://github.com/1Panel-dev/1Panel>

## License

This project is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE) for details.
