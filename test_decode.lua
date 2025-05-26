-- Test script for HexerDecode
package.path = package.path .. ";./lua/?.lua"
local hexer = require('hexer.api')

-- Mock vim functions for testing
_G.vim = {
  api = {
    nvim_create_namespace = function() return 1 end,
    nvim_win_get_cursor = function() return {1, 0} end,
    nvim_buf_set_lines = function(_, _, _, _, lines)
      print("Output:")
      print(string.rep("-", 70))
      for _, line in ipairs(lines) do
        print(line)
      end
    end,
    nvim_buf_add_highlight = function() end
  },
  fn = {
    system = function(cmd)
      if cmd:match("which cast") then
        return "/usr/local/bin/cast"
      elseif cmd:match("cast 4byte%-decode") then
        -- Return the expected cast output
        return [[1) "modifyAllocations(address,((address,uint32),address[],uint64[])[])"
0x7aBF46564cfd4d67E36DC8fB5DeF6a1162EBaF6b
[((0xcc3Bc3f5397e2b3c5D9869CD17566Ce88E47DceC, 0), [0x8b29d91e67b013e855EaFe0ad704aC4Ab086a574, 0x424246eF71b01ee33aA33aC590fd9a0855F5eFbc], [1, 1])]]]
      end
    end,
    shellescape = function(s) return s end
  },
  v = { shell_error = 0 },
  log = { levels = { INFO = 1 } },
  notify = function(msg) print("Notification: " .. msg) end,
  cmd = function() end,
  split = function(str, sep)
    local lines = {}
    for line in str:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    return lines
  end
}

-- Test calldata
local calldata = "0x952899ee0000000000000000000000007abf46564cfd4d67e36dc8fb5def6a1162ebaf6b000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000cc3bc3f5397e2b3c5d9869cd17566ce88e47dcec0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000020000000000000000000000008b29d91e67b013e855eafe0ad704ac4ab086a574000000000000000000000000424246ef71b01ee33aa33ac590fd9a0855f5efbc000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"

-- Config
local config = {
  output_method = "insert",
  show_offset = true,
  offset_format = "hex"
}

-- Run the decode
hexer.abi_decode(calldata, config)