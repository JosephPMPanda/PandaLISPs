# Block BURST Operations for AutoCAD 2025

A dynamic AutoLISP routine that provides a dialog interface for block operations without requiring a separate .dcl file.

## Overview

`block_burst.lsp` provides two essential block operations through an intuitive dialog interface:

1. **Override Block Explodability** - Enables the "allow exploding" attribute for all block definitions in the drawing
2. **BURST All Blocks** - Explodes all block references while preserving their original layer assignments

## Features

- ✅ **Dynamic DCL Generation** - No separate .dcl file required; dialog is generated at runtime
- ✅ **Real-time Status Display** - Shows current block counts (definitions and references)
- ✅ **Three Operation Modes**:
  - Override explodability only
  - BURST blocks only
  - Combined operation (recommended)
- ✅ **Express Tools Integration** - Uses AutoCAD's BURST command for layer preservation
- ✅ **Multiple Command Aliases** - Flexible command entry options
- ✅ **Detailed Feedback** - Progress updates and operation summaries

## Installation

1. Download `block_burst.lsp`
2. Load the file in AutoCAD using one of these methods:
   - Type `APPLOAD` and browse to the file
   - Drag and drop the file into AutoCAD
   - Add to your startup suite for automatic loading

## Usage

### Commands

- `BLOCKBURST` - Full command name
- `BB` - Quick shortcut (recommended)
- `BBURST` - Alternative shortcut

### Basic Workflow

1. Type `BB` (or `BLOCKBURST`) at the command line
2. The dialog will display showing:
   - Current number of block definitions
   - Current number of block references
3. Choose one of three operations:
   - **Override Block Explodability** - Makes all blocks explodable
   - **BURST All Blocks** - Explodes blocks while keeping layers
   - **Both Operations** - Recommended for complete processing

### Operation Details

#### 1. Override Block Explodability

This operation modifies all block definitions in the drawing to allow exploding:

- Scans all block definitions (excluding anonymous and xref blocks)
- Clears the "disallow exploding" flag (DXF code 70, bit 0)
- Updates each block definition using `entmod`
- Regenerates the drawing to reflect changes
- Provides a summary of successful and failed operations

**When to use:**
- Before attempting to explode blocks that are currently non-explodable
- As preparation for the BURST operation
- When standardizing block properties across a drawing

#### 2. BURST All Blocks

This operation explodes all block references while preserving layer assignments:

- Uses AutoCAD's BURST command (requires Express Tools)
- Processes all INSERT entities in the drawing
- Each entity from the exploded block retains the layer it was originally on within the block definition
- Different from standard EXPLODE which moves entities to the block reference layer

**When to use:**
- Converting blocks to individual entities
- Maintaining layer organization after explosion
- Preparing drawings for specific workflows that require unbounded geometry

#### 3. Both Operations (Recommended)

Runs both operations in sequence:
1. First overrides all block explodability
2. Then BURSTs all blocks
3. Provides a combined summary

**When to use:**
- For complete block processing in one step
- When you're unsure if blocks are currently explodable
- As a comprehensive solution for converting blocked drawings

## Requirements

- **AutoCAD 2025** (or compatible version)
- **Express Tools** - Required for the BURST command
  - BURST is not available in AutoCAD LT
  - If Express Tools are not loaded, you'll receive an error message

### Checking Express Tools

To verify Express Tools are loaded:
1. Type `EXPRESSTOOLS` at the command line
2. If a menu appears, Express Tools are loaded
3. If not found, load them from the AutoCAD installation

## Technical Details

### How It Works

1. **Dynamic DCL Generation**:
   - Dialog structure is created as a string at runtime
   - Written to a temporary .dcl file in the system temp directory
   - Loaded into AutoCAD's DCL system
   - Cleaned up automatically after use

2. **Block Explodability Override**:
   - Uses `tblnext` to iterate through block table
   - Filters out anonymous blocks (`*`) and xref blocks (`|`)
   - Modifies DXF code 70 (flag value) using bitwise operations
   - Bit 0 controls explodability: 0=allow, 1=disallow

3. **BURST Operation**:
   - Creates selection set of all INSERT entities
   - Passes to the BURST command
   - BURST preserves original entity layers from block definition
   - Unlike EXPLODE, which moves all to the block reference layer

### File Structure

