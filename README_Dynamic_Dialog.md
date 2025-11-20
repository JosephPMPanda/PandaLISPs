# Dynamic Height Layer Selector for AutoCAD 2025

## Problem
The original `layer_selector.dcl` dialog had a fixed height of 15 lines for the layer list, causing unnecessary scrolling when dealing with many layers.

## Solution Overview
I've created three versions of the solution, with increasing levels of sophistication:

### Version 1: Basic Dynamic DCL (`layer_selector_dynamic.dcl` + `layermgr_dynamic.lsp`)
- Modified DCL file without fixed height
- LISP attempts to calculate optimal height
- **Limitation**: DCL doesn't truly support runtime height modification

### Version 2: Fully Dynamic Solution (`layermgr_dynamic_v2.lsp`)
- **Recommended Solution**
- Generates DCL content programmatically at runtime
- Calculates optimal height based on:
  - Number of layers in the drawing
  - Screen resolution (using SCREENSIZE system variable)
  - Reasonable min/max bounds (5-40 lines)
- Creates temporary DCL file with exact height needed
- Automatically cleans up temporary files

## Installation Instructions

### For the Recommended Solution (Version 2):
1. Load `layermgr_dynamic_v2.lsp` into AutoCAD 2025
2. No separate DCL file needed - it's generated automatically
3. Type `LAYERMGR` to use the command

### For Testing Other Versions:
- **Version 1**: Place both `layer_selector_dynamic.dcl` and `layermgr_dynamic.lsp` in AutoCAD's search path
- **Original**: Use `layer_selector.dcl` and `layermgr.lsp`

## Key Features of the Dynamic Solution

### Intelligent Height Calculation
```lisp
;; Calculates optimal height based on:
- Screen resolution (pixels to dialog units)
- Number of layers in drawing
- Dialog overhead (buttons, title, etc.)
- Min height: 5 lines (for usability)
- Max height: 40 lines (or screen limit)
```

### Dynamic DCL Generation
- Creates DCL content as a string at runtime
- Writes to temporary file in AutoCAD's temp directory
- Loads and displays the customized dialog
- Cleans up temporary files after use

### Screen-Aware Sizing
- Uses `(getvar "SCREENSIZE")` to get screen dimensions
- Converts pixels to approximate dialog units
- Accounts for dialog chrome and other UI elements
- Prevents dialog from exceeding screen bounds

## Usage
1. Select objects in your drawing (or select when prompted)
2. Type `LAYERMGR`
3. The dialog will appear with optimal height:
   - Few layers: Compact dialog
   - Many layers: Expanded to show more without scrolling
   - Excessive layers: Capped at screen-appropriate maximum
4. Use search, select layers, copy/move as before

## Benefits
- **No more unnecessary scrolling** for typical layer counts
- **Better overview** of available layers
- **Faster workflow** with less scrolling
- **Adaptive to screen size** - works on different monitor resolutions
- **Backward compatible** - all original functionality preserved

## Technical Details

### Height Calculation Formula
```
optimal_height = min(max(layer_count + 1, 5), min(40, screen_based_max))
```

### Files Created
- **Permanent**: The LISP file you load
- **Temporary**: `layer_selector_temp.dcl` in temp directory (auto-deleted)

### Compatibility
- Tested for AutoCAD 2025
- Should work with AutoCAD 2020 and later
- Uses standard AutoLISP functions

## Troubleshooting

### Dialog doesn't appear
- Ensure LISP file is loaded correctly
- Check that temp directory is writable
- Verify no syntax errors in command line

### Height seems wrong
- The formula estimates ~20 pixels per dialog line
- Adjust the `overhead-lines` variable if needed (default: 12)
- Consider your DPI settings if using high-resolution displays

### Performance
- DCL generation is nearly instantaneous
- No noticeable performance impact
- Temporary file is small (<2KB)

## Customization
You can adjust these parameters in `layermgr_dynamic_v2.lsp`:
- `min-height`: Minimum list height (default: 5)
- `max-height`: Maximum list height (default: 40)
- `overhead-lines`: UI overhead estimate (default: 12)

## Original Files
- `layer_selector.dcl` - Original fixed-height DCL
- `layermgr.lsp` - Original LISP implementation

These are preserved for reference and fallback purposes.
