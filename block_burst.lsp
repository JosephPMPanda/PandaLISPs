;; ===== BLOCK_BURST.LSP - AutoCAD 2025 Block Operations =====
;; Dynamic DCL dialog (no separate .dcl file required)
;; 
;; Features:
;; 1. Override block explodability (allow all blocks to be exploded)
;; 2. BURST all blocks (explode while preserving original layers)
;;
;; Usage: Type BLOCKBURST at the command line

;; ===== UTILITY FUNCTIONS =====

(defun count-blocks (/ ss count)
  "Count total number of block references in the drawing"
  (setq count 0)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (if ss
    (setq count (sslength ss))
  )
  count
)

(defun get-all-block-names (/ block-list block-name)
  "Get list of all block definition names in the drawing"
  (setq block-list '())
  (setq block-name (tblnext "BLOCK" T))
  (while block-name
    ;; Exclude anonymous blocks (starting with *) and xref blocks (containing |)
    (if (not (wcmatch (cdr (assoc 2 block-name)) "`**,*|*"))
      (setq block-list (cons (cdr (assoc 2 block-name)) block-list))
    )
    (setq block-name (tblnext "BLOCK"))
  )
  (reverse block-list)
)

(defun override-block-explodability (/ block-names block-name block-def flag-value new-flag success-count failed-count)
  "Override all block definitions to allow exploding"
  (princ "\n╔════════════════════════════════════════════════════════════╗")
  (princ "\n║ Overriding Block Explodability...                         ║")
  (princ "\n╚════════════════════════════════════════════════════════════╝")
  (princ "\n")
  
  (setq block-names (get-all-block-names))
  (setq success-count 0)
  (setq failed-count 0)
  
  (if (> (length block-names) 0)
    (progn
      (princ (strcat "\nFound " (itoa (length block-names)) " block definition(s) to process...\n"))
      
      (foreach block-name block-names
        (if (setq block-def (tblsearch "BLOCK" block-name))
          (progn
            (princ (strcat "\n  Processing: " block-name))
            
            ;; Get the block's current flag value (DXF code 70)
            ;; Bit 0 (value 1) controls explodability: 0=allow, 1=disallow
            (setq flag-value (cdr (assoc 70 block-def)))
            
            ;; Clear bit 0 to allow exploding (bitwise AND with complement)
            (setq new-flag (logand flag-value (~ 1)))
            
            ;; Use the BLOCK command to modify the block definition
            ;; We'll use entmod to update the block definition
            (if (entmod (subst (cons 70 new-flag) (assoc 70 block-def) block-def))
              (progn
                (princ " - ✓ Explodability enabled")
                (setq success-count (1+ success-count))
              )
              (progn
                (princ " - ✗ Failed to modify")
                (setq failed-count (1+ failed-count))
              )
            )
          )
          (progn
            (princ (strcat "\n  ✗ Could not find block definition: " block-name))
            (setq failed-count (1+ failed-count))
          )
        )
      )
      
      (princ "\n")
      (princ "\n┌────────────────────────────────────────────────────────────┐")
      (princ (strcat "\n│ Results: " (itoa success-count) " succeeded, " (itoa failed-count) " failed"))
      (princ "\n└────────────────────────────────────────────────────────────┘")
      (princ "\n")
      
      ;; Regenerate to update display
      (command "_.REGEN")
      
      success-count
    )
    (progn
      (princ "\n✗ No block definitions found in the drawing.")
      (princ "\n")
      0
    )
  )
)

(defun burst-all-blocks (/ ss count success-count error-count)
  "BURST all blocks in the drawing (explode while preserving layers)"
  (princ "\n╔════════════════════════════════════════════════════════════╗")
  (princ "\n║ BURSTING All Blocks...                                     ║")
  (princ "\n╚════════════════════════════════════════════════════════════╝")
  (princ "\n")
  
  ;; Count blocks before operation
  (setq count (count-blocks))
  
  (if (> count 0)
    (progn
      (princ (strcat "\nFound " (itoa count) " block reference(s) to burst...\n"))
      
      ;; Select all INSERT entities (block references)
      (setq ss (ssget "_X" '((0 . "INSERT"))))
      
      (if ss
        (progn
          ;; Use BURST command on all blocks
          ;; BURST is an Express Tools command that explodes blocks
          ;; while preserving the layer of each entity
          (princ "\n  Executing BURST command...")
          (princ "\n")
          
          ;; Execute BURST command
          ;; Note: Ensure Express Tools are loaded before using this command
          ;; Express Tools commands may need special initialization
          
          ;; First, try to ensure the command is available
          (if (not (wcmatch (getvar "CMDNAMES") "*BURST*"))
            ;; Try to initialize express tools burst command
            (progn
              (princ "\n  Initializing Express Tools...")
              ;; Load burst command explicitly if needed
              (vl-load-com)
            )
          )
          
          ;; Use the command with proper selection
          ;; Some versions require the selection set to be current first
          (sssetfirst nil ss)
          (command "BURST")
          
          ;; Wait for command to complete
          (while (> (getvar "CMDACTIVE") 0)
            (command "")
          )
          
          (princ "\n┌────────────────────────────────────────────────────────────┐")
          (princ (strcat "\n│ BURST operation completed on " (itoa count) " block(s)"))
          (princ "\n└────────────────────────────────────────────────────────────┘")
          (princ "\n")
          
          count
        )
        (progn
          (princ "\n✗ No block references found to burst.")
          (princ "\n")
          0
        )
      )
    )
    (progn
      (princ "\n✗ No block references found in the drawing.")
      (princ "\n")
      0
    )
  )
)

(defun perform-both-operations ()
  "Perform both override and burst operations in sequence"
  (princ "\n╔════════════════════════════════════════════════════════════╗")
  (princ "\n║ Performing Both Operations...                              ║")
  (princ "\n╚════════════════════════════════════════════════════════════╝")
  (princ "\n")
  
  ;; First override explodability
  (setq override-count (override-block-explodability))
  
  ;; Then burst all blocks
  (setq burst-count (burst-all-blocks))
  
  (princ "\n╔════════════════════════════════════════════════════════════╗")
  (princ "\n║ Combined Operation Summary                                 ║")
  (princ "\n╚════════════════════════════════════════════════════════════╝")
  (princ (strcat "\n  Block definitions modified: " (itoa override-count)))
  (princ (strcat "\n  Block references burst: " (itoa burst-count)))
  (princ "\n")
)

;; ===== DCL GENERATION =====

(defun generate-block-burst-dcl (/ dcl-content block-count)
  "Generate DCL content for the block burst dialog"
  (setq block-count (count-blocks))
  
  (setq dcl-content 
    (strcat
      "// Dynamically generated dialog for block burst operations\n"
      "block_burst_dialog : dialog {\n"
      "    label = \"Block BURST Operations\";\n"
      "    width = 55;\n"
      "    \n"
      "    : boxed_column {\n"
      "        label = \"Current Drawing Status\";\n"
      "        \n"
      "        : text {\n"
      "            key = \"status_text\";\n"
      "            label = \"\";\n"
      "        }\n"
      "    }\n"
      "    \n"
      "    : boxed_column {\n"
      "        label = \"Available Operations\";\n"
      "        \n"
      "        : text {\n"
      "            label = \"Select an operation to perform:\";\n"
      "        }\n"
      "        \n"
      "        spacer;\n"
      "        \n"
      "        : button {\n"
      "            key = \"override_btn\";\n"
      "            label = \"1. Override Block Explodability\";\n"
      "            width = 40;\n"
      "        }\n"
      "        \n"
      "        : text {\n"
      "            label = \"   (Enable exploding for all block definitions)\";\n"
      "            alignment = left;\n"
      "        }\n"
      "        \n"
      "        spacer;\n"
      "        \n"
      "        : button {\n"
      "            key = \"burst_btn\";\n"
      "            label = \"2. BURST All Blocks\";\n"
      "            width = 40;\n"
      "        }\n"
      "        \n"
      "        : text {\n"
      "            label = \"   (Explode blocks while preserving layers)\";\n"
      "            alignment = left;\n"
      "        }\n"
      "        \n"
      "        spacer;\n"
      "        \n"
      "        : button {\n"
      "            key = \"both_btn\";\n"
      "            label = \"3. Both Operations (Override + BURST)\";\n"
      "            width = 40;\n"
      "        }\n"
      "        \n"
      "        : text {\n"
      "            label = \"   (Recommended: Run both in sequence)\";\n"
      "            alignment = left;\n"
      "        }\n"
      "    }\n"
      "    \n"
      "    spacer;\n"
      "    \n"
      "    : boxed_column {\n"
      "        label = \"Information\";\n"
      "        \n"
      "        : text {\n"
      "            label = \"NOTE: BURST requires Express Tools to be loaded.\";\n"
      "            alignment = left;\n"
      "        }\n"
      "        \n"
      "        : text {\n"
      "            label = \"The BURST command explodes blocks while keeping\";\n"
      "            alignment = left;\n"
      "        }\n"
      "        \n"
      "        : text {\n"
      "            label = \"entities in their original block layers.\";\n"
      "            alignment = left;\n"
      "        }\n"
      "    }\n"
      "    \n"
      "    spacer;\n"
      "    \n"
      "    : row {\n"
      "        fixed_width = true;\n"
      "        alignment = centered;\n"
      "        \n"
      "        : button {\n"
      "            key = \"cancel\";\n"
      "            label = \"Close\";\n"
      "            width = 12;\n"
      "            is_cancel = true;\n"
      "            is_default = true;\n"
      "        }\n"
      "    }\n"
      "}\n"
    )
  )
  dcl-content
)

(defun write-temp-dcl (dcl-content / temp-path temp-file f result)
  "Write DCL content to a temporary file and return the file path"
  (setq temp-path (getvar "TEMPPREFIX"))
  (setq temp-file (strcat temp-path "block_burst_temp.dcl"))
  
  (setq f (open temp-file "w"))
  (if f
    (progn
      (write-line dcl-content f)
      (close f)
      (setq result temp-file)
    )
    (progn
      (princ "\n✗ ERROR: Could not create temporary DCL file.")
      (setq result nil)
    )
  )
  result
)

(defun show-block-burst-dialog (/ dcl-content temp-dcl-file dcl_id result block-count block-names operation)
  "Show the block burst operations dialog"
  
  ;; Get current drawing information
  (setq block-count (count-blocks))
  (setq block-names (get-all-block-names))
  
  ;; Generate DCL content
  (setq dcl-content (generate-block-burst-dcl))
  
  ;; Write to temporary DCL file
  (setq temp-dcl-file (write-temp-dcl dcl-content))
  
  (if (not temp-dcl-file)
    (progn
      (princ "\n✗ ERROR: Could not create dynamic dialog.")
      (exit)
    )
  )
  
  ;; Load the dynamically generated DCL
  (setq dcl_id (load_dialog temp-dcl-file))
  (if (not (new_dialog "block_burst_dialog" dcl_id))
    (progn
      (princ "\n✗ ERROR: Could not load dynamic dialog.")
      (unload_dialog dcl_id)
      (vl-file-delete temp-dcl-file)
      (exit)
    )
  )
  
  ;; Set status text
  (set_tile "status_text" 
    (strcat 
      "Block Definitions: " (itoa (length block-names))
      "  |  Block References: " (itoa block-count)
    )
  )
  
  ;; Set up action tiles
  (action_tile "override_btn" 
    "(setq operation \"OVERRIDE\") (done_dialog 1)"
  )
  
  (action_tile "burst_btn" 
    "(setq operation \"BURST\") (done_dialog 2)"
  )
  
  (action_tile "both_btn" 
    "(setq operation \"BOTH\") (done_dialog 3)"
  )
  
  (action_tile "cancel" 
    "(done_dialog 0)"
  )
  
  ;; Show dialog and get result
  (setq result (start_dialog))
  (unload_dialog dcl_id)
  
  ;; Clean up temporary file
  (vl-file-delete temp-dcl-file)
  
  ;; Perform selected operation
  (cond
    ((= result 1)
     ;; Override block explodability
     (override-block-explodability)
    )
    ((= result 2)
     ;; BURST all blocks
     (burst-all-blocks)
    )
    ((= result 3)
     ;; Both operations
     (perform-both-operations)
    )
    (T
     ;; Cancelled
     (princ "\nOperation cancelled.")
     (princ "\n")
    )
  )
)

;; ===== MAIN COMMAND =====

(defun C:BLOCKBURST (/ )
  "Main command to launch block burst operations dialog"
  (princ "\n")
  (princ "\n╔════════════════════════════════════════════════════════════╗")
  (princ "\n║          BLOCK BURST OPERATIONS                            ║")
  (princ "\n╚════════════════════════════════════════════════════════════╝")
  (princ "\n")
  
  ;; Show the dialog
  (show-block-burst-dialog)
  
  (princ)
)

;; Short command aliases
(defun C:BB () 
  "Shortcut for BLOCKBURST command"
  (C:BLOCKBURST)
)

(defun C:BBURST () 
  "Alternative shortcut for BLOCKBURST command"
  (C:BLOCKBURST)
)

;; ===== STARTUP MESSAGE =====

(princ "\n========================================")
(princ "\nBLOCK BURST OPERATIONS Loaded")
(princ "\n")
(princ "\nAvailable commands:")
(princ "\n  BLOCKBURST - Full command name")
(princ "\n  BB         - Quick shortcut")
(princ "\n  BBURST     - Alternative shortcut")
(princ "\n")
(princ "\nFeatures:")
(princ "\n  • Dynamic DCL dialog (no .dcl file needed)")
(princ "\n  • Override block explodability")
(princ "\n  • BURST blocks while preserving layers")
(princ "\n  • Combined operations")
(princ "\n")
(princ "\nNOTE: BURST command requires Express Tools")
(princ "\n========================================")
(princ)
