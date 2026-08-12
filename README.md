# Soul for Noctalia

This repository is a Noctalia v5 Git source for the public Soul companion
plugin. Soul remains responsible for private configuration, enrolled-device
discovery, status collection, and action authorization; the plugin only renders
Soul's bounded companion contract.

## Install

Add this repository as a custom Git source and enable the plugin:

```sh
noctalia msg plugins source add soul git https://github.com/Unhall0w3d/soul-noctalia
noctalia msg plugins enable soul/overview
```

Add the `soul/overview:soul` widget to a bar through Noctalia Settings.

## Source layout

```text
overview/         Soul Overview plugin
manual-presence/  Optional standalone arRPC manual-presence plugin
catalog.toml      Noctalia source catalog
```

The plugin requires the `soul-noctalia` companion command supplied by Soul. No
fleet topology, SSH aliases, addresses, usernames, keys, or credentials are
stored in this repository.

`arrpc/manual-presence` is separate from Soul Overview: it publishes only an
explicit operator-provided Rich Presence through a local arRPC server. It does
not use Soul state, private inventory, or Discord credentials.
