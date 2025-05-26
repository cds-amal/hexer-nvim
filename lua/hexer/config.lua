local M = {}

-- Default configuration
M.defaults = {
  -- Display options
  group_size = 64,        -- Number of characters per line (32 bytes = 64 hex chars)
  chunk_size = 8,         -- Number of characters per chunk
  show_offset = true,     -- Show offset comments
  offset_format = "both", -- "hex", "decimal", or "both"
  
  -- Formatting options
  show_selector = true,   -- Show selector line for calldata
  uppercase = false,      -- Use uppercase hex letters
  
  -- UI options
  output_method = "insert", -- "insert", "float", or "virtual"
  float_opts = {
    border = "rounded",
    width = 0.8,
    height = 0.6,
  },
  
  -- Highlight groups
  highlights = {
    selector = "Title",
    offset = "Comment",
    data = "Normal",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

function M.get()
  -- Return defaults if setup hasn't been called yet
  if vim.tbl_isempty(M.options) then
    return M.defaults
  end
  return M.options
end

return M