```
block_burst.lsp
├── Utility Functions
│   ├── count-blocks         - Count block references
│   └── get-all-block-names  - Get block definition list
├── Operation Functions
│   ├── override-block-explodability - Enable exploding
│   ├── burst-all-blocks            - BURST operation
│   └── perform-both-operations      - Combined operation
├── DCL Generation
│   ├── generate-block-burst-dcl    - Create DCL string
│   ├── write-temp-dcl              - Write to temp file
│   └── show-block-burst-dialog     - Display and manage
└── Command Definitions
    ├── C:BLOCKBURST  - Main command
    ├── C:BB          - Shortcut
    └── C:BBURST      - Alternative
```

## Troubleshooting

### "BURST command not found" Error

**Problem:** Express Tools are not loaded

**Solutions:**
1. Type `EXPRESSTOOLS` to load Express Tools menu
2. Check AutoCAD installation includes Express Tools
3. For AutoCAD LT users: BURST is not available (use standard EXPLODE instead)

### "No block definitions found"

**Problem:** The drawing contains no blocks

**Solution:** This is expected behavior for drawings without blocks

### Failed to modify block definitions

**Possible Causes:**
1. Block definitions are protected or locked
2. Drawing file permissions issues
3. Block is an xref or external reference

**Solution:** Check block properties and ensure write access to the drawing

### Operation takes a long time

**Cause:** Large number of blocks or complex nested blocks

**Note:** This is normal behavior. Progress is shown in the command line.

## Comparison with Standard EXPLODE

| Feature | EXPLODE | BURST (this tool) |
|---------|---------|-------------------|
| Preserves entity layers | ❌ No | ✅ Yes |
| Handles nested blocks | ⚠️ One level | ⚠️ One level |
| Requires Express Tools | ❌ No | ✅ Yes |
| Works in AutoCAD LT | ✅ Yes | ❌ No |
| Attributes handling | Converts to text | Converts to text |

## Examples

### Example 1: Processing a Drawing with Protected Blocks

```
Command: BB
[Dialog appears showing: Block Definitions: 15 | Block References: 247]
[Click "Both Operations"]

╔════════════════════════════════════════╗
║ Overriding Block Explodability...     ║
╚════════════════════════════════════════╝

Found 15 block definition(s) to process...
  Processing: DOOR - ✓ Explodability enabled
  Processing: WINDOW - ✓ Explodability enabled
  Processing: TABLE - ✓ Explodability enabled
  ...

Results: 15 succeeded, 0 failed

╔════════════════════════════════════════╗
║ BURSTING All Blocks...                 ║
╚════════════════════════════════════════╝

Found 247 block reference(s) to burst...
  Executing BURST command...

BURST operation completed on 247 block(s)
```

### Example 2: Drawing Without Blocks

```
Command: BLOCKBURST
[Dialog appears showing: Block Definitions: 0 | Block References: 0]
[Click any operation]

✗ No block definitions found in the drawing.
```

## Advanced Usage

### Using in Scripts

The commands can be used in AutoCAD scripts:

```lisp
(load "block_burst.lsp")
(C:BLOCKBURST)
; User must interact with dialog
```

For automated workflows without dialog:

```lisp
(load "block_burst.lsp")
(override-block-explodability)
(burst-all-blocks)
```

### Integration with Other Routines

The utility functions can be called from other AutoLISP routines:

```lisp
;; Count blocks in current drawing
(setq block-count (count-blocks))

;; Get list of block names
(setq block-names (get-all-block-names))

;; Enable exploding for all blocks
(override-block-explodability)

;; BURST all blocks
(burst-all-blocks)
```

## Best Practices

1. **Save Before Processing** - Always save your drawing before running BURST operations
2. **Test on Copy** - Try the operation on a copy of your drawing first
3. **Check Layers** - Verify layer structure is as expected after BURST
4. **Use Both Operations** - For maximum compatibility, use the combined operation
5. **Audit Regularly** - Run AUDIT after major block operations

## Limitations

1. **Express Tools Required** - BURST functionality requires Express Tools
2. **Not Available in LT** - AutoCAD LT users must use standard EXPLODE
3. **One Level Only** - Nested blocks are exploded one level at a time
4. **Anonymous Blocks** - System blocks (dimensions, hatches) are excluded
5. **Xrefs** - External references are not processed

## Version History

- **v1.0** (2025) - Initial release
  - Dynamic DCL generation
  - Override block explodability
  - BURST all blocks
  - Combined operations mode

## License

This AutoLISP routine is provided as-is for use in AutoCAD environments.

## Support

For issues, questions, or contributions, please refer to the PandaLISPs repository.

---

**Note:** This routine modifies block definitions and explodes block references. Always maintain backups of important drawings before using block manipulation tools.
