# Changelog

## 1.1.0

- On-screen indicator beside the compass: `Encounter log: on` in green; `Encounter log: off` in red when Always Logging should be logging but is not, amber when logging is off as expected.
- Show/hide and lock/unlock in settings or with `/alog indicator`, `/alog unlock`, `/alog lock`; drag to move; reset position button.
- The indicator also polls once a second, so it stays right even if another addon changes logging without going through the hooked function.

## 1.0.0

- Turns on encounter logging when entering the game, and after every loading screen if something turned it off.
- Account-wide settings by default; any character can switch to its own with `/alog character`, no reload needed.
- `/alog` (or `/alwayslogging`) to toggle, plus `on`, `off`, `status`, `account`, `character`.
- Chat messages for logging state: at login, when logging is turned on, and when something else turns it off.
- One-time note when Easy Stalking's automatic logging is also on.
- Optional LibAddonMenu-2.0 settings panel (`/alogsettings`).
