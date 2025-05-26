local M = {}

-- Constants
local BYTES_PER_LINE = 32  -- 32 bytes = 64 hex characters
local CHARS_PER_BYTE = 2
local SELECTOR_LENGTH = 8  -- 4 bytes = 8 hex characters

-- Namespace for virtual text
local ns_id = vim.api.nvim_create_namespace("hexer")

-- trim string
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Validate hex string
local function validate_hex(input)
  -- Remove 0x prefix if present
  if input:sub(1, 2) == "0x" then
    input = input:sub(3)
  end
  
  -- Check if valid hex
  if not input:match("^[0-9a-fA-F]*$") then
    error("Invalid hex string: contains non-hex characters")
  end
  
  -- Check if even length
  if #input % 2 ~= 0 then
    error("Invalid hex string: odd number of characters")
  end
  
  return input
end

-- Function to insert lines above the current line in the buffer
local function insert_above(lines, config)
  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  
  -- Create undo group
  vim.cmd("undojoin")
  
  vim.api.nvim_buf_set_lines(0, cur_line - 1, cur_line - 1, false, lines)
  
  -- Apply highlights if configured
  if config and config.highlights then
    for i, line in ipairs(lines) do
      local line_num = cur_line - 1 + i - 1
      if line:match("^Selector:") then
        vim.api.nvim_buf_add_highlight(0, ns_id, config.highlights.selector, line_num, 0, -1)
      elseif line:match("//") then
        local offset_start = line:find("//")
        vim.api.nvim_buf_add_highlight(0, ns_id, config.highlights.offset, line_num, offset_start - 1, -1)
      end
    end
  end
end

-- Function to group characters in a string
local function group(str, size)
  local grouped = {}
  for i = 1, #str, size do
    table.insert(grouped, str:sub(i, i + size - 1))
  end
  return table.concat(grouped, " ")
end

-- Function to format the byte string
local function format_bytes(input, group_size, config)
  local line_length = BYTES_PER_LINE * CHARS_PER_BYTE
  
  -- Validate input length
  if #input % line_length ~= 0 then
    error(string.format("Input length must be a multiple of %d characters (32 bytes)", line_length))
  end

  local formatted = {}
  local offsetCounter = 0

  -- Loop through the string in chunks of 64 characters (32 bytes)
  for i = 1, #input, line_length do
    -- Extract a line worth of hex
    local hex = input:sub(i, i + line_length - 1)

    if hex ~= "" then
      -- Format hex with grouping
      local grouped_hex = group(hex, group_size)
      
      -- Add offset comment if configured
      if config.show_offset then
        local currentOffset = offsetCounter * BYTES_PER_LINE
        local comment = ""
        
        if config.offset_format == "hex" then
          comment = string.format(" // 0x%03x", currentOffset)
        elseif config.offset_format == "decimal" then
          comment = string.format(" // %03d", currentOffset)
        else -- both
          comment = string.format(" // 0x%03x (%03d)", currentOffset, currentOffset)
        end
        
        grouped_hex = grouped_hex .. comment
      end
      
      table.insert(formatted, grouped_hex)
      offsetCounter = offsetCounter + 1
    end
  end

  return formatted
end


-- Format calldata or returndata
M.format_data = function(input, group_size, config)
  -- Validate and clean input
  input = validate_hex(input)
  
  -- Apply case transformation if configured
  if config.uppercase then
    input = input:upper()
  else
    input = input:lower()
  end
  
  local lines = {}
  local data_part = input
  
  -- Check for function selector (4 bytes = 8 hex chars)
  if config.show_selector and #input % (BYTES_PER_LINE * CHARS_PER_BYTE) == SELECTOR_LENGTH then
    table.insert(lines, "Selector: 0x" .. input:sub(1, SELECTOR_LENGTH))
    data_part = input:sub(SELECTOR_LENGTH + 1)
  elseif #input > 0 then
    table.insert(lines, "Data:")
  end
  
  -- Format the data part
  if #data_part > 0 then
    local formatted_data = format_bytes(data_part, group_size, config)
    for _, line in ipairs(formatted_data) do
      table.insert(lines, line)
    end
  end
  
  -- Output based on method
  if config.output_method == "insert" then
    insert_above(lines, config)
  elseif config.output_method == "float" then
    -- TODO: Implement floating window output
    insert_above(lines, config)
  else
    -- TODO: Implement virtual text output
    insert_above(lines, config)
  end
end

M.convert_bytes_to_ascii = function(input_bytes, config)
  -- Validate hex input
  input_bytes = validate_hex(input_bytes)
  
  -- Remove spaces if present
  input_bytes = input_bytes:gsub("%s+", "")
  
  local result = {}
  local ascii_line = ""
  local hex_line = ""
  
  -- Convert hex to ASCII
  for i = 1, #input_bytes, 2 do
    local byte = input_bytes:sub(i, i + 1)
    local num = tonumber(byte, 16)
    
    if not num then
      error("Invalid hex byte: " .. byte)
    end
    
    -- Add to hex display
    hex_line = hex_line .. byte .. " "
    
    -- Convert to ASCII (printable characters only)
    if num >= 32 and num <= 126 then
      ascii_line = ascii_line .. string.char(num)
    else
      ascii_line = ascii_line .. "."
    end
    
    -- Break lines at reasonable length
    if #hex_line >= 48 then -- 16 bytes per line
      table.insert(result, hex_line .. "  |" .. ascii_line .. "|")
      hex_line = ""
      ascii_line = ""
    end
  end
  
  -- Add remaining bytes
  if #hex_line > 0 then
    -- Pad hex line to align ASCII
    while #hex_line < 48 do
      hex_line = hex_line .. "   "
    end
    table.insert(result, hex_line .. "  |" .. ascii_line .. "|")
  end
  
  -- Insert header
  table.insert(result, 1, "Hex to ASCII:")
  table.insert(result, 2, string.rep("-", 68))
  
  -- Output
  if config.output_method == "insert" then
    insert_above(result, config)
  else
    -- For now, fallback to insert
    insert_above(result, config)
  end
  
  -- Also notify with just the ASCII text
  local full_ascii = input_bytes:gsub("..", function(hex)
    local n = tonumber(hex, 16)
    return (n >= 32 and n <= 126) and string.char(n) or "."
  end)
  vim.notify("ASCII: " .. full_ascii, vim.log.levels.INFO)
end

return M
