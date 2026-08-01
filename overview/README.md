# Soul Overview

![Soul Overview thumbnail](thumbnail.webp)

Soul Overview adds a compact bar indicator and attached panel for Soul's active
Core, Voice Presence, and dynamically enrolled SSH-integrated fleet.

The active-Core control follows Soul's five-Core contract: **Soul Core**,
**Soul-Lite Core**, **Creative Core**, **Free Core**, and **Dev Core**. Free Core
is shown explicitly as having no model loaded; Dev Core is identified as the
active development lane.

## Plugin

| Field | Value |
| --- | --- |
| ID | `soul/overview` |
| Entries | Bar widget: `soul`; panel: `overview`; service: `collector` |

## Requirements

Install Soul's `soul-noctalia` companion command on `PATH`. The command must
support:

```text
soul-noctalia status
soul-noctalia voice-launch
soul-noctalia connect --device DEVICE_ID
soul-noctalia core-preview --core CORE_ID
soul-noctalia core-activate --core CORE_ID --target-profile PROFILE_ID \
  --confirmation PHRASE --expected-digest SHA256
```

## Usage

Add the `soul/overview:soul` widget to a Noctalia bar. Left-click the widget to
open the panel and right-click it to refresh.

Open the panel directly with:

```sh
noctalia msg panel-toggle soul/overview:overview
```

Within the panel:

- select **Change Core**, choose one of Soul's five configured Cores, review
  the exact transition, then select **Activate** as the second explicit gate;
- select **Launch Voice Presence** to ask Soul to open its foreground voice UI;
- left-click a device to open Soul's allowed connection in the default terminal;
- right-click a device to toggle its generic detail face;
- select **Refresh** to reread Soul's cached companion status.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `soul_command` | `string` | `soul-noctalia` | Companion executable or an absolute path without spaces. |

## Notes

The collector runs `soul-noctalia status` every 30 seconds with a 10-second
timeout. It does not probe the network itself. Status documents contain opaque
device IDs, bounded display rows, and allowed action IDs; resolved SSH aliases,
usernames, key paths, and credentials remain inside Soul.

Device connections are foreground terminal operations. The plugin passes only
the opaque selected device ID to `soul-noctalia connect`; Soul validates and
resolves the private target. The plugin performs no maintenance or reboot
actions, filesystem writes, or network requests.

Core activation is a bounded foreground operation over Soul's existing Core
orchestrator. The first click requests a fresh read-only preview. The plugin
retains that preview only in service memory and exposes a separate **Activate**
button; that click submits the exact target profile, confirmation phrase, and
SHA-256 state digest returned by Soul. Soul rechecks active work, runtime
idleness, target membership, confirmation, and digest freshness before any
model service changes. A plugin reload discards the pending preview.

The plugin cannot issue arbitrary model or system-service commands. It accepts
only the five reviewed Core IDs and bounded gate fields returned by Soul.
