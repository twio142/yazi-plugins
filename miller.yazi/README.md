# miller.yazi

[Miller](https://github.com/johnkerl/miller) now in [yazi](https://github.com/sxyazi/yazi). To install, use the command `ya pack -a twio142/miller` and add to your `yazi.toml`:

```toml
[plugin]
prepend_previewers = [
    { mime = "text/csv", run = "miller" },
    { name = "*.csv", run = "miller" },
]
```

## Preview

![preview](https://github.com/Reledia/miller.yazi/blob/main/preview.png?raw=true)

## Custom options

Put the following code in your `init.lua`:

```lua
-- default options
require("miller").setup({
    ["-C"] = true,            -- if the value is true, the key will be used as a flag
    ["--icsv"] = true,
    ["--opprint"] = true,
    ["--key-color"] = "208",  -- if the value is a string, both key and value will be passed as arguments
    ["--value-color"] = "grey70",
})

-- actual command: mlr -C --icsv --opprint --key-color 208 --value-color grey70 cat $FILE
```

If `--ifs` (input field separator) is not set, the plugin will try to detect it from the file.

Explicitly setting an option to `false` will remove it from the command.
