-- Solidity function signature parser
-- Parses canonical function signatures used for selector generation
-- Format: functionName(type1,type2,(tuple1,tuple2),type3[])
--
-- These signatures contain only types (no parameter names) and are what
-- gets hashed with keccak256 to generate 4-byte function selectors.
-- Complex types (structs) are represented as tuples in canonical form.
--
-- Examples:
--   transfer(address,uint256)
--   modifyAllocations(address,((address,uint32),address[],uint64[])[])

local M = {}

-- Parse a Solidity function signature
function M.parse_signature(signature)
  -- Extract function name and parameter list
  local func_name, params = signature:match("^([%w_]+)%((.*)%)$")
  if not func_name then
    return nil
  end
  
  local result = {
    name = func_name,
    parameters = M.parse_parameter_list(params)
  }
  
  return result
end

-- Parse a comma-separated parameter list, handling nested tuples
function M.parse_parameter_list(params_str)
  if not params_str or params_str == "" then
    return {}
  end
  
  local parameters = {}
  local current = ""
  local depth = 0
  
  for i = 1, #params_str do
    local char = params_str:sub(i, i)
    
    if char == "(" then
      depth = depth + 1
      current = current .. char
    elseif char == ")" then
      depth = depth - 1
      current = current .. char
    elseif char == "," and depth == 0 then
      -- Top-level comma, parameter boundary
      if current ~= "" then
        table.insert(parameters, M.parse_type(current))
        current = ""
      end
    else
      current = current .. char
    end
  end
  
  -- Don't forget the last parameter
  if current ~= "" then
    table.insert(parameters, M.parse_type(current))
  end
  
  return parameters
end

-- Parse a single type (could be basic, array, or tuple)
function M.parse_type(type_str)
  type_str = type_str:match("^%s*(.-)%s*$") -- trim whitespace
  
  local type_info = {
    raw = type_str,
    base_type = nil,
    is_array = false,
    is_dynamic_array = false,
    array_size = nil,
    is_tuple = false,
    tuple_elements = nil
  }
  
  -- Check if it's a tuple
  if type_str:match("^%(") then
    type_info.is_tuple = true
    -- Extract tuple contents
    local tuple_contents = type_str:match("^%((.*)%)(.*)$")
    type_info.tuple_elements = M.parse_parameter_list(tuple_contents)
    
    -- Check for array suffix after tuple
    local suffix = type_str:match("%)(.*)$")
    if suffix and suffix:match("%[") then
      type_info.is_array = true
      local array_size = suffix:match("%[(%d*)%]")
      if array_size == "" then
        type_info.is_dynamic_array = true
      else
        type_info.array_size = tonumber(array_size)
      end
    end
  else
    -- Not a tuple, check for array
    local base, array_part = type_str:match("^([^%[]+)(.*)$")
    type_info.base_type = base
    
    if array_part and array_part ~= "" then
      type_info.is_array = true
      -- Could be multiple dimensions: uint256[][]
      local dimensions = {}
      for size in array_part:gmatch("%[(%d*)%]") do
        if size == "" then
          table.insert(dimensions, "dynamic")
        else
          table.insert(dimensions, tonumber(size))
        end
      end
      
      if #dimensions == 1 then
        if dimensions[1] == "dynamic" then
          type_info.is_dynamic_array = true
        else
          type_info.array_size = dimensions[1]
        end
      else
        -- Multi-dimensional array
        type_info.dimensions = dimensions
      end
    end
  end
  
  return type_info
end

-- Generate human-readable names for parameters based on type and position
function M.generate_parameter_names(parameters)
  local names = {}
  
  for i, param in ipairs(parameters) do
    local name = ""
    
    if param.base_type == "address" then
      if i == 1 then
        name = "account"
      else
        name = "address" .. i
      end
    elseif param.base_type and param.base_type:match("uint") then
      name = "amount" .. i
    elseif param.base_type == "bool" then
      name = "flag" .. i
    elseif param.base_type == "bytes32" then
      name = "hash" .. i
    elseif param.base_type == "string" then
      name = "text" .. i
    elseif param.is_tuple then
      -- Check tuple contents for patterns
      if M.is_operator_set_tuple(param) then
        name = "operatorSet"
      elseif M.is_allocation_params(param) then
        name = "params"
      else
        name = "data" .. i
      end
      
      if param.is_array then
        name = name .. "Array"
      end
    else
      name = "param" .. i
    end
    
    table.insert(names, name)
  end
  
  -- Special case: modifyAllocations pattern
  if #parameters == 2 and parameters[1].base_type == "address" and 
     parameters[2].is_array and parameters[2].is_tuple then
    names[1] = "operator"
    names[2] = "allocationParams"
  end
  
  return names
end

-- Check if a tuple matches the (address,uint32) pattern (operatorSet)
function M.is_operator_set_tuple(param)
  if not param.is_tuple or not param.tuple_elements then
    return false
  end
  
  return #param.tuple_elements == 2 and
         param.tuple_elements[1].base_type == "address" and
         param.tuple_elements[2].base_type == "uint32"
end

-- Check if a tuple matches allocation params pattern
function M.is_allocation_params(param)
  if not param.is_tuple or not param.tuple_elements then
    return false
  end
  
  -- Pattern: ((address,uint32), address[], uint64[])
  return #param.tuple_elements == 3 and
         param.tuple_elements[1].is_tuple and
         M.is_operator_set_tuple(param.tuple_elements[1]) and
         param.tuple_elements[2].is_array and
         param.tuple_elements[2].base_type == "address" and
         param.tuple_elements[3].is_array and
         param.tuple_elements[3].base_type == "uint64"
end

-- Format type info for display
function M.format_type(type_info)
  if type_info.is_tuple then
    local elements = {}
    for _, elem in ipairs(type_info.tuple_elements) do
      table.insert(elements, M.format_type(elem))
    end
    local tuple_str = "(" .. table.concat(elements, ", ") .. ")"
    
    if type_info.is_array then
      if type_info.is_dynamic_array then
        return tuple_str .. "[]"
      else
        return tuple_str .. "[" .. type_info.array_size .. "]"
      end
    end
    return tuple_str
  else
    local str = type_info.base_type or "unknown"
    if type_info.is_array then
      if type_info.dimensions then
        for _, dim in ipairs(type_info.dimensions) do
          str = str .. "[" .. (dim == "dynamic" and "" or dim) .. "]"
        end
      elseif type_info.is_dynamic_array then
        str = str .. "[]"
      else
        str = str .. "[" .. type_info.array_size .. "]"
      end
    end
    return str
  end
end

return M