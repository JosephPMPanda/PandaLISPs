;; ===== LAYERMGR.LSP - CLEAN VERSION WITHOUT SYNTAX ERRORS =====

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
        (cons 390 "5")
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
  
  (cond 
    ((= selected-count 0) 
     (set_tile "selection_info" "No layers selected - Click layers to select")
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

(defun show-layer-dialog (objects / dcl_id result current-layer target-layers operation)
  "Show the layer selection dialog"
  (setq current-layer (getvar "CLAYER"))
  (setq *all-layers* (build-layer-list current-layer))
  (setq *filtered-layers* *all-layers*)
  (setq *selected-objects* objects)
  
  (setq dcl_id (load_dialog "layer_selector.dcl"))
  (if (not (new_dialog "layer_selector" dcl_id))
    (progn
      (princ "\nError: Could not load dialog. Make sure layer_selector.dcl is in AutoCAD search path.")
      (exit)
    )
  )
  
  (setq *selected-layer-names* nil)
  (setq *current-search* "")
  (update-layer-list "")
  (set_tile "layer_list" "")
  (update-selection-info)
  
  (action_tile "search_box" "(update-layer-list (get_tile \"search_box\"))")
  (action_tile "layer_list" "(toggle-layer-selection)")
  (action_tile "create_layer_btn" "(create-layer-from-search)")
  (action_tile "copy_btn" "(setq operation \"COPY\") (done_dialog 1)")
  (action_tile "move_btn" "(setq operation \"MOVE\") (done_dialog 1)")
  (action_tile "cancel" "(done_dialog 0)")
  
  (setq result (start_dialog))
  (unload_dialog dcl_id)
  
  (if (= result 1)
    (progn
      (setq target-layers (get-selected-layers))
      (if (> (length target-layers) 0)
        (cond 
          ((= operation "COPY")
           (copy-objects-to-layers objects target-layers)
          )
          ((= operation "MOVE")
           (if (= (length target-layers) 1)
             (move-objects-to-layer objects (car target-layers))
             (princ "\nMove operation requires exactly one layer selection.")
           )
          )
        )
        (princ "\nNo layers selected.")
      )
    )
    (princ "\nOperation cancelled.")
  )
)

(defun C:LAYERMGR (/ ss ent-list i)
  "Enhanced layer copy/move command with dialog interface"
  
  (command)
  
  (cond 
    ((setq ss (ssget "_I"))
     (if (= (sslength ss) 0)
       (setq ss nil)
     )
    )
  )
  
  (if (not ss)
    (progn
      (princ "\nSelect objects to copy/move to layers: ")
      (setq ss (ssget))
    )
  )
  
  (if ss
    (progn
      (princ (strcat "\n" (itoa (sslength ss)) " objects selected."))
      
      (setq ent-list '())
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent-list (cons (ssname ss i) ent-list))
        (setq i (1+ i))
      )
      
      (show-layer-dialog ent-list)
    )
    (princ "\nNo objects selected.")
  )
  (princ)
)

(princ "\nLAYERMGR command loaded. Type LAYERMGR to copy/move objects with layer selection dialog.")
(princ "\nMake sure 'layer_selector.dcl' file is in AutoCAD search path.")
(princ)