# arRPC Manual Presence

An opt-in Noctalia v5 panel for publishing one manually chosen Discord Rich
Presence through a locally running [arRPC](https://arrpc.openasar.dev/) server.

It does **not** inspect running applications, read Discord messages, capture
credentials, start `arrpc`, or share data with Soul. Each publish, clear, and
status action opens one local `discord-ipc-*` Unix socket, sends one bounded
request, and exits.

## Setup

1. Install and start `arrpc` using your distribution's normal user-service
   workflow.
2. Enable arRPC support in Vencord, Vesktop, or the compatible Discord client
   you use.
3. Create a Discord application in the Developer Portal and copy its public
   **Application ID**. No bot token, client secret, or Discord password belongs
   in this plugin.
4. Enable `arrpc/manual-presence` in Noctalia, add its `manual-presence` widget
   to a bar, and open the panel. This is the supported interface; a generated
   preview window is not the installed plugin. The default publisher resolves
   from Noctalia's own materialized plugin directory. Advanced users can
   override it with an absolute path to an executable copy of
   `arrpc-manual-presence`.

Enter the Application ID, a Details line, optional State line, then choose
**Publish override**. While enabled, the selected activity is a deliberate
static presence. The public Application ID and visible activity text are kept
in Noctalia's local plugin-data directory so the active state is visible after
a shell reload. Choose **Use automatic activity** to send `SET_ACTIVITY` with a
null activity; arRPC can then continue presenting ordinary application
activity.

## Scope and limitations

The activity uses Discord's normal Rich Presence fields and is subject to the
client's arRPC integration. It contains no image assets in this first version;
adding image keys requires uploading corresponding assets to the user's Discord
application and is intentionally deferred.

If Noctalia crashes while an override is active, the last activity may remain
until the Discord/arRPC session is refreshed or the panel is opened and turned
off. This plugin deliberately does not run an autonomous cleanup daemon.
