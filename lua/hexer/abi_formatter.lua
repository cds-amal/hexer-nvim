-- ABI-aware formatter for decoded calldata
local M = {}

local tree_chars = {
  mid = "├─",
  last = "└─",
  vert = "│ ",
  empty = "  "
}

-- Format decoded data with ABI information
function M.format_with_abi(decoded_lines, function_sig, calldata)
  -- Validate inputs
  if not decoded_lines or #decoded_lines < 1 then
    return nil
  end
  
  if not function_sig or function_sig == "" then
    return nil
  end
  
  -- Safely load abi_lookup
  local ok, abi_lookup = pcall(require, "hexer.abi_lookup")
  if not ok then
    return nil
  end
  
  -- Extract function name
  local func_name = function_sig:match("^(%w+)")
  if not func_name then
    return nil
  end
  
  -- Try to find ABI
  local abi_func, contract_name = abi_lookup.find_function_abi(func_name)
  if not abi_func then
    return nil
  end
  
  -- Extract parameter structure
  local param_structure = abi_lookup.extract_param_structure(abi_func)
  if not param_structure then
    return nil
  end
  
  -- Format the output with proper names
  local result = {}
  table.insert(result, "ABI Decoded Calldata")
  table.insert(result, string.rep("─", 70))
  table.insert(result, "Function: " .. function_sig)
  if contract_name then
    table.insert(result, "Contract: " .. contract_name)
  end
  table.insert(result, "")
  table.insert(result, "Calldata: 0x" .. calldata:sub(1, 10) .. "...")
  table.insert(result, "")
  
  -- Format each parameter
  local offset = 0
  for i = 2, #decoded_lines do
    local decoded_value = decoded_lines[i]
    if decoded_value and decoded_value ~= "" then
      local param = param_structure[i-1]
      if param then
        local formatted = M.format_parameter(param, decoded_value, "", offset)
        for _, line in ipairs(formatted) do
          table.insert(result, line)
        end
        table.insert(result, "")
      end
    end
  end
  
  table.insert(result, string.rep("─", 70))
  return result
end

