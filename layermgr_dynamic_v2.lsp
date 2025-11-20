;; ===== LAYERMGR_DYNAMIC_V2.LSP - Fully Dynamic Dialog Height Version =====
;; Enhanced version that generates DCL dynamically based on layer count

;; Global variables for dialog management
(setq *all-layers* nil)
(setq *filtered-layers* nil)
(setq *selected-objects* nil)
(setq *selected-layer-names* nil)
(setq *current-search* "")

(defun filter-layers (search-term layers / filtered)
  "Filter layer list based on search term"
  (setq filtered '())
  (foreach layer layers
    (if (or (= search-term "")
            (vl-string-search (strcase search-term) (strcase layer)))
      (setq filtered (cons layer filtered))
    )
  )
  (reverse filtered)
)

(defun create-new-layer (layer-name / new-layer)
  "Create a new layer with specified name"
  (if (not (tblsearch "LAYER" layer-name))
    (progn
      (setq new-layer (list 
        (cons 0 "LAYER")
        (cons 100 "AcDbSymbolTableRecord")
        (cons 100 "AcDbLayerTableRecord")
        (cons 2 layer-name)
        (cons 70 0)
        (cons 62 7)
        (cons 6 "Continuous")
        (cons 290 1)
        (cons 370 -3)
      ))
      (if (entmake new-layer)
        (progn
          (princ (strcat "\nCreated new layer: " layer-name))
          (setq *all-layers* (cons layer-name *all-layers*))
          (setq *all-layers* (vl-sort *all-layers* '<))
          T
        )
        (progn
          (princ (strcat "\nError creating layer: " layer-name))
          nil
        )
      )
    )
    (progn
      (princ (strcat "\nLayer already exists: " layer-name))
      T
    )
  )
)

(defun update-search-status (search-term)
  "Update search status display"
  (setq result-count (length *filtered-layers*))
  (cond
    ((= search-term "")
     (set_tile "search_status" (strcat "Showing all " (itoa result-count) " layers"))
     (mode_tile "create_layer_btn" 1)
    )
    ((> result-count 0)
     (set_tile "search_status" (strcat "Showing " (itoa result-count) " layers matching \"" search-term "\""))
     (mode_tile "create_layer_btn" 1)
    )
    (T
     (set_tile "search_status" (strcat "No matches for \"" search-term "\" - Click to create this layer"))
     (mode_tile "create_layer_btn" 0)
    )
  )
)

(defun update-layer-list (search-term)
  "Update the layer list based on search term with real-time feedback"
  (setq *current-search* search-term)
  (setq *filtered-layers* (filter-layers search-term *all-layers*))
  
  (update-search-status search-term)
  
  (start_list "layer_list")
  (foreach layer *filtered-layers*
    (if (member layer *selected-layer-names*)
      (add_list (strcat "► " layer))
      (add_list layer)
    )
  )
  (end_list)
  (update-selection-info)
)

(defun update-selection-info ()
  "Update selection info text and button states"
  (setq selected-count (length *selected-layer-names*))
  
  ;; Copy to All button is always enabled (no layer selection needed)
  (mode_tile "copy_all_btn" 0)
  
  (cond 
    ((= selected-count 0) 
     (set_tile "selection_info" "No layers selected - Click layers to select, or use Copy to All")
     (mode_tile "copy_btn" 1)
     (mode_tile "move_btn" 1)
    )
    ((= selected-count 1) 
     (set_tile "selection_info" 
       (strcat "1 layer selected: " (car *selected-layer-names*) " - Copy or Move available"))
     (mode_tile "copy_btn" 0)
     (mode_tile "move_btn" 0)
    )
    (T 
     (set_tile "selection_info" 
       (strcat (itoa selected-count) " layers selected - Only Copy available"))
     (mode_tile "copy_btn" 0)
     (mode_tile "move_btn" 1)
    )
  )
)

(defun toggle-layer-selection ()
  "Toggle selection of current layer in list"
  (setq selected-index (get_tile "layer_list"))
  (if (and selected-index (/= selected-index ""))
    (progn
      (setq idx (atoi selected-index))
      (if (< idx (length *filtered-layers*))
        (progn
          (setq layer-name (nth idx *filtered-layers*))
          (if (member layer-name *selected-layer-names*)
            (setq *selected-layer-names* (vl-remove layer-name *selected-layer-names*))
            (setq *selected-layer-names* (cons layer-name *selected-layer-names*))
          )
          (update-layer-list (get_tile "search_box"))
        )
      )
    )
  )
)

(defun create-layer-from-search ()
  "Create new layer from current search term"
  (setq search-term (get_tile "search_box"))
  (if (and search-term (/= search-term ""))
    (progn
      (princ (strcat "\nAttempting to create layer: \"" search-term "\""))
      
      (setq clean-name (vl-string-translate " <>|\"/\\:;*?=," "____________" search-term))
      (if (/= clean-name search-term)
        (progn
          (alert (strcat "Invalid characters replaced.\nOriginal: " search-term "\nCleaned: " clean-name))
          (setq search-term clean-name)
        )
      )
      
      (if (create-new-layer search-term)
        (progn
          (setq *selected-layer-names* (cons search-term *selected-layer-names*))
          (set_tile "search_box" "")
          (update-layer-list "")
          (princ (strcat "\n✓ Layer \"" search-term "\" created and auto-selected!"))
        )
        (alert (strcat "Failed to create layer: " search-term))
      )
    )
    (alert "Please enter a layer name in the search box first.")
  )
)

(defun get-selected-layers ()
  "Get list of selected layer names"
  *selected-layer-names*
)

(defun copy-objects-to-layers (objects target-layers / ent new-ent count)
  "Copy objects to specified layers"
  (setq count 0)
  (foreach layer target-layers
    (foreach obj objects
      (if (and obj (setq ent (entget obj)))
        (progn
          (setq new-ent (subst (cons 8 layer) (assoc 8 ent) ent))
          (if (entmake new-ent)
            (setq count (1+ count))
          )
        )
      )
    )
  )
  (princ (strcat "\n" (itoa count) " objects copied to " (itoa (length target-layers)) " layers."))
)

(defun copy-objects-to-all-layers (objects / ent new-ent count layer-count)
  "Copy objects to all available layers"
  (setq count 0)
  (setq layer-count (length *all-layers*))
  (princ (strcat "\nCopying " (itoa (length objects)) " objects to " (itoa layer-count) " layers..."))
  (foreach layer *all-layers*
    (foreach obj objects
      (if (and obj (setq ent (entget obj)))
        (progn
          (setq new-ent (subst (cons 8 layer) (assoc 8 ent) ent))
          (if (entmake new-ent)
            (setq count (1+ count))
          )
        )
      )
    )
  )
  (princ (strcat "\n✓ " (itoa count) " objects copied to all " (itoa layer-count) " layers."))
)

(defun move-objects-to-layer (objects target-layer / ent new-ent count)
  "Move objects to specified layer"
  (setq count 0)
  (foreach obj objects
    (if (and obj (setq ent (entget obj)))
      (progn
        (setq new-ent (subst (cons 8 target-layer) (assoc 8 ent) ent))
        (if (entmod new-ent)
          (setq count (1+ count))
        )
      )
    )
  )
  (princ (strcat "\n" (itoa count) " objects moved to layer " target-layer "."))
)

(defun build-layer-list (current-layer / layers layer-name)
  "Build list of available layers (excluding current layer)"
  (setq layers '())
  (setq layer-name (tblnext "LAYER" T))
  (while layer-name
    (if (/= (cdr (assoc 2 layer-name)) current-layer)
      (setq layers (cons (cdr (assoc 2 layer-name)) layers))
    )
    (setq layer-name (tblnext "LAYER"))
  )
  
  (setq layers 
    (vl-remove-if 
      '(lambda (x) 
         (setq layer-name (tblsearch "LAYER" x))
         (or (> (logand (cdr (assoc 70 layer-name)) 1) 0)
             (> (logand (cdr (assoc 70 layer-name)) 4) 0))
       ) 
      layers
    )
  )
  (reverse layers)
)

(defun calculate-dialog-height (layer-count / screen-height max-height min-height overhead-lines optimal-height)
  "Calculate optimal dialog height based on layer count and screen size"
  ;; Get screen dimensions using system variables
  ;; SCREENSIZE returns (width height) in pixels
  (setq screen-height (cadr (getvar "SCREENSIZE")))
  
  ;; Convert pixels to approximate dialog units (rough estimate: 1 line ≈ 20 pixels)
  ;; Account for dialog overhead (title bar, buttons, other controls)
  (setq max-lines (fix (/ screen-height 20.0)))  ; Convert to lines
  (setq overhead-lines 12)  ; Approximate overhead for other dialog elements
  (setq max-height (- max-lines overhead-lines))
  
  ;; Set reasonable min and max bounds
  (setq min-height 5)    ; Minimum height for usability
  (if (< max-height 40)  ; Cap at reasonable maximum
    (setq max-height max-height)
    (setq max-height 40)
  )
  
  ;; Calculate optimal height
  (setq optimal-height (+ layer-count 1))  ; Add 1 for a little padding
  
  ;; Apply bounds
  (cond
    ((< optimal-height min-height) min-height)
    ((> optimal-height max-height) max-height)
    (T optimal-height)
  )
)

(defun generate-dynamic-dcl (height / dcl-content)
  "Generate DCL content with dynamic height"
  (setq dcl-content 
    (strcat
      "// Dynamically generated dialog for layer selector\n"
      "layer_selector_temp : dialog {\n"
      "    label = \"Copy/Move Objects to Layers\";\n"
      "    width = 50;\n"
      "    \n"
      "    : boxed_column {\n"
      "        label = \"Layer Selection\";\n"
      "        \n"
      "        : edit_box {\n"
      "            key = \"search_box\";\n"
      "            label = \"Search layers:\";\n"
      "            edit_width = 30;\n"
      "        }\n"
      "        \n"
      "        : text {\n"
      "            key = \"search_status\";\n"
      "            label = \"\";\n"
      "        }\n"
      "        \n"
      "        : row {\n"
      "            : button {\n"
      "                key = \"create_layer_btn\";\n"
      "                label = \"Create Layer from Search\";\n"
      "                width = 25;\n"
      "            }\n"
      "        }\n"
      "        \n"
      "        : list_box {\n"
      "            key = \"layer_list\";\n"
      "            label = \"Available Layers (Click to select multiple):\";\n"
      "            height = " (itoa height) ";\n"
      "            width = 40;\n"
      "            fixed_width = true;\n"
      "            allow_accept = true;\n"
      "        }\n"
      "        \n"
      "        : text {\n"
      "            key = \"selection_info\";\n"
      "            label = \"No layers selected\";\n"
      "        }\n"
      "    }\n"
      "    \n"
      "    : row {\n"
      "        : button {\n"
      "            key = \"copy_btn\";\n"
      "            label = \"Copy\";\n"
      "            width = 10;\n"
      "        }\n"
      "        : button {\n"
      "            key = \"copy_all_btn\";\n"
      "            label = \"Copy to All\";\n"
      "            width = 12;\n"
      "        }\n"
      "        : button {\n"
      "            key = \"move_btn\";\n"
      "            label = \"Move\";\n"
      "            width = 10;\n"
      "        }\n"
      "        : button {\n"
      "            key = \"cancel\";\n"
      "            label = \"Cancel\";\n"
      "            width = 10;\n"
      "            is_cancel = true;\n"
      "        }\n"
      "    }\n"
      "}\n"
    )
  )
  dcl-content
)

(defun write-temp-dcl (dcl-content / temp-path temp-file result)
  "Write DCL content to a temporary file and return the file path"
  ;; Get temporary directory path
  (setq temp-path (getvar "TEMPPREFIX"))
  (setq temp-file (strcat temp-path "layer_selector_temp.dcl"))
  
  ;; Open file for writing
  (setq f (open temp-file "w"))
  (if f
    (progn
      (write-line dcl-content f)
      (close f)
      (setq result temp-file)
    )
    (progn
      (princ "\nError: Could not create temporary DCL file.")
      (setq result nil)
    )
  )
  result
)

(defun show-layer-dialog (objects / dcl_id result current-layer target-layers operation dialog-height dcl-content temp-dcl-file)
  "Show the layer selection dialog with truly dynamic height"
  (setq current-layer (getvar "CLAYER"))
  (setq *all-layers* (build-layer-list current-layer))
  (setq *filtered-layers* *all-layers*)
  (setq *selected-objects* objects)
  
  ;; Calculate optimal dialog height based on layer count
  (setq dialog-height (calculate-dialog-height (length *all-layers*)))
  (princ (strcat "\nSetting dialog list height to: " (itoa dialog-height) " lines for " (itoa (length *all-layers*)) " layers"))
  
  ;; Generate DCL with dynamic height
  (setq dcl-content (generate-dynamic-dcl dialog-height))
  
  ;; Write to temporary DCL file
  (setq temp-dcl-file (write-temp-dcl dcl-content))
  
  (if (not temp-dcl-file)
    (progn
      (princ "\nError: Could not create dynamic dialog.")
      (exit)
    )
  )
  
  ;; Load the dynamically generated DCL
  (setq dcl_id (load_dialog temp-dcl-file))
  (if (not (new_dialog "layer_selector_temp" dcl_id))
    (progn
      (princ "\nError: Could not load dynamic dialog.")
      (exit)
    )
  )
  
  ;; Initialize dialog state
  (setq *selected-layer-names* nil)
  (setq *current-search* "")
  
  ;; Update initial display
  (update-layer-list "")
  (set_tile "layer_list" "")
  (update-selection-info)
  
  ;; Set up action tiles
  (action_tile "search_box" "(update-layer-list (get_tile \"search_box\"))")
  (action_tile "layer_list" "(toggle-layer-selection)")
  (action_tile "create_layer_btn" "(create-layer-from-search)")
  (action_tile "copy_btn" "(setq operation \"COPY\") (done_dialog 1)")
  (action_tile "copy_all_btn" "(setq operation \"COPY_ALL\") (done_dialog 1)")
  (action_tile "move_btn" "(setq operation \"MOVE\") (done_dialog 1)")
  (action_tile "cancel" "(done_dialog 0)")
  
  (setq result (start_dialog))
  (unload_dialog dcl_id)
  
  ;; Clean up temporary file (optional, as temp files get cleaned eventually)
  (vl-file-delete temp-dcl-file)
  
  (if (= result 1)
    (progn
      (cond 
        ((= operation "COPY_ALL")
         ;; Copy to all layers regardless of selection
         (copy-objects-to-all-layers objects)
        )
        ((= operation "COPY")
         ;; Copy to selected layers
         (setq target-layers (get-selected-layers))
         (if (> (length target-layers) 0)
           (copy-objects-to-layers objects target-layers)
           (princ "\nNo layers selected.")
         )
        )
        ((= operation "MOVE")
         ;; Move to selected layer
         (setq target-layers (get-selected-layers))
         (if (= (length target-layers) 1)
           (move-objects-to-layer objects (car target-layers))
           (princ "\nMove operation requires exactly one layer selection.")
         )
        )
      )
    )
    (princ "\nOperation cancelled.")
  )
)

(defun C:LAYERMGR (/ ss ent-list i)
  "Enhanced layer copy/move command with fully dynamic dialog interface"
  
  ;; First check for implied selection (already selected objects)
  (setq ss (ssget "_I"))
  
  ;; If no implied selection or empty selection, prompt for selection
  (if (or (not ss) (= (sslength ss) 0))
    (progn
      (princ "\nSelect objects to copy/move to layers: ")
      (setq ss (ssget))
    )
    ;; If we have a pre-selection, notify the user
    (princ (strcat "\nUsing current selection of " (itoa (sslength ss)) " objects."))
  )
  
  ;; Process the selection if we have one
  (if (and ss (> (sslength ss) 0))
    (progn
      (if (not (ssget "_I"))
        (princ (strcat "\n" (itoa (sslength ss)) " objects selected."))
      )
      
      ;; Convert selection set to entity list
      (setq ent-list '())
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent-list (cons (ssname ss i) ent-list))
        (setq i (1+ i))
      )
      
      ;; Show the dialog
      (show-layer-dialog ent-list)
    )
    (princ "\nNo objects selected.")
  )
  (princ)
)

;; Short command alias
(defun C:LM () 
  "Shortcut for LAYERMGR command"
  (C:LAYERMGR)
)

;; Alternative short aliases
(defun C:LMG () 
  "Alternative shortcut for LAYERMGR command"
  (C:LAYERMGR)
)

(defun C:LMGR () 
  "Another shortcut for LAYERMGR command"
  (C:LAYERMGR)
)

(princ "\n========================================")
(princ "\nLAYERMGR command loaded (Dynamic Height Version)")
(princ "\n")
(princ "\nAvailable commands:")
(princ "\n  LAYERMGR - Full command name")
(princ "\n  LM       - Quick shortcut (recommended)")
(princ "\n  LMG      - Alternative shortcut")
(princ "\n  LMGR     - Alternative shortcut")
(princ "\n")
(princ "\nFeatures:")
(princ "\n  • Works with pre-selected objects")
(princ "\n  • Dynamic dialog height based on layer count")
(princ "\n  • Copy to All button for quick duplication")
(princ "\n========================================")
(princ)
