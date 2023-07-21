local M = {}
local api = require("hexer.api")

--[[
local function is_pow2(n)
  print("pow of 2" .. n)
  if n > 64 or n < 2 then
    return false
  end
  -- check if the number is a power of 2 by checking if its binary representation has exactly one '1'
  -- and by confirming that it is less than or equal to 64
    return n > 0 and ((n & (n - 1)) == 0)
end
--]]

M.format_calldata = function(group_size)
  -- EVM wordsize is 32-bytes (256-bits)
  -- You can group them in 2, 4, 8, 16, 32, or 64 characters. Note: 1 byte = 2 chars
  group_size = group_size or 64
  -- if not is_pow2(group_size) then
  --   group_size = 64
  -- end
  api.format_data(vim.fn.expand("<cword>"), group_size)
end

M.bytes_to_ascii = function()
  api.convert_bytes_to_ascii(vim.fn.expand("<cword>"))
end

return M
