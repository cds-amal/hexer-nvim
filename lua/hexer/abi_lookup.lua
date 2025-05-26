-- ABI lookup functionality for better decoding
local M = {}

-- Use persistent cache
local cache = require("hexer.cache")

-- Find contract files containing a function
function M.find_contracts_with_function(func_name)
  local contracts = {}
  
  -- Use ripgrep to find function definitions
  local cmd = string.format("rg '%s' -l --type-add 'sol:*.sol' -t sol", func_name)
  local output = vim.fn.system(cmd)
  
  if vim.v.shell_error == 0 and output ~= "" then
    for line in output:gmatch("[^\n]+") do
      if line:match("%.sol$") then
        -- Extract contract name from path
        local contract = line:match("([^/]+)%.sol$")
        if contract then
          table.insert(contracts, {
            path = line,
            name = contract
          })
        end
      end
    end
  end
  
  return contracts
end

-- Get ABI for a specific function from a contract
function M.get_function_abi(contract_name, func_name)
  -- Check persistent cache first
  local cached_abi = cache.get_abi(func_name, contract_name)
  if cached_abi then
    return cached_abi
  end
  
  -- Use forge to get ABI
  local cmd = string.format(
    "forge inspect %s abi --json 2>/dev/null | jq '.[] | select(.name == \"%s\")'",
    contract_name, func_name
  )
  
  local output = vim.fn.system(cmd)
  
  if vim.v.shell_error == 0 and output ~= "" then
    -- Parse JSON output
    local ok, abi = pcall(vim.json.decode, output)
    if ok and abi then
      -- Save to persistent cache
      cache.set_abi(func_name, contract_name, abi)
      return abi
    end
  end
  
  -- Try alternative: look for the contract in out/ or artifacts/
  local alt_cmd = string.format(
    "find . -name '%s.json' -path '*/out/*' -o -path '*/artifacts/*' | head -1",
    contract_name
  )
  local contract_path = vim.fn.system(alt_cmd):gsub("\n", "")
  
  if contract_path ~= "" then
    local jq_cmd = string.format(
      "jq '.abi[] | select(.name == \"%s\")' %s 2>/dev/null",
      func_name, contract_path
    )
    output = vim.fn.system(jq_cmd)
    if vim.v.shell_error == 0 and output ~= "" then
      local ok, abi = pcall(vim.json.decode, output)
      if ok and abi then
        cache.set_abi(func_name, contract_name, abi)
        return abi
      end
    end
  end
  
  return nil
end

-- Try multiple methods to find ABI
function M.find_function_abi(func_name)
  -- Method 1: Look for common contract patterns
  local common_contracts = {
    "Tracer", "AllocationManager", "DelegationManager", 
    "StrategyManager", "EigenPodManager", "AVSDirectory"
  }
  
  for _, contract in ipairs(common_contracts) do
    local abi = M.get_function_abi(contract, func_name)
    if abi then
      return abi, contract
    end
  end
  
  -- Method 2: Search for contracts containing the function
  local contracts = M.find_contracts_with_function(func_name)
  for _, contract_info in ipairs(contracts) do
    local abi = M.get_function_abi(contract_info.name, func_name)
    if abi then
      return abi, contract_info.name
    end
  end
  
  -- Method 3: Try to find from artifacts
  local artifacts_cmd = string.format(
    "find . -name '*.json' -path '*/artifacts/*' -o -path '*/out/*' | " ..
    "xargs grep -l '\"%s\"' 2>/dev/null | head -5",
    func_name
  )
  
  local artifacts_output = vim.fn.system(artifacts_cmd)
  if vim.v.shell_error == 0 and artifacts_output ~= "" then
    for artifact_path in artifacts_output:gmatch("[^\n]+") do
      -- Try to extract ABI from artifact
      local jq_cmd = string.format(
        "jq '.abi[] | select(.name == \"%s\")' %s 2>/dev/null",
        func_name, artifact_path
      )
      local abi_output = vim.fn.system(jq_cmd)
      if vim.v.shell_error == 0 and abi_output ~= "" then
        local ok, abi = pcall(vim.json.decode, abi_output)
        if ok and abi then
          return abi, artifact_path:match("([^/]+)%.json$")
        end
      end
    end
  end
  
  return nil
end

-- Extract parameter structure from ABI
function M.extract_param_structure(abi_func)
  if not abi_func or not abi_func.inputs then
    return nil
  end
  
  local params = {}
  
  for _, input in ipairs(abi_func.inputs) do
    local param = {
      name = input.name,
      type = input.type,
      internal_type = input.internalType,
      components = {}
    }
    
    -- Handle complex types with components
    if input.components then
      param.components = M.extract_components(input.components)
    end
    
    table.insert(params, param)
  end
  
  return params
end

-- Recursively extract component structure
function M.extract_components(components)
  local result = {}
  
  for _, comp in ipairs(components) do
    local item = {
      name = comp.name,
      type = comp.type,
      internal_type = comp.internalType,
      components = {}
    }
    
    if comp.components then
      item.components = M.extract_components(comp.components)
    end
    
    table.insert(result, item)
  end
  
  return result
end

-- Generate field paths for decoded data
function M.generate_field_paths(param_structure)
  local paths = {}
  
  local function traverse(params, prefix)
    for i, param in ipairs(params) do
      local current_path = prefix and (prefix .. "." .. param.name) or param.name
      
      -- Add the current path
      table.insert(paths, {
        path = current_path,
        name = param.name,
        type = param.type,
        internal_type = param.internal_type
      })
      
      -- Handle arrays
      if param.type:match("%[%]$") then
        -- For arrays, we need to handle indices
        if #param.components > 0 then
          -- Array of structs
          traverse(param.components, current_path .. "[i]")
        end
      elseif #param.components > 0 then
        -- Struct
        traverse(param.components, current_path)
      end
    end
  end
  
  traverse(param_structure, nil)
  return paths
end

return M