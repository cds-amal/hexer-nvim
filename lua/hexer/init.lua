local M = {}

-- trim string
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Function to insert lines above the current line in the buffer
local function insert_above(lines)
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, cur_line - 1, cur_line - 1, false, lines)
end

-- Function to group characters in a string
local function group(str, size)
  size = size or 8
  local grouped = ""
  for i = 0, 56, size do
    grouped = grouped .. str:sub(i + 1, i + size) .. " "
  end

  -- Remove trailing space
  grouped = grouped:sub(1, -2)
  return grouped
end

-- Function to format the byte string
local function format_bytes(input)
  -- Guard input length is a multiple of 64
  if #input % 64 ~= 0 then
    return ""
  end

  local formatted = {}
  local offsetCounter = 0

  -- Loop through the string in chunks of 64 characters
  for i = 0, #input, 64 do
    -- Extract a 64-character substring
    local hex = input:sub(i + 1, i + 64)

    if trim(hex) ~= "" then
      -- Add offset
      local currentOffset = offsetCounter * 32
      local comment = string.format(" // 0x%03x (%03d)", currentOffset, currentOffset)
      offsetCounter = offsetCounter + 1
      table.insert(formatted, group(hex) .. comment)
    end
  end

  insert_above(formatted)
end

-- Function to execute the formatting
M.exec = function(input)
  local trimmed = ""
  local formatted = {}

  -- If the input length modulo 64 (chars) is 10, split the input into a formatted
  -- and a trimmed part. For example a function selector 0xc6eb23d0 followed by
  -- multiples of 64 char data, implies a selector followed by data:
  -- [0x + 8]        + data
  --   1 + 5 bytes   + word multiples of 32 bytes, or 64 chars.
  --
  if #input % 64 == 10 then
    trimmed, formatted = input:sub(11), { input:sub(1, 10) }
    insert_above(formatted)
  end

  format_bytes(trimmed)
end

M.convert_bytes_to_ascii = function(input_bytes)
  local res = ""
  local i = 1
  while i <= string.len(input_bytes) do
    while string.sub(input_bytes, i, i) == " " do
      i = i + 1
    end
    res = res .. string.char(tonumber(string.sub(input_bytes, i, i + 1), 16))
    i = i + 2
  end
  print(res)
  insert_above({ res })
end


return M
