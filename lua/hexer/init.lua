local M = {}
local api = require("hexer.api")
local config = require("hexer.config")

-- Setup function for configuration
function M.setup(opts)
  config.setup(opts)
end

-- Get current word or visual selection
local function get_input(input)
  if input and input ~= "" then
    return input
  end
  
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" then
    -- Get visual selection
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
    
    if #lines == 1 then
      -- Single line selection
      return lines[1]:sub(start_pos[3], end_pos[3])
    else
      -- Multi-line selection - join lines
      return table.concat(lines, "")
    end
  else
    -- Get word under cursor
    return vim.fn.expand("<cword>")
  end
end

-- Format calldata with improved error handling and flexibility
function M.format_calldata(input, opts)
  local ok, err = pcall(function()
    opts = opts or {}
    local cfg = config.get()
    
    -- Get input
    input = get_input(input)
    if not input or input == "" then
      error("No input provided. Place cursor on hex string or select text.")
    end
    
    -- Validate and use group size
    local group_size = opts.group_size or cfg.group_size
    if group_size % 2 ~= 0 or group_size < 2 or group_size > 64 then
      error("Group size must be an even number between 2 and 64")
    end
    
    -- Call the API function with configuration
    api.format_data(input, group_size, cfg)
  end)
  
  if not ok then
    vim.notify("Hexer: " .. err, vim.log.levels.ERROR)
  end
end

-- Convert bytes to ASCII with improved error handling
function M.bytes_to_ascii(input)
  local ok, err = pcall(function()
    input = get_input(input)
    if not input or input == "" then
      error("No input provided. Place cursor on hex string or select text.")
    end
    
    api.convert_bytes_to_ascii(input, config.get())
  end)
  
  if not ok then
    vim.notify("Hexer: " .. err, vim.log.levels.ERROR)
  end
end

-- ABI decode calldata using Foundry
function M.abi_decode(input)
  local ok, err = pcall(function()
    input = get_input(input)
    if not input or input == "" then
      error("No input provided. Place cursor on hex calldata or select text.")
    end
    
    api.abi_decode(input, config.get())
  end)
  
  if not ok then
    vim.notify("Hexer: " .. err, vim.log.levels.ERROR)
  end
end

return M
