-- Persistent cache for function signatures and ABIs
local M = {}

-- Cache configuration
local cache_dir = vim.fn.stdpath("cache") .. "/hexer"
local sig_cache_file = cache_dir .. "/signatures.json"
local abi_cache_file = cache_dir .. "/abis.json"

-- In-memory caches
M.signatures = {}
M.abis = {}

-- Ensure cache directory exists
local function ensure_cache_dir()
  if vim.fn.isdirectory(cache_dir) == 0 then
    vim.fn.mkdir(cache_dir, "p")
  end
end

-- Load cache from disk
function M.load()
  ensure_cache_dir()
  
  -- Load signatures
  if vim.fn.filereadable(sig_cache_file) == 1 then
    local content = vim.fn.readfile(sig_cache_file)
    if #content > 0 then
      local ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
      if ok and data then
        M.signatures = data
      end
    end
  end
  
  -- Load ABIs
  if vim.fn.filereadable(abi_cache_file) == 1 then
    local content = vim.fn.readfile(abi_cache_file)
    if #content > 0 then
      local ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
      if ok and data then
        M.abis = data
      end
    end
  end
end

-- Save cache to disk
function M.save()
  ensure_cache_dir()
  
  -- Save signatures
  local ok, sig_json = pcall(vim.json.encode, M.signatures)
  if ok then
    vim.fn.writefile({sig_json}, sig_cache_file)
  end
  
  -- Save ABIs
  local ok_abi, abi_json = pcall(vim.json.encode, M.abis)
  if ok_abi then
    vim.fn.writefile({abi_json}, abi_cache_file)
  end
end

-- Get function signature from selector
function M.get_signature(selector)
  -- Normalize selector (remove 0x if present)
  selector = selector:gsub("^0x", ""):sub(1, 8):lower()
  return M.signatures[selector]
end

-- Set function signature for selector
function M.set_signature(selector, signature)
  selector = selector:gsub("^0x", ""):sub(1, 8):lower()
  M.signatures[selector] = signature
  M.save()
end

-- Get ABI for function
function M.get_abi(func_name, contract_name)
  local key = contract_name and (contract_name .. ":" .. func_name) or func_name
  return M.abis[key]
end

-- Set ABI for function
function M.set_abi(func_name, contract_name, abi)
  local key = contract_name and (contract_name .. ":" .. func_name) or func_name
  M.abis[key] = abi
  M.save()
end

-- Get all signatures (for debugging/inspection)
function M.get_all_signatures()
  return M.signatures
end

-- Get all ABIs (for debugging/inspection)
function M.get_all_abis()
  return M.abis
end

-- Clear cache
function M.clear()
  M.signatures = {}
  M.abis = {}
  M.save()
end

-- Clear specific entries
function M.clear_signature(selector)
  selector = selector:gsub("^0x", ""):sub(1, 8):lower()
  M.signatures[selector] = nil
  M.save()
end

function M.clear_abi(func_name, contract_name)
  local key = contract_name and (contract_name .. ":" .. func_name) or func_name
  M.abis[key] = nil
  M.save()
end

-- Stats
function M.stats()
  return {
    signatures = vim.tbl_count(M.signatures),
    abis = vim.tbl_count(M.abis),
    cache_dir = cache_dir
  }
end

-- Initialize cache on load
M.load()

-- Auto-save on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  pattern = "*",
  callback = function()
    M.save()
  end,
  desc = "Save hexer cache"
})

return M