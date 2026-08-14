# sessions.yazi

Save and restore a Yazi session: every tab's cwd, name, cursor position, preferences and selected files, plus the yanked files and the active tab.

- `save`
    - Write the current session to disk
- `save_as`
    - Ask for the session name first, then write it. An empty name saves to `default`, and cancelling the prompt saves nothing
- `restore`
    - Close every tab and rebuild the saved one in its place

Each action takes an optional session name, so several sessions can live side by side. Without one, `default` is used.

Both `save` and `save_as` also take `-q`, which quits Yazi once the session is on disk. Nothing is quit if the save fails, or if the `save_as` prompt is cancelled.

## Usage

Put this in your `keymap.toml`:

```toml
[mgr]
prepend_keymap = [
  { on = ["u", "s"], run = "plugin sessions save",    desc = "Save session" },
  { on = ["u", "a"], run = "plugin sessions save_as", desc = "Save session under a name" },
  { on = ["u", "r"], run = "plugin sessions restore", desc = "Restore session" },
  # Anything beyond the action needs the whole argument quoted:
  { on = ["u", "q"], run = "plugin sessions 'save -q'",      desc = "Save session and quit" },
  { on = ["u", "w"], run = "plugin sessions 'save work'",    desc = "Save the `work` session" },
  { on = ["u", "e"], run = "plugin sessions 'restore work'", desc = "Restore the `work` session" },
]
```

## Storage

Sessions are written to `sessions/<name>` inside the installed plugin's directory, i.e. `~/.config/yazi/plugins/sessions.yazi/sessions/default` for the default one. `YAZI_CONFIG_HOME` and `XDG_CONFIG_HOME` are honoured the same way Yazi honours them.

The format is one tab-separated record per line, so a session stays readable and editable:

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

Note that `ya pkg upgrade` redeploys the plugin's directory, which can take the saved sessions with it.

## Notes

- A tab's name is only recorded when it was actually renamed, since `tab.name` otherwise just mirrors the cwd.
- The same goes for the preferences `linemode`, `show_hidden`, `sort_by`, `sort_sensitive`, `sort_reverse`, `sort_dir_first`, `sort_translit` and `sort_fallback`: only the ones a tab moved away from your `yazi.toml` are written down, so the rest keep following your config as you change it.
- Files that disappeared between saving and restoring are dropped from the selection, the yanked set and the cursor position, so a stale session restores as much as it still can.
- Yazi allows at most 9 tabs, so a session holding more is truncated.
- A tab sitting in search results is saved as the directory that was searched, since search results can't be restored.

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
