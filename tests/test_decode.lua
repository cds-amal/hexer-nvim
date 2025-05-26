-- Test for HexerDecode functionality
local M = {}

-- Test calldata
M.test_calldata = "0x952899ee0000000000000000000000007abf46564cfd4d67e36dc8fb5def6a1162ebaf6b000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000cc3bc3f5397e2b3c5d9869cd17566ce88e47dcec0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000020000000000000000000000008b29d91e67b013e855eafe0ad704ac4ab086a574000000000000000000000000424246ef71b01ee33aa33ac590fd9a0855f5efbc000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"

-- Expected output structure
M.expected_structure = [[
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
]]

-- Run test
function M.test_decode()
  -- This would need to be run inside Neovim
  local hexer = require('hexer')
  
  -- Create a buffer with the test calldata
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {M.test_calldata})
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_win_set_cursor(0, {1, 0})
  
  -- Run decode
  hexer.abi_decode()
  
  -- Get the result
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  
  -- Print for debugging
  print("=== ACTUAL OUTPUT ===")
  for _, line in ipairs(lines) do
    print(line)
  end
  print("=== END OUTPUT ===")
end

-- Simulated cast output for testing parser
M.simulated_cast_output = [[
1) "modifyAllocations(address,((address,uint32),address[],uint64[])[])"
0x7aBF46564cfd4d67E36DC8fB5DeF6a1162EBaF6b
[((0xcc3Bc3f5397e2b3c5D9869CD17566Ce88E47DceC, 0), [0x8b29d91e67b013e855EaFe0ad704aC4Ab086a574, 0x424246eF71b01ee33aA33aC590fd9a0855F5eFbc], [1, 1])]
]]

return M