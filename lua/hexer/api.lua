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

-- Tree drawing characters
local tree_chars = {
  mid = "├─",
  last = "└─",
  vert = "│ ",
  empty = "  "
}

-- Helper function to calculate offsets for structured output
local function calculate_offset(position)
  return string.format("@ 0x%03x", position)
end

-- Advanced parser for complex data structures
local ComplexParser = {}

function ComplexParser:new()
  local obj = {
    offset = 0,
    parameter_names = {}
  }
  setmetatable(obj, { __index = self })
  return obj
end

function ComplexParser:advance_offset(bytes)
  self.offset = self.offset + (bytes or 32)
end

-- Extract parameter names from function signature
function ComplexParser:extract_param_names(function_sig)
  -- Extract the parameter list from the function signature
  local params = function_sig:match("%((.+)%)$")
  if not params then return end
  
  -- Simple extraction of parameter names for common patterns
  if params:match("address%s*,%s*%(%(.+%)%[%]%)%[%]") then
    -- Pattern like: address, ((address,uint32), address[], uint64[])[]
    self.parameter_names = {"operator", "allocationParams"}
  elseif params:match("address%s*,%s*address") then
    self.parameter_names = {"from", "to"}
  end
end

-- Split complex data structures
function ComplexParser:split_by_delimiter(str, delimiter, respect_depth)
  local parts = {}
  local current = ""
  local depth = 0
  
  for i = 1, #str do
    local char = str:sub(i, i)
    if char == "(" or char == "[" then
      depth = depth + 1
    elseif char == ")" or char == "]" then
      depth = depth - 1
    elseif char == delimiter and (not respect_depth or depth == 0) then
      if current ~= "" then
        table.insert(parts, current:match("^%s*(.-)%s*$"))
        current = ""
      end
      goto continue
    end
    current = current .. char
    ::continue::
  end
  
  if current ~= "" then
    table.insert(parts, current:match("^%s*(.-)%s*$"))
  end
  
  return parts
end

