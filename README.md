# Always Logging

An Elder Scrolls Online addon that turns on encounter logging (the same switch as `/encounterlog`) every time you enter the game, and keeps it on.

Encounter logging writes `Logs/Encounter.log`, which you can upload to [esologs.com](https://www.esologs.com). It is easy to forget to turn it on and lose a run. Always Logging turns it on for you and tells you in chat when it does.

It is a simpler take on Easy Stalking: instead of choosing places to log, it logs everywhere.

## How it works

- **Entering the game** (log in, switch character, `/reloadui`): logging is turned on.
- **After each loading screen**: if `/encounterlog` or another addon turned logging off, it is turned back on. You can switch this off and only turn logging on at login.
- **Logging is only ever turned off when you say so**: `/alog off`, `/alog` (toggle), or the settings checkbox stop logging immediately. Logging in or changing zones never turns it off.

### Chat messages

| When | Message |
|------|---------|
| Always Logging turns logging on | `turned encounter logging ON.` |
| Entering the game, already logging | `Encounter logging is ON. Always Logging is on (account-wide settings).` |
| Something else turns logging off | A warning saying when it will come back on (at most once per loading screen) |
| Logging could not be turned on | `could not turn encounter logging on. Try /encounterlog.` |
| Easy Stalking's automatic logging is also on | A one-time note at login, because the two addons undo each other |

The login status line, the "after every loading screen" status line, and the switch-off warning can each be turned off in settings.

### On-screen indicator

A small label beside the compass shows the logging state at a glance:

| Shows | Means |
|-------|-------|
| 🟢 `Encounter log: on` (green) | Logging |
| 🔴 `Encounter log: off` (red) | Not logging, although Always Logging should have it on: you are losing a log |
| 🟠 `Encounter log: off` (amber) | Not logging, as expected: Always Logging is off, or it is about to turn logging on after a loading screen |

To move it: `/alog unlock`, show the cursor (the `.` key by default), drag it, then `/alog lock`. `/alog indicator` hides or shows it. It only appears with the normal HUD, not in menus.

## Slash commands

`/alog` and `/alwayslogging` are interchangeable.

| Command | Description |
|---------|-------------|
| `/alog` | Toggle Always Logging on or off |
| `/alog on` | Turn it on; logging starts now |
| `/alog off` | Turn it off; logging stops now |
| `/alog status` | Show whether encounter logging is on, and which settings are in use |
| `/alog account` | Use the account-wide settings on this character |
| `/alog character` | Give this character its own settings (`char` and `toon` also work) |
| `/alog indicator` | Show or hide the on-screen indicator |
| `/alog unlock` | Unlock the indicator so it can be dragged (it shows while unlocked, even if hidden) |
| `/alog lock` | Lock the indicator in place |
| `/alogsettings` | Open the settings panel (needs LibAddonMenu-2.0) |

## Account-wide or per-character

By default every character uses one shared set of settings. Any character can switch to its own settings with `/alog character` or by unchecking **Use account-wide settings**. That lets you, say, keep logging on everywhere except on a crafting alt. Switching takes effect immediately; no reload is needed.

Switching never stops logging. If the settings you switch to have Always Logging on, logging is turned on; if they have it off, logging is left as it is.

## Settings

Open with `/alogsettings` or **Settings > Addons > Always Logging**.

| Setting | Default | Description |
|---------|---------|-------------|
| Use account-wide settings | On | Off gives this character its own settings |
| Always log encounters | On | Turn logging on when entering the game. Unchecking stops logging now |
| Keep it on after loading screens | On | Turn logging back on after a loading screen if something turned it off |
| Status when entering the game | On | Chat line after log in or `/reloadui` |
| Status after every loading screen | Off | Chat line after every loading screen, even when nothing changed |
| Warn when logging is turned off | On | Chat line when `/encounterlog` or another addon turns logging off |
| Show indicator | On | The on-screen `Encounter log: on/off` label |
| Lock position | On | Unlock to drag the indicator |
| Reset position | | Put the indicator back beside the compass |

Indicator visibility and position follow the account-wide/per-character choice like every other setting.

## Using it with Easy Stalking

Easy Stalking's **Automatic logging** turns logging off everywhere it is not set to log, so with both addons on they will undo each other on every loading screen. Always Logging runs after Easy Stalking and wins, but you get chat noise. Turn off one of them.

## Installation

Download the zip from [Releases](https://github.com/brainsnorkel/AlwaysLogging/releases) and extract it into your AddOns folder, so that you have `AddOns/AlwaysLogging/AlwaysLogging.txt`.

## Dependencies

- **LibAddonMenu-2.0** (optional): settings panel. Without it, everything works through `/alog`.

## Development

```sh
lua5.1 tests/run.lua              # offline harness with stubbed ESO API
luacheck . --config .luacheckrc   # lint
scripts/package.sh                # build dist/AlwaysLogging-<version>.zip
git config core.hooksPath .githooks   # run the same checks before each commit
```

Pushing a `v*` tag that matches `## Version:` in the manifest builds the zip and creates a GitHub release.

## License

MIT
