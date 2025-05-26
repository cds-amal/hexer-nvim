-- Tree formatter for complex ABI decoded data
local M = {}

-- Tree drawing characters
local tree_chars = {
  mid = "├─",
  last = "└─",
  vert = "│ ",
  empty = "  "
}

-- Store ABI information for current formatting session
M.current_abi = nil

-- Format allocation params structure
function M.format_allocation_params(value, indent, parser)
  local lines = {}
  
  -- Parse the array of allocation params
  if not value:match("^%[%(") then
    return lines
  end
  
  -- Remove outer brackets
  local inner = value:sub(2, -2)
  
  -- Parse each allocation param
  local current = ""
  local depth = 0
  local params = {}
  
  for i = 1, #inner do
    local char = inner:sub(i, i)
    if char == "(" then
      depth = depth + 1
    elseif char == ")" then
      depth = depth - 1
    end
    
    current = current .. char
    
    -- Complete param when depth returns to 0 after a closing paren
    if depth == 0 and current ~= "" and current:match("%)$") then
      table.insert(params, current)
      current = ""
      -- Skip comma and space
      if i < #inner and inner:sub(i+1, i+2):match("^, ") then
        -- Skip ahead
      end
    end
  end
  
  -- Format each param
  for idx, param in ipairs(params) do
    -- This should be ((address,uint32), address[], uint64[])
    if param:match("^%(%(.*%), %[.*%], %[.*%]%)$") then
      -- Extract the inner content
      local content = param:match("^%((.+)%)$")
      
      -- Split into three main parts
      local parts = M.split_allocation_parts(content)
      
      if #parts >= 3 then
        -- Add spacing before each param except first
        if idx > 1 then
          table.insert(lines, "")
        end
        
        -- Main allocation param header with offset
        table.insert(lines, string.format("%sAllocationParams[%d]:%s@ 0x%03x",
          indent, idx-1,
          string.rep(" ", 50 - #indent - #string.format("AllocationParams[%d]:", idx-1)),
          parser.offset + 0x20 + (idx-1) * 0xe0))
        
        -- Parse operatorSet
        local operatorSet = parts[1]
        if operatorSet:match("^%(.*%)$") then
          local op_content = operatorSet:match("^%((.+)%)$")
          local avs, id = op_content:match("^(0x[0-9a-fA-F]+),%s*(%d+)$")
          if avs and id then
            table.insert(lines, indent .. "  " .. tree_chars.mid .. " operatorSet.avs: " .. avs:lower())
            table.insert(lines, indent .. "  " .. tree_chars.mid .. " operatorSet.id:  " .. id)
          end
        end
        
        -- Parse strategies array
        local strategies = parts[2]
        if strategies:match("^%[.*%]$") then
          local strat_content = strategies:match("^%[(.*)%]$")
          local strats = {}
          for addr in strat_content:gmatch("0x[0-9a-fA-F]+") do
            table.insert(strats, addr:lower())
          end
          
          if #strats > 0 then
            table.insert(lines, string.format("%s  %s strategies:%s@ 0x%03x",
              indent, tree_chars.mid,
              string.rep(" ", 50 - #indent - 14),
              parser.offset + 0x20 + (idx-1) * 0xe0 + 0x80))
            
            for i, strat in ipairs(strats) do
              local prefix = i < #strats and tree_chars.mid or tree_chars.last
              table.insert(lines, indent .. "  " .. tree_chars.vert .. "   " .. prefix .. 
                string.format(" [%d] %s", i-1, strat))
            end
          end
        end
        
        -- Parse magnitudes array
        local magnitudes = parts[3]
        if magnitudes:match("^%[.*%]$") then
          local mag_content = magnitudes:match("^%[(.*)%]$")
          local mags = {}
          for num in mag_content:gmatch("%d+") do
            table.insert(mags, num)
          end
          
          if #mags > 0 then
            table.insert(lines, string.format("%s  %s magnitudes:%s@ 0x%03x",
              indent, tree_chars.last,
              string.rep(" ", 50 - #indent - 13),
              parser.offset + 0x20 + (idx-1) * 0xe0 + 0xe0))
            
            for i, mag in ipairs(mags) do
              local prefix = i < #mags and tree_chars.mid or tree_chars.last
              table.insert(lines, indent .. "      " .. prefix .. 
                string.format(" [%d] %s", i-1, mag))
            end
          end
        end
      end
    end
  end
  
  return lines
end

-- Split allocation param parts carefully
function M.split_allocation_parts(content)
  local parts = {}
  local current = ""
  local depth = 0
  local in_brackets = 0
  
  for i = 1, #content do
    local char = content:sub(i, i)
    
    if char == "(" then
      depth = depth + 1
    elseif char == ")" then
      depth = depth - 1
    elseif char == "[" then
      in_brackets = in_brackets + 1
    elseif char == "]" then
      in_brackets = in_brackets - 1
    end
    
    current = current .. char
    
    -- Split on comma at depth 0 and not in brackets
    if char == "," and depth == 0 and in_brackets == 0 then
      -- Remove the comma and trim
      table.insert(parts, current:sub(1, -2):match("^%s*(.-)%s*$"))
      current = ""
      -- Skip space after comma
      if i < #content and content:sub(i+1, i+1) == " " then
        -- Skip it
      end
    end
  end
  
  -- Add the last part
  if current ~= "" then
    table.insert(parts, current:match("^%s*(.-)%s*$"))
  end
  
  return parts
end

return M