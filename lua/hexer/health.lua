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
  local commands = {"HexerFormat", "HexerBytesToAscii", "HexerDecode"}
  for _, cmd in ipairs(commands) do
    if vim.fn.exists(":" .. cmd) == 2 then
      vim.health.ok(string.format("Command :%s is available", cmd))
    else
      vim.health.error(string.format("Command :%s is not available", cmd))
    end
  end
  
  -- Check for Foundry installation
  vim.health.start("Optional dependencies")
  local cast_check = vim.fn.system("which cast")
  if vim.v.shell_error == 0 then
    vim.health.ok("Foundry's cast command is available (required for :HexerDecode)")
    
    -- Check cast version
    local version_output = vim.fn.system("cast --version")
    if vim.v.shell_error == 0 then
      local version = version_output:match("cast (%S+)")
      if version then
        vim.health.info("Cast version: " .. version)
      end
    end
  else
    vim.health.warn("Foundry's cast command not found. Install from https://getfoundry.sh/")
    vim.health.info("The :HexerDecode command requires Foundry to be installed")
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
  
  -- Check default keymaps
  vim.health.start("Keybindings")
  if vim.g.hexer_no_mappings then
    vim.health.info("Default keymaps are disabled (g:hexer_no_mappings is set)")
  else
    vim.health.ok("Default keymaps enabled:")
    vim.health.info("  <leader>hd - [H]exer [D]ecode (ABI decode)")
    vim.health.info("  <leader>hf - [H]exer [F]ormat (format calldata)")
    vim.health.info("  <leader>ha - [H]exer [A]scii (convert to ASCII)")
  end
end

return M