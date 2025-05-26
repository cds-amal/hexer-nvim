-- Test LPeg-based Solidity parser
local parser = require('hexer.solidity_parser_lpeg')

-- Test cases
local test_cases = {
  {
    name = "Simple transfer",
    signature = "transfer(address,uint256)",
    expected_params = 2,
    expected_names = {"recipient", "amount"}
  },
  {
    name = "Complex modifyAllocations",
    signature = "modifyAllocations(address,((address,uint32),address[],uint64[])[])",
    expected_params = 2,
    expected_names = {"operator", "allocationParams"}
  },
  {
    name = "Multiple arrays",
    signature = "multicall(bytes[],bool[])",
    expected_params = 2,
    expected_names = {"dataArray", "flagArray"}
  },
  {
    name = "Fixed size array",
    signature = "setValues(uint256[10])",
    expected_params = 1,
    expected_names = {"amount1Array"}
  },
  {
    name = "Nested tuples",
    signature = "complex((uint256,bytes32),(address,bool)[])",
    expected_params = 2,
    expected_names = {"data1", "data2Array"}
  },
  {
    name = "Empty parameters",
    signature = "noParams()",
    expected_params = 0,
    expected_names = {}
  }
}

-- Run tests
print("Testing LPeg Solidity parser...")
print("=" .. string.rep("=", 50))

for _, test in ipairs(test_cases) do
  print("\nTest: " .. test.name)
  print("Signature: " .. test.signature)
  
  local result = parser.parse_signature(test.signature)
  if not result then
    print("  ✗ Failed to parse")
  else
    print("  Function: " .. result.name)
    print("  Parameters: " .. #result.parameters)
    
    -- Check parameter count
    if #result.parameters ~= test.expected_params then
      print("  ✗ Expected " .. test.expected_params .. " parameters, got " .. #result.parameters)
    else
      print("  ✓ Parameter count correct")
    end
    
    -- Generate and check names
    local names = parser.generate_parameter_names(result.parameters)
    print("  Generated names: " .. table.concat(names, ", "))
    
    local names_match = true
    for i, expected in ipairs(test.expected_names) do
      if names[i] ~= expected then
        names_match = false
        print("  ✗ Name mismatch at position " .. i .. ": expected '" .. expected .. "', got '" .. (names[i] or "nil") .. "'")
      end
    end
    
    if names_match and #names == #test.expected_names then
      print("  ✓ Names match")
    end
    
    -- Print detailed parameter info
    for i, param in ipairs(result.parameters) do
      print("  Param " .. i .. ": " .. parser.format_type(param))
      local info = parser.get_type_info(param)
      if info.is_array then
        print("    - Array with dimensions: " .. vim.inspect(info.array_dimensions))
      end
      if info.is_tuple then
        print("    - Tuple with " .. #param.elements .. " elements")
      end
    end
  end
end

-- Test specific parsing case
print("\n" .. string.rep("=", 50))
print("Detailed test: modifyAllocations")
local sig = "modifyAllocations(address,((address,uint32),address[],uint64[])[])"
local result = parser.parse_signature(sig)

if result then
  print("Parsed successfully!")
  print("Function name: " .. result.name)
  
  for i, param in ipairs(result.parameters) do
    print("\nParameter " .. i .. ":")
    print("  Type: " .. parser.format_type(param))
    
    if param.type == "array" and param.base.type == "tuple" then
      print("  Array of tuples detected")
      print("  Tuple structure:")
      for j, elem in ipairs(param.base.elements) do
        print("    Element " .. j .. ": " .. parser.format_type(elem))
      end
    end
  end
end