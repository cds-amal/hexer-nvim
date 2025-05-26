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
  -- Try LPeg parser first (if available)
  local ok_lpeg, lpeg_parser = pcall(require, "hexer.solidity_parser_lpeg")
  if ok_lpeg then
    local parsed = lpeg_parser.parse_signature(function_sig)
    if parsed then
      self.function_info = parsed
      self.parameter_names = lpeg_parser.generate_parameter_names(parsed.parameters)
      -- Store additional type info for better formatting
      self.parameter_types = {}
      for i, param in ipairs(parsed.parameters) do
        self.parameter_types[i] = lpeg_parser.get_type_info(param)
      end
      return
    end
  end
  
  -- Fallback to manual parser
  local ok_manual, sol_parser = pcall(require, "hexer.solidity_parser")
  if ok_manual then
    local func_info = sol_parser.parse_signature(function_sig)
    if func_info then
      self.function_info = func_info
      self.parameter_names = sol_parser.generate_parameter_names(func_info.parameters)
      return
    end
  end
  
  -- Final fallback to simple regex-based parsing
  local params = function_sig:match("%((.+)%)$")
  if not params then return end
  
  local func_name = function_sig:match("^(%w+)")
  
  -- Simple extraction for common patterns
  if func_name == "modifyAllocations" and params:match("address%s*,%s*%(%(.+%)%[%]%)%[%]") then
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
    
  elseif value:match("^%[%(") then
    -- Array of tuples (like AllocationParams)
    -- Determine the name based on context
    local array_name = name or "AllocationParams"
    -- For modifyAllocations, the second parameter is typically allocationParams
    if name == "AllocationParams:" then
      array_name = "AllocationParams"
    end
    lines[1] = indent .. array_name .. ":" .. string.rep(" ", 50 - #indent - #array_name - 1) .. offset_str
    
    -- Parse array of complex tuples
    local inner = value:sub(2, -2)
    local tuples = {}
    local current = ""
    local depth = 0
    
    for i = 1, #inner do
      local char = inner:sub(i, i)
      if char == "(" then
        depth = depth + 1
        current = current .. char
      elseif char == ")" then
        depth = depth - 1
        current = current .. char
        if depth == 0 and i < #inner and inner:sub(i+1, i+1) == "," then
          table.insert(tuples, current)
          current = ""
          i = i + 1  -- Skip comma
          -- Skip optional space
          if i < #inner and inner:sub(i+1, i+1) == " " then
            i = i + 1
          end
        end
      elseif char ~= "" then
        current = current .. char
      end
    end
    
    -- Add last tuple if exists
    if current ~= "" then
      table.insert(tuples, current)
    end
    
    -- Parse each AllocationParam
    for i, tuple in ipairs(tuples) do
      if tuple:match("^%(%(.*%), %[.*%], %[.*%]%)$") then
        -- This looks like ((address,uint32), address[], uint64[])
        local inner_tuple = tuple:match("^%((.+)%)$")
        
        -- Extract the three main parts more carefully
        local parts = {}
        local part = ""
        local depth = 0
        local in_bracket = false
        
        for j = 1, #inner_tuple do
          local char = inner_tuple:sub(j, j)
          if char == "(" then
            depth = depth + 1
          elseif char == ")" then
            depth = depth - 1
          elseif char == "[" then
            in_bracket = true
          elseif char == "]" then
            in_bracket = false
          end
          
          if char == "," and depth == 0 and not in_bracket then
            table.insert(parts, trim(part))
            part = ""
            -- Skip space after comma
            if j < #inner_tuple and inner_tuple:sub(j+1, j+1) == " " then
              j = j + 1
            end
          else
            part = part .. char
          end
        end
        
        -- Add last part
        if part ~= "" then
          table.insert(parts, trim(part))
        end
        
        local item_indent = indent .. tree_chars.vert .. " "
        if i == #tuples then
          item_indent = indent .. tree_chars.empty .. " "
        end
        
        local prefix = i < #tuples and tree_chars.mid or tree_chars.last
        table.insert(lines, string.format("%s%sAllocationParams[%d]:", indent, prefix, i-1))
        
        -- Parse operatorSet (first part)
        if parts[1] and parts[1]:match("^%(.*%)$") then
          local op_parts = parts[1]:match("%((.+)%)")
          if op_parts then
            local op_values = self:split_by_delimiter(op_parts, ",", true)
            table.insert(lines, item_indent .. tree_chars.mid .. " operatorSet:")
            table.insert(lines, item_indent .. tree_chars.vert .. " " .. tree_chars.mid .. " avs: " .. trim(op_values[1] or ""))
            table.insert(lines, item_indent .. tree_chars.vert .. " " .. tree_chars.last .. " id:  " .. trim(op_values[2] or ""))
          end
        end
        
        -- Parse strategies (second part)
        if parts[2] and parts[2]:match("^%[.*%]$") then
          local strategies = parts[2]:match("%[(.*)%]")
          if strategies then
            local strat_list = self:split_by_delimiter(strategies, ",", false)
            table.insert(lines, item_indent .. tree_chars.mid .. " strategies:")
            for j, strat in ipairs(strat_list) do
              local strat_prefix = j < #strat_list and tree_chars.mid or tree_chars.last
              table.insert(lines, item_indent .. tree_chars.vert .. " " .. strat_prefix .. string.format(" [%d] %s", j-1, trim(strat)))
            end
          end
        end
        
        -- Parse magnitudes (third part)
        if parts[3] and parts[3]:match("^%[.*%]$") then
          local magnitudes = parts[3]:match("%[(.*)%]")
          if magnitudes then
            local mag_list = self:split_by_delimiter(magnitudes, ",", false)
            table.insert(lines, item_indent .. tree_chars.last .. " magnitudes:")
            for j, mag in ipairs(mag_list) do
              local mag_prefix = j < #mag_list and tree_chars.mid or tree_chars.last
              table.insert(lines, item_indent .. tree_chars.empty .. " " .. mag_prefix .. string.format(" [%d] %s", j-1, trim(mag)))
            end
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
  -- Remove the "1)" prefix if present (cast sometimes numbers multiple matches)
  function_sig = function_sig:gsub('^%d+%)%s*"?', ""):gsub('"$', "")
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
      local param_name = nil
      if parser.parameter_names and parser.parameter_names[i-1] then
        param_name = parser.parameter_names[i-1]
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