-- Format a single parameter with its value
function M.format_parameter(param, value, indent, offset)
  local lines = {}
  
  -- Clean up the value
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  
  -- Handle different parameter types
  if param.type == "address" then
    -- Simple address
    table.insert(lines, string.format("%s%s:",
      indent, param.name:sub(1,1):upper() .. param.name:sub(2)))
    table.insert(lines, string.format("%s  └─ %s%s@ 0x%03x",
      indent, value:lower(),
      string.rep(" ", math.max(1, 50 - #indent - #value - 5)),
      offset))
      
  elseif param.type:match("^tuple%[%]") and param.internal_type:match("struct") then
    -- Array of structs (like AllocateParams[])
    local struct_name = param.internal_type:match("struct%s+(%w+)%[%]")
    table.insert(lines, string.format("%s%s:%s@ 0x%03x",
      indent, param.name:sub(1,1):upper() .. param.name:sub(2),
      string.rep(" ", 50 - #indent - #param.name - 1),
      offset + 0x20))
    
    -- Parse the array value
    if value:match("^%[") then
      local formatted_items = M.format_struct_array(param, value, indent, offset + 0x20)
      for _, line in ipairs(formatted_items) do
        table.insert(lines, line)
      end
    end
    
  elseif param.type == "tuple" and param.internal_type:match("struct") then
    -- Single struct
    local struct_name = param.internal_type:match("struct%s+(%w+)")
    table.insert(lines, string.format("%s%s (%s):",
      indent, param.name, struct_name or "struct"))
    
    -- Format the struct using the same logic as struct items
    if param.components and #param.components > 0 then
      local struct_lines = M.format_struct_item(param.components, value, indent .. "  ", offset)
      for _, line in ipairs(struct_lines) do
        table.insert(lines, line)
      end
    end
    
  else
    -- Other types
    table.insert(lines, string.format("%s%s: %s",
      indent, param.name, value))
  end
  
  return lines
end

-- Format an array of structs
function M.format_struct_array(param, value, indent, offset)
  local lines = {}
  
  -- Remove outer brackets and parse items
  local inner = value:sub(2, -2)
  local items = M.parse_array_items(inner)
  
  for idx, item in ipairs(items) do
    -- Add spacing between items
    if idx > 1 then
      table.insert(lines, "")
    end
    
    -- Format array index
    table.insert(lines, string.format("%s[%d]:%s@ 0x%03x",
      indent, idx-1,
      string.rep(" ", 50 - #indent - #string.format("[%d]:", idx-1)),
      offset + (idx-1) * 0xe0))
    
    -- Format struct fields
    if #param.components > 0 then
      local item_lines = M.format_struct_item(param.components, item, indent .. "  ", offset + (idx-1) * 0xe0)
      for _, line in ipairs(item_lines) do
        table.insert(lines, line)
      end
    end
  end
  
  return lines
end

-- Format a single struct item based on components
function M.format_struct_item(components, value, indent, offset)
  local lines = {}
  
  -- Parse the tuple value
  local values = M.parse_tuple_values(value)
  
  for i, component in ipairs(components) do
    local comp_value = values[i]
    if comp_value then
      if component.type == "tuple" and component.internal_type:match("OperatorSet") then
        -- OperatorSet struct
        local op_values = M.parse_tuple_values(comp_value)
        table.insert(lines, indent .. tree_chars.mid .. " " .. component.name .. ":")
        if op_values[1] then
          table.insert(lines, indent .. tree_chars.vert .. "   " .. tree_chars.mid .. 
            " avs: " .. op_values[1]:lower())
        end
        if op_values[2] then
          table.insert(lines, indent .. tree_chars.vert .. "   " .. tree_chars.last .. 
            " id:  " .. op_values[2])
        end
        
      elseif component.type:match("%[%]$") then
        -- Array field
        local array_values = M.parse_array_values(comp_value)
        local field_offset = offset + (i-1) * 0x80
        
        table.insert(lines, string.format("%s%s %s:%s@ 0x%03x",
          indent, 
          i < #components and tree_chars.mid or tree_chars.last,
          component.name,
          string.rep(" ", 50 - #indent - #component.name - 2),
          field_offset))
        
        for j, arr_val in ipairs(array_values) do
          local prefix = j < #array_values and tree_chars.mid or tree_chars.last
          local vert = i < #components and tree_chars.vert or tree_chars.empty
          table.insert(lines, indent .. vert .. "   " .. prefix .. 
            string.format(" [%d] %s", j-1, arr_val:lower()))
        end
        
      else
        -- Simple field
        table.insert(lines, string.format("%s%s %s: %s",
          indent,
          i < #components and tree_chars.mid or tree_chars.last,
          component.name,
          comp_value))
      end
    end
  end
  
  return lines
end

-- Parse array items from string representation
function M.parse_array_items(str)
  local items = {}
  local current = ""
  local depth = 0
  
  for i = 1, #str do
    local char = str:sub(i, i)
    if char == "(" then
      depth = depth + 1
    elseif char == ")" then
      depth = depth - 1
    end
    
    current = current .. char
    
    if depth == 0 and current:match("%)$") then
      table.insert(items, current)
      current = ""
      -- Skip comma and space
      while i < #str and str:sub(i+1, i+1):match("[, ]") do
        i = i + 1
      end
    end
  end
  
  return items
end

-- Parse tuple values
function M.parse_tuple_values(tuple_str)
  if not tuple_str:match("^%(") then
    return {tuple_str}
  end
  
  local inner = tuple_str:match("^%((.*)%)$") or tuple_str
  local values = {}
  local current = ""
  local depth = 0
  local in_brackets = 0
  
  for i = 1, #inner do
    local char = inner:sub(i, i)
    
    if char == "(" then
      depth = depth + 1
    elseif char == ")" then
      depth = depth - 1
    elseif char == "[" then
      in_brackets = in_brackets + 1
    elseif char == "]" then
      in_brackets = in_brackets - 1
    end
    
    if char == "," and depth == 0 and in_brackets == 0 then
      table.insert(values, current:match("^%s*(.-)%s*$"))
      current = ""
    else
      current = current .. char
    end
  end
  
  if current ~= "" then
    table.insert(values, current:match("^%s*(.-)%s*$"))
  end
  
  return values
end

-- Parse array values
function M.parse_array_values(array_str)
  if not array_str:match("^%[") then
    return {}
  end
  
  local inner = array_str:match("^%[(.*)%]$") or ""
  local values = {}
  
  -- Handle simple arrays (addresses, numbers)
  for value in inner:gmatch("[^,]+") do
    table.insert(values, value:match("^%s*(.-)%s*$"))
  end
  
  return values
end

return M