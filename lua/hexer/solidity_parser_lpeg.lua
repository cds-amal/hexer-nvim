-- Solidity function signature parser using LPeg
-- Parses canonical function signatures used for selector generation

local M = {}

-- Check if LPeg is available
local has_lpeg, lpeg = pcall(require, "lpeg")
if not has_lpeg then
  return M  -- Return empty module if LPeg not available
end

local P, R, S, V, C, Ct, Cg, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg, lpeg.Cc

-- Basic elements
local space = S(" \t\n")^0
local alpha = R("az", "AZ") + P("_")
local digit = R("09")
local alphanum = alpha + digit

-- Solidity type identifiers
local ident = C(alpha * alphanum^0)

-- Array dimensions
local array_dim = P("[") * C(digit^0) * P("]")
local array_suffix = Ct(array_dim^1)

-- Grammar definition
local grammar = P{
  "FunctionSig",

  -- Function signature: name(type1, type2, ...)
  FunctionSig = Ct(
    Cg(ident, "name") *
    space * P("(") * space *
    Cg(V("TypeList"), "parameters") *
    space * P(")")
  ),

  -- Type list (comma-separated, can be empty)
  TypeList = Ct(
    (V("Type") * (space * P(",") * space * V("Type"))^0)^-1
  ),

  -- A single type (base type, array, or tuple)
  Type = space * V("ArrayType") * space,

  -- Array type (base or tuple with array suffix)
  ArrayType = V("BaseType") * (
    array_suffix / function(dims)
      return function(base)
        return {
          type = "array",
          base = base,
          dimensions = dims,
          is_array = true,
          is_dynamic = #dims > 0 and dims[1] == ""
        }
      end
    end
  )^0 / function(base, ...)
    local transforms = {...}
    for i = #transforms, 1, -1 do
      base = transforms[i](base)
    end
    return base
  end,

  -- Base type (identifier or tuple)
  BaseType = V("Tuple") + V("SimpleType"),

  -- Simple type (just an identifier)
  SimpleType = ident / function(name)
    return {
      type = "basic",
      name = name,
      is_array = false,
      is_tuple = false
    }
  end,

  -- Tuple type: (type1, type2, ...)
  Tuple = P("(") * space * V("TypeList") * space * P(")") / function(types)
    return {
      type = "tuple",
      elements = types,
      is_tuple = true,
      is_array = false
    }
  end,
}

-- Parse a function signature
function M.parse_signature(signature)
  if not has_lpeg then
    return nil, "LPeg not available"
  end

  local result = grammar:match(signature)
  if not result then
    return nil, "Failed to parse signature"
  end

  return result
end

-- Generate human-readable parameter names
function M.generate_parameter_names(parameters)
  local names = {}

  for i, param in ipairs(parameters) do
    local name = M.generate_name_for_type(param, i, parameters)
    table.insert(names, name)
  end

  -- Special cases for known function patterns
  if #parameters == 2 then
    local p1, p2 = parameters[1], parameters[2]

    -- modifyAllocations pattern
    if p1.type == "basic" and p1.name == "address" and
       p2.type == "array" and p2.base.type == "tuple" then
      names[1] = "operator"
      names[2] = "allocationParams"
    end

    -- transfer pattern
    elseif p1.type == "basic" and p1.name == "address" and
           p2.type == "basic" and p2.name:match("^uint") then
      names[1] = "recipient"
      names[2] = "amount"
    end
  end

  return names
end

-- Generate a name for a specific type
function M.generate_name_for_type(param, index, all_params)
  if param.type == "basic" then
    if param.name == "address" then
      -- First address in a 2-param function is often operator/sender/recipient
      if index == 1 and #all_params == 2 then
        return "account"
      else
        return "address" .. index
      end
    elseif param.name:match("^uint") then
      return "amount" .. index
    elseif param.name == "bool" then
      return "flag" .. index
    elseif param.name == "bytes32" then
      return "hash" .. index
    elseif param.name == "string" then
      return "text" .. index
    elseif param.name:match("^bytes") then
      return "data" .. index
    else
      return "param" .. index
    end

  elseif param.type == "array" then
    local base_name = M.generate_name_for_type(param.base, index, all_params)
    -- Special handling for allocation params pattern
    if param.base.type == "tuple" and M.is_allocation_param_tuple(param.base) then
      return "params"
    end
    return base_name .. "Array"

  elseif param.type == "tuple" then
    if M.is_operator_set_tuple(param) then
      return "operatorSet"
    elseif M.is_allocation_param_tuple(param) then
      return "allocation"
    else
      return "data" .. index
    end
  else
    return "param" .. index
  end
end

-- Check if tuple matches (address,uint32) pattern
function M.is_operator_set_tuple(param)
  if param.type ~= "tuple" or #param.elements ~= 2 then
    return false
  end

  local e1, e2 = param.elements[1], param.elements[2]
  return e1.type == "basic" and e1.name == "address" and
         e2.type == "basic" and e2.name == "uint32"
end

-- Check if tuple matches allocation param pattern
function M.is_allocation_param_tuple(param)
  if param.type ~= "tuple" or #param.elements ~= 3 then
    return false
  end

  local e1, e2, e3 = param.elements[1], param.elements[2], param.elements[3]

  -- Pattern: (operatorSet, address[], uint64[])
  return M.is_operator_set_tuple(e1) and
         e2.type == "array" and e2.base.type == "basic" and e2.base.name == "address" and
         e3.type == "array" and e3.base.type == "basic" and e3.base.name == "uint64"
end

-- Format a type for display
function M.format_type(param)
  if param.type == "basic" then
    return param.name

  elseif param.type == "array" then
    local base = M.format_type(param.base)
    local suffix = ""
    for _, dim in ipairs(param.dimensions) do
      suffix = suffix .. "[" .. dim .. "]"
    end
    return base .. suffix

  elseif param.type == "tuple" then
    local elements = {}
    for _, elem in ipairs(param.elements) do
      table.insert(elements, M.format_type(elem))
    end
    return "(" .. table.concat(elements, ",") .. ")"
  else
    return "unknown"
  end
end

-- Get type info for better formatting
function M.get_type_info(param)
  local info = {
    raw_type = M.format_type(param),
    is_array = param.is_array or false,
    is_tuple = param.is_tuple or false,
    is_dynamic_array = false,
    array_dimensions = {}
  }

  if param.type == "array" then
    info.is_dynamic_array = param.is_dynamic
    for _, dim in ipairs(param.dimensions) do
      table.insert(info.array_dimensions, dim == "" and "dynamic" or tonumber(dim))
    end

    -- Get base type info
    if param.base.type == "tuple" then
      info.tuple_info = M.get_type_info(param.base)
    end
  elseif param.type == "tuple" then
    info.tuple_elements = {}
    for _, elem in ipairs(param.elements) do
      table.insert(info.tuple_elements, M.get_type_info(elem))
    end
  end

  return info
end

return M
