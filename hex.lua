-- Create a module table to hold the exported functions
local M = {}

-- Helper function to remove leading and trailing whitespace from a string
local function trim(s)
  return s:match "^%s*(.-)%s*$"
end

-- insert lines above current line
local function insert_above(lines)
  -- Get the current line number
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  -- Insert the formatted byte strings into the buffer above the current line
  vim.api.nvim_buf_set_lines(0, cur_line - 1, cur_line - 1, false, lines)
end

local function group(str, size)
  size = size or 8
  local grouped = ""
  for i = 0, 56, size do
    grouped = grouped .. str:sub(i + 1, i + 8) .. " "
  end

  -- remove trailing space
  grouped = grouped:sub(1, -2)
  return grouped
end

-- Function to format the byte string
local function format_bytes(input)
  -- Initialize a table to hold the formatted byte strings
  local formatted = {}

  -- Check if the length of the input string is a multiple of 64
  if #input % 64 ~= 0 then
    return ""
  end

  -- Initialize a counter for the comments
  local offsetCounter = 0

  -- Loop through the string in chunks of 64 characters
  for i = 0, #input, 64 do
    -- Extract a 64-character substring
    local hex = input:sub(i + 1, i + 64)

    -- Check if the trimmed substring is not empty
    if (trim(hex) ~= "") then
      -- Create a comment string based on the counter
      local comment = string.format(" // 0x%02x", offsetCounter * 32)

      -- Increment the counter
      offsetCounter = offsetCounter + 1

      -- group hex into bytes of 8

      -- Add the formatted string to the table
      table.insert(formatted, group(hex) .. comment)
    end
  end

  insert_above(formatted)
end

-- Function to execute the formatting and print a success message
M.exec = function(input)
  local trimmed = ""
  local formatted = {}
  if #input % 64 == 10 then
    trimmed, formatted = input:sub(11), { input:sub(1, 10) }
    insert_above(formatted)
  end

  format_bytes(trimmed)
end

-- Return the module table
return M