-- Parse a single value with context
function ComplexParser:parse_value(value, indent, name)
  local lines = {}
  local offset_str = calculate_offset(self.offset)
  
  -- Handle different value types
  if value:match("^0x[0-9a-fA-F]+$") then
    -- Ethereum address
    local display_name = name and (name .. ":") or ""
    local padding = 50 - #indent - #display_name - #value
    lines[1] = string.format("%s%s%s%s%s", 
      indent, 
      display_name and (display_name .. " ") or "",
      value,
      string.rep(" ", math.max(1, padding)),
      offset_str
    )
    self:advance_offset()
    
  elseif value:match("^%d+$") then
    -- Number
    local display_name = name and (name .. ":") or ""
    lines[1] = string.format("%s%s %s", indent, display_name, value)
    self:advance_offset()
    
  elseif value:match("^%[%[.+%]%]$") then
    -- Array of arrays
    lines[1] = indent .. (name and (name .. ":") or "Arrays:") .. string.rep(" ", 50 - #indent - #name - 7) .. offset_str
    local inner = value:sub(2, -2)
    local arrays = self:split_by_delimiter(inner, "]", false)
    
    for i, arr in ipairs(arrays) do
      arr = arr:gsub("^%s*,%s*%[", "["):gsub("^%s*%[", "[")
      if arr ~= "" then
        local prefix = i < #arrays and tree_chars.mid or tree_chars.last
        local sub_lines = self:parse_value(arr, indent .. prefix .. " ", string.format("[%d]", i-1))
        for _, line in ipairs(sub_lines) do
          table.insert(lines, line)
        end
      end
    end
    
  elseif value:match("^%[.+%]$") then
    -- Simple array
    local inner = value:sub(2, -2)
    local items = self:split_by_delimiter(inner, ",", true)
    
    if #items > 0 and items[1]:match("^0x") then
      -- Array of addresses
      lines[1] = indent .. (name and (name .. ":") or "addresses:") .. string.rep(" ", 50 - #indent - #(name or "addresses") - 1) .. offset_str
      for i, item in ipairs(items) do
        local prefix = i < #items and tree_chars.mid or tree_chars.last
        local sub_indent = indent .. tree_chars.vert .. " "
        if i == #items then
          sub_indent = indent .. tree_chars.empty .. " "
        end
        table.insert(lines, string.format("%s%s [%d] %s", indent, prefix, i-1, item))
        self:advance_offset()
      end
    else
      -- Array of numbers or other values
      lines[1] = indent .. (name and (name .. ":") or "values:") .. string.rep(" ", 50 - #indent - #(name or "values") - 1) .. offset_str
      for i, item in ipairs(items) do
        local prefix = i < #items and tree_chars.mid or tree_chars.last
        table.insert(lines, string.format("%s%s [%d] %s", indent, prefix, i-1, item))
        self:advance_offset()
      end
    end
    
  elseif value:match("^%((.+)%)$") then
    -- Tuple
    local inner = value:match("^%((.+)%)$")
    local parts = self:split_by_delimiter(inner, ",", true)
    
    -- Special handling for common tuple patterns
    if #parts == 2 and parts[1]:match("^0x") and parts[2]:match("^%d+$") then
      -- (address, uint) pattern - likely operatorSet
      lines[1] = indent .. "operatorSet:" .. string.rep(" ", 50 - #indent - 12) .. offset_str
      table.insert(lines, indent .. tree_chars.mid .. " avs: " .. parts[1])
      table.insert(lines, indent .. tree_chars.last .. " id:  " .. parts[2])
      self:advance_offset(2)
    else
      -- Generic tuple
      lines[1] = indent .. (name and (name .. ":") or "tuple:")
      for i, part in ipairs(parts) do
        local prefix = i < #parts and tree_chars.mid or tree_chars.last
        local sub_lines = self:parse_value(part, indent .. prefix .. " ")
        for _, line in ipairs(sub_lines) do
          table.insert(lines, line)
        end
      end
    end
    
  elseif value:match("^%[%((.+)%)%]$") then
    -- Array of tuples (like AllocationParams)
    lines[1] = indent .. (name and (name .. ":") or "AllocationParams:") .. string.rep(" ", 50 - #indent - #(name or "AllocationParams") - 1) .. offset_str
    
    -- Parse array of complex tuples
    local inner = value:sub(2, -2)
    local tuples = {}
    local current = ""
    local depth = 0
    
    for i = 1, #inner do
      local char = inner:sub(i, i)
      if char == "(" then
        depth = depth + 1
      elseif char == ")" then
        depth = depth - 1
        current = current .. char
        if depth == 0 then
          table.insert(tuples, current)
          current = ""
          -- Skip comma and space
          if i < #inner and inner:sub(i+1, i+2) == ", " then
            i = i + 2
          end
        end
        goto continue
      end
      current = current .. char
      ::continue::
    end
    
    -- Parse each AllocationParam
    for i, tuple in ipairs(tuples) do
      if tuple:match("^%(%(.*%), %[.*%], %[.*%]%)$") then
        -- This looks like ((address,uint32), address[], uint64[])
        local parts = {}
        local inner_tuple = tuple:match("^%((.+)%)$")
        
        -- Extract the three main parts
        local operatorSet = inner_tuple:match("^(%(.-%))") 
        local remaining = inner_tuple:sub(#operatorSet + 3) -- Skip ", "
        local addresses_end = remaining:find("%], ")
        local strategies = remaining:sub(2, addresses_end - 1) -- Skip "["
        local magnitudes = remaining:match("%[([^%]]+)%]$")
        
        local item_indent = indent .. tree_chars.vert .. " "
        if i == #tuples then
          item_indent = indent .. tree_chars.empty .. " "
        end
        
        local prefix = i < #tuples and tree_chars.mid or tree_chars.last
        table.insert(lines, string.format("%sAllocationParams[%d]:", indent .. prefix .. " ", i-1))
        
        -- Parse operatorSet
        local op_parts = operatorSet:match("%((.+)%)")
        if op_parts then
          local op_values = self:split_by_delimiter(op_parts, ",", true)
          table.insert(lines, item_indent .. tree_chars.mid .. " operatorSet.avs: " .. (op_values[1] or ""))
          table.insert(lines, item_indent .. tree_chars.mid .. " operatorSet.id:  " .. (op_values[2] or ""))
        end
        
        -- Parse strategies
        if strategies then
          local strat_list = self:split_by_delimiter(strategies, ",", false)
          table.insert(lines, item_indent .. tree_chars.mid .. " strategies:")
          for j, strat in ipairs(strat_list) do
            local strat_prefix = j < #strat_list and tree_chars.mid or tree_chars.last
            table.insert(lines, item_indent .. tree_chars.vert .. " " .. strat_prefix .. string.format(" [%d] %s", j-1, strat))
          end
        end
        
        -- Parse magnitudes
        if magnitudes then
          local mag_list = self:split_by_delimiter(magnitudes, ",", false)
          table.insert(lines, item_indent .. tree_chars.last .. " magnitudes:")
          for j, mag in ipairs(mag_list) do
            local mag_prefix = j < #mag_list and tree_chars.mid or tree_chars.last
            table.insert(lines, item_indent .. tree_chars.empty .. " " .. mag_prefix .. string.format(" [%d] %s", j-1, mag))
          end
        end
      else
        -- Generic tuple in array
        local prefix = i < #tuples and tree_chars.mid or tree_chars.last
        local sub_lines = self:parse_value(tuple, indent .. prefix .. " ", string.format("[%d]", i-1))
        for _, line in ipairs(sub_lines) do
          table.insert(lines, line)
        end
      end
    end
    
  else
    -- Unknown format, display as-is
    lines[1] = indent .. (name and (name .. ": ") or "") .. value
  end
  
  return lines
end

-- Main formatting function
local function format_decoded_output(lines, input_calldata)
  local result = {}
  local parser = ComplexParser:new()
  
  -- Extract function signature and parameter names
  local function_sig = lines[1] or ""
  parser:extract_param_names(function_sig)
  
  table.insert(result, "Function: " .. function_sig)
  table.insert(result, "")
  table.insert(result, "Calldata: 0x" .. input_calldata:sub(1, 10) .. "...")
  table.insert(result, "")
  
  -- Parse arguments
  for i = 2, #lines do
    local line = lines[i]
    if line and line ~= "" then
      line = line:gsub("^%s+", ""):gsub("%s+$", "")
      
      -- Determine parameter name
      local param_name = parser.parameter_names[i-1]
      if param_name then
        param_name = param_name:sub(1, 1):upper() .. param_name:sub(2) .. ":"
      end
      
      -- Parse the value
      local parsed_lines = parser:parse_value(line, "", param_name)
      for _, parsed_line in ipairs(parsed_lines) do
        table.insert(result, parsed_line)
      end
      
      -- Add spacing between major parameters
      if i < #lines then
        table.insert(result, "")
      end
    end
  end
  
  return result
end

-- ABI decode using Foundry's cast command
M.abi_decode = function(input_calldata, config)
  -- Validate hex input
  input_calldata = validate_hex(input_calldata)
  
  -- Store original for display
  local display_calldata = input_calldata
  
  -- Ensure calldata starts with 0x
  if not input_calldata:match("^0x") then
    input_calldata = "0x" .. input_calldata
  else
    display_calldata = input_calldata:sub(3) -- Remove 0x for display
  end
  
  -- Check if cast is available
  local cast_check = vim.fn.system("which cast")
  if vim.v.shell_error ~= 0 then
    error("Foundry's 'cast' command not found. Please install Foundry: https://getfoundry.sh/")
  end
  
  -- Run cast 4byte-decode
  local cmd = string.format("cast 4byte-decode %s", vim.fn.shellescape(input_calldata))
  local output = vim.fn.system(cmd)
  
  if vim.v.shell_error ~= 0 then
    error("Failed to decode calldata: " .. output)
  end
  
  -- Parse the output
  local lines = vim.split(output, "\n", { plain = true, trimempty = true })
  if #lines == 0 then
    error("No output from cast 4byte-decode")
  end
  
  -- Format with tree structure
  local result = format_decoded_output(lines, display_calldata)
  
  -- Add header and footer
  table.insert(result, 1, "ABI Decoded Calldata")
  table.insert(result, 2, string.rep("─", 70))
  table.insert(result, string.rep("─", 70))
  
  -- Output based on method
  if config.output_method == "insert" then
    insert_above(result, config)
  elseif config.output_method == "float" then
    -- TODO: Implement floating window
    insert_above(result, config)
  else
    insert_above(result, config)
  end
  
  -- Also show a notification with the function signature
  if lines[1] then
    vim.notify("Decoded: " .. lines[1], vim.log.levels.INFO)
  end
end

return M
