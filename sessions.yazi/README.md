# sessions.yazi

Save and restore tabs: cwd, name, cursor, preferences and selection, plus the yanked files and the active tab.

- `save [name]` - write the session
- `save_as` - prompt for the name, then write it
- `restore [name]` - close every tab and rebuild the saved one

Without a name, `default` is used. `save` and `save_as` also take `-q` to quit afterwards.

## Usage

```toml
# keymap.toml
[mgr]
prepend_keymap = [
  { on = ["u", "s"], run = "plugin sessions save",           desc = "Save session" },
  { on = ["u", "a"], run = "plugin sessions save_as",        desc = "Save session under a name" },
  { on = ["u", "r"], run = "plugin sessions restore",        desc = "Restore session" },
  { on = ["u", "q"], run = "plugin sessions 'save -q'",      desc = "Save session and quit" },
  { on = ["u", "w"], run = "plugin sessions 'save work'",    desc = "Save the `work` session" },
  { on = ["u", "e"], run = "plugin sessions 'restore work'", desc = "Restore the `work` session" },
]
```

Quote everything past the action as one argument, and quote a name with spaces again inside it: `"plugin sessions 'save \"work notes\"'"`.

## Restoring on startup

```lua
-- init.lua
require("sessions"):setup()
```

```sh
yazi -- -r         # restores `default`
yazi -- -r work    # restores `work`
```

The `--` is required, since Yazi's CLI rejects unknown flags, and `-r` only counts as the first argument after it.

## Storage

`sessions/<name>` inside the plugin's directory, e.g. `~/.config/yazi/plugins/sessions.yazi/sessions/default`. One tab-separated record per line:

```
idx	2
cut	0
yank	/home/me/notes/todo.md
tab	/home/me/notes
name	Notes
hov	/home/me/notes/todo.md
pref	show_hidden	1
sel	/home/me/notes/todo.md
tab	/home/me/src
hov	/home/me/src/main.rs
```

`ya pkg upgrade` redeploys the plugin's directory and can take the sessions with it.

## Notes

- Names and preferences are only recorded when a tab differs from your `yazi.toml`, so the rest keep following your config.
- Files that no longer exist are dropped from the selection, the yanked set and the cursor.
- Sessions over 9 tabs are truncated, Yazi's limit.
- A tab in search results is saved as the directory it searched.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
