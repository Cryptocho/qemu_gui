# AGENTS.md

## What this is

Single-package Flutter desktop app: a GUI manager for QEMU VMs. The real target is **Linux desktop (GTK)** — `android/`, `ios/`, `web/`, `windows/`, `macos/` are unused `flutter create` boilerplate. `README.md` and the pubspec description are stock template text; don't trust them for facts.

## Commands

- Run app: `flutter run -d linux`
- Analyze: `flutter analyze` — currently passes with ~15 info-level deprecation notices (`withOpacity`, `background`, …). That's the baseline; info output is not a failure, and don't bulk-fix deprecations as a side effect of unrelated work.
- Test: `flutter test` (one smoke test in `test/widget_test.dart`); tests don't require QEMU installed.
- Build release: `flutter build linux --release` → `build/linux/x64/release/bundle/`

## Architecture

- Entry: `lib/main.dart`. Settings and VMs are loaded **before** `runApp`. Providers: `SettingsService`, `QemuService`, `VMService` (ChangeNotifier), plus `SettingsWrapper`, which exposes the current `Settings` object via its own provider.
- Routes: named routes `/` (home), `/settings`, `/images`. `/wizard` is handled in `onGenerateRoute` and takes an optional `VMConfig` argument — present means edit-existing, absent means create-new.
- `lib/models/`: manual `toJson`/`fromJson`, **no codegen**. Any model field change must be hand-applied in all three files (`vm_config.dart`, `disk_image.dart`, `net_config.dart`).
- `lib/services/`:
  - `QemuService` — builds qemu-system args from a `VMConfig` (`buildArgs`; `headless` → `-display none`) and spawns via `Process.start`.
  - `VMService` — persists the whole VM list as one JSON string in SharedPreferences key `vms`; owns running `Process`es per VM id and a per-VM log buffer (capped at 1000 lines).
  - `SettingsService` — SharedPreferences key `settings` (qemu binary paths; defaults `qemu-system-x86_64` / `qemu-img` on PATH).
  - `ImageService` — thin wrappers around `qemu-img` (create / info / resize / convert).
- All persistence is `shared_preferences` JSON blobs, not files on disk.

## Gotchas

- `VMService.loadVMs()` silently resets to an empty list if the stored JSON fails to decode — a schema-breaking change makes all user VMs vanish with no error. Keep `fromJson` backward-compatible (use `??` fallbacks like existing fields); note `id`, `name`, and `netConfig` currently have none and will throw on decode failure.
- Port/guest forwards serialize through `PortForward.toString()` / `GuestForward.toString()` and are spliced verbatim into the `-netdev user` arg (`hostfwd=` / `guestfwd=`). Changing those string formats changes emitted QEMU commands.

## Release / versioning

- Bump version in **both** `pubspec.yaml` `version` and `PKGBUILD` `pkgver` (+ the `Version=` line in the generated `.desktop` entry) — currently 0.1.2.
- Releases are GitHub release tags on `Cryptocho/qemu_gui` containing `linux_x64.tar.xz` (the release bundle); `PKGBUILD` downloads it for the AUR package. No CI configured.