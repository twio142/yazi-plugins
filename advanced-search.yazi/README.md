# advanced-search.yazi

- `find`
    - Builtin find mode, but `close` will close and escape
- `filter`
    - Builtin filter mode, but `close` will close and escape
- `smart_filter`
    - Continuous filter mode
- `git_changes`
    - Search files with git status (untracked, modified, staged, etc.)

## Usage

Put this in your `keymap.toml`:

```toml
[manager]
prepend_keys = [
  { on = "/",        run = "plugin advanced-search find",         desc = "Find" },
  { on = "f",        run = "plugin advanced-search filter",       desc = "Filter" },
  { on = "F",        run = "plugin advanced-search smart_filter", desc = "Smart filter" },
  { on = ["g", "/"], run = "plugin advanced-search git_search",   desc = "Git search" },
  # ...
]

[input]
prepend_keymap = [
  { on = "<esc>", run = "close", desc = "Cancel input" },
]
```

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
