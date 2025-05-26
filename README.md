# This is experimental! A work in progress.

## What

When working with solidity, json-rpc or Remix, a long string is hard to grok. For example, transaction calldata is encoded and it is easier to format it before investigating . This plugin splits the selector and data portion, so you can start decoding.

For example, given the following calldata:
```
["0xc6f922d00000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"]
```

Hexer breaks the calldata into a selector and data , placing the formatted output above the source (current word/line). Each line of data represents 32 bytes of data split into 4 byte chunks. There's also an offset indicator to help with navigation.
```
Selector: 0xc6f922d0
0000000000000000000000000000000000000000000000000000000000000007 // 0x000 (000)
0000000000000000000000000000000000000000000000000000000000000060 // 0x020 (032)
0000000000000000000000000000000000000000000000000000000000000009 // 0x040 (064)
0000000000000000000000000000000000000000000000000000000000000003 // 0x060 (096)
0000000000000000000000000000000000000000000000000000000000000001 // 0x080 (128)
0000000000000000000000000000000000000000000000000000000000000002 // 0x0a0 (160)
0000000000000000000000000000000000000000000000000000000000000003 // 0x0c0 (192)
["0xc6f922d00000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000090000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003"]
```

## Asciinema Demo

[![asciicast](https://asciinema.org/a/Ee0K1WSutTCpn4nL68zXAYsgn.png)](https://asciinema.org/a/Ee0K1WSutTCpn4nL68zXAYsgn)


## Config

### [folke/lazy](https://github.com/folke/lazy.nvim)

```lua
{
  "cds-amal/hexer-nvim",
  name = "hexer",
  lazy = false,
  config = function()
    require("hexer").setup({
      -- your configuration (optional)
    })
  end
}
```

### Commands

- `:HexerFormat [input]` - Format hex calldata (works with visual selection)
- `:HexerBytesToAscii [input]` - Convert hex bytes to ASCII

### Key bindings

```lua
-- Normal mode
vim.keymap.set('n', '<leader>hf', '<cmd>HexerFormat<cr>', { desc = 'Format hex calldata' })
vim.keymap.set('n', '<leader>ha', '<cmd>HexerBytesToAscii<cr>', { desc = 'Convert hex to ASCII' })

-- Visual mode support
vim.keymap.set('v', '<leader>hf', '<cmd>HexerFormat<cr>', { desc = 'Format selected hex' })
vim.keymap.set('v', '<leader>ha', '<cmd>HexerBytesToAscii<cr>', { desc = 'Convert selected hex to ASCII' })
```

### Configuration

```lua
require("hexer").setup({
  -- Display options
  group_size = 64,        -- Characters per line (32 bytes = 64 hex chars)
  show_offset = true,     -- Show offset comments
  offset_format = "both", -- "hex", "decimal", or "both"
  
  -- Formatting options  
  show_selector = true,   -- Show selector line for calldata
  uppercase = false,      -- Use uppercase hex letters
  
  -- Highlight groups
  highlights = {
    selector = "Title",
    offset = "Comment",
  },
})
```

### Health Check

Run `:checkhealth hexer` to verify your installation.
