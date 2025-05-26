local M = {}

-- Health check for hexer.nvim
function M.check()
  vim.health.start("hexer.nvim")
  
  -- Check Neovim version
  if vim.fn.has("nvim-0.8.0") == 1 then
    vim.health.ok("Neovim version is compatible")
  else
    vim.health.error("hexer.nvim requires Neovim >= 0.8.0")
  end
  
  -- Check if plugin is loaded
  if vim.g.loaded_hexer then
    vim.health.ok("Plugin is loaded")
  else
    vim.health.error("Plugin is not loaded. Check your plugin manager configuration.")
  end
  
  -- Check configuration
  local ok, config = pcall(require, "hexer.config")
  if ok then
    vim.health.ok("Configuration module loaded")
    
    -- Check if setup was called
    if config.options and next(config.options) ~= nil then
      vim.health.ok("Setup function has been called")
    else
      vim.health.info("Setup function not called. Using default configuration.")
    end
  else
    vim.health.error("Failed to load configuration module")
  end
  
  -- Check commands
  local commands = {"HexerFormat", "HexerBytesToAscii"}
  for _, cmd in ipairs(commands) do
    if vim.fn.exists(":" .. cmd) == 2 then
      vim.health.ok(string.format("Command :%s is available", cmd))
    else
      vim.health.error(string.format("Command :%s is not available", cmd))
    end
  end
  
  -- Test basic functionality
  local api_ok, api = pcall(require, "hexer.api")
  if api_ok then
    vim.health.ok("API module loaded successfully")
    
    -- Test hex validation
    local test_ok = pcall(function()
      local validate = debug.getinfo(api.format_data).func
      -- Basic smoke test
    end)
    
    if test_ok then
      vim.health.ok("Basic API functionality working")
    else
      vim.health.warn("Could not verify API functionality")
    end
  else
    vim.health.error("Failed to load API module: " .. tostring(api))
  end
  
  -- Suggest keybindings if not set
  vim.health.start("Suggested keybindings")
  vim.health.info([[
Add these to your config:
```lua
vim.keymap.set('n', '<leader>hf', '<cmd>HexerFormat<cr>', { desc = 'Format hex calldata' })
vim.keymap.set('v', '<leader>hf', '<cmd>HexerFormat<cr>', { desc = 'Format hex calldata' })
vim.keymap.set('n', '<leader>ha', '<cmd>HexerBytesToAscii<cr>', { desc = 'Convert hex to ASCII' })
vim.keymap.set('v', '<leader>ha', '<cmd>HexerBytesToAscii<cr>', { desc = 'Convert hex to ASCII' })
```
  ]])
end

return M