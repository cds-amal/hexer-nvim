# This is experimental! A work in progress.

## What

When working with solidity, json-rpc or Remix, a long string is hard to grok. For example, transaction calldata is encoded and it is easier to format it before investigating . This plugin splits the selector and data portion, so you can start decoding.

## Features

### Format Calldata
Given the following calldata:
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

### ABI Decode (NEW!)
With Foundry installed, you can decode calldata to see the function signature and arguments:

```
0x952899ee0000000000000000000000007abf46564cfd4d67e36dc8fb5def6a1162ebaf6b...
```

Running `:HexerDecode` will show:
```
ABI Decoded Calldata
──────────────────────────────────────────────────────────────────────
Function: modifyAllocations(address,((address,uint32),address[],uint64[])[])

Calldata: 0x952899ee00...

Operator: 0x7aBF46564cfd4d67E36DC8fB5DeF6a1162EBaF6b    @ 0x000

AllocationParams:                                        @ 0x020
└─ AllocationParams[0]:
   ├─ operatorSet.avs: 0xcc3Bc3f5397e2b3c5D9869CD17566Ce88E47DceC
   ├─ operatorSet.id:  0
   ├─ strategies:
   │  ├─ [0] 0x8b29d91e67b013e855EaFe0ad704aC4Ab086a574
   │  └─ [1] 0x424246eF71b01ee33aA33aC590fd9a0855F5eFbc
   └─ magnitudes:
      ├─ [0] 1
      └─ [1] 1
──────────────────────────────────────────────────────────────────────
```

## Asciinema Demo

[![asciicast](https://asciinema.org/a/Ee0K1WSutTCpn4nL68zXAYsgn.png)](https://asciinema.org/a/Ee0K1WSutTCpn4nL68zXAYsgn)


## Requirements

- Neovim >= 0.8.0
- [Foundry](https://getfoundry.sh/) (optional, required for `:HexerDecode` command)

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
- `:HexerDecode [input]` - Decode ABI calldata using Foundry (requires `cast` command)

### Key bindings

#### Default Keymaps
The plugin provides default keymaps (all start with `<leader>h`):
- `<leader>hd` - [H]exer [D]ecode - ABI decode calldata
- `<leader>hf` - [H]exer [F]ormat - Format hex calldata  
- `<leader>ha` - [H]exer [A]scii - Convert hex to ASCII

All keymaps work in both normal and visual mode.

To disable default keymaps, add this to your config before loading the plugin:
```vim
let g:hexer_no_mappings = 1
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
