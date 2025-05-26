-- Test Solidity signature parser
local parser = require('hexer.solidity_parser')

local test_cases = {
  {
    signature = "transfer(address,uint256)",
    expected = {
      name = "transfer",
      param_count = 2,
      param_names = {"account", "amount1"}
    }
  },
  {
    signature = "modifyAllocations(address,((address,uint32),address[],uint64[])[])",
    expected = {
      name = "modifyAllocations", 
      param_count = 2,
      param_names = {"operator", "allocationParams"}
    }
  },
  {
    signature = "swap(uint256,uint256,address,bytes)",
    expected = {
      name = "swap",
      param_count = 4,
      param_names = {"amount1", "amount2", "address3", "param4"}
    }
  },
  {
    signature = "multicall(bytes[])",
    expected = {
      name = "multicall",
      param_count = 1,
      param_names = {"param1"}
    }
  }
}

-- Run tests
for _, test in ipairs(test_cases) do
  print("Testing: " .. test.signature)
  
  local result = parser.parse_signature(test.signature)
  assert(result, "Failed to parse signature")
  assert(result.name == test.expected.name, "Function name mismatch")
  assert(#result.parameters == test.expected.param_count, "Parameter count mismatch")
  
  local names = parser.generate_parameter_names(result.parameters)
  for i, expected_name in ipairs(test.expected.param_names) do
    assert(names[i] == expected_name, 
      string.format("Parameter %d name mismatch: got '%s', expected '%s'", 
        i, names[i], expected_name))
  end
  
  print("  ✓ Passed")
end

-- Test complex tuple parsing
print("\nTesting complex tuple parsing...")
local complex_sig = "modifyAllocations(address,((address,uint32),address[],uint64[])[])"
local result = parser.parse_signature(complex_sig)

print("Parameters:")
for i, param in ipairs(result.parameters) do
  print(string.format("  [%d] %s", i, parser.format_type(param)))
  if param.is_tuple and param.tuple_elements then
    print("    Tuple elements:")
    for j, elem in ipairs(param.tuple_elements) do
      print(string.format("      [%d] %s", j, parser.format_type(elem)))
    end
  end
end

print("\nAll tests passed!")