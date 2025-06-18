# AIXcel Backend API Testing

This directory contains comprehensive tests for the AIXcel backend API.

## Test Script: `test_api.sh`

A comprehensive test suite that validates all backend functionality while preserving existing data.

### Features

- **Data Preservation**: Automatically backs up existing spreadsheet data before testing and restores it afterward
- **Comprehensive Coverage**: Tests all API endpoints and features including:
  - Health checks
  - Basic cell operations (create, read, update, delete)
  - Cell formatting (bold, italic, background colors)
  - Formula evaluation (SUM, AVERAGE, arithmetic)
  - Formula cells with cell references
  - Bulk operations (insert/clear multiple cells)
  - Large dataset performance testing
  - Edge cases and error handling
  - Cell updates and overwrites

### Usage

```bash
# Test against local backend
./test_api.sh

# Test against specific backend URL
./test_api.sh http://192.168.10.161:6889

# Make sure the script is executable
chmod +x test_api.sh
```

### Test Categories

1. **Health Check**: Verifies backend is running and responding
2. **Basic Operations**: Text/number cells, listing, basic CRUD
3. **Formatting**: Bold, italic, colors, multiple formats
4. **Formulas**: SUM, AVERAGE, arithmetic, complex expressions
5. **Formula Cells**: Cells containing formulas that reference other cells
6. **Bulk Operations**: Mass insert/delete operations
7. **Performance**: Large dataset handling (100+ cells)
8. **Edge Cases**: Error handling, special characters, large coordinates
9. **Updates**: Overwriting existing cells, format changes

### Output

The script provides colored output with:
- ✅ **Green**: Passed tests
- ❌ **Red**: Failed tests
- ℹ️ **Blue**: Information messages
- ⚠️ **Yellow**: Warnings

### Example Output

```
🎉 All tests completed successfully!

Test Summary:
  ✓ health endpoint returns 'ok'
  ✓ add simple text cell
  ✓ SUM formula evaluation
  ✓ bulk insert 5 cells
  ✓ large dataset retrieval performance acceptable (<1s)
  ...

Total tests passed: 37
Backend is fully functional!
```

### Safety Features

- **Automatic Backup**: Creates timestamped backup before testing
- **Automatic Restore**: Restores original data even if tests fail
- **Cleanup on Exit**: Ensures data is restored on script termination
- **Non-destructive**: Original spreadsheet data is always preserved

### Dependencies

- `curl`: For HTTP requests
- `jq`: For JSON parsing and manipulation
- `bash`: Shell environment

Make sure these tools are installed before running the tests.
