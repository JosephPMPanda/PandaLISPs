;;; region_to_pline.lsp
;;; Convert AutoCAD Region entities to Polyline entities
;;; Author: PandaLISP Collection
;;; Description: Converts multiple region entities to polylines in a single pass
;;;              by extracting boundary curves and creating polylines

(defun c:R2P ( / ss i ent obj curves pline-created delete-opt)
  ;; Main command to convert regions to polylines
  (princ "\nREGION TO POLYLINE CONVERTER")
  (princ "\n============================\n")
  
  ;; Get selection set of regions
  (setq ss (ssget '((0 . "REGION"))))
  
  (if ss
    (progn
      ;; Ask user if they want to delete original regions
      (initget "Yes No")
      (setq delete-opt (getkword "\nDelete original regions after conversion? [Yes/No] <No>: "))
      (if (not delete-opt) (setq delete-opt "No"))
      
      ;; Initialize counter
      (setq i 0)
      (setq pline-created 0)
      
      ;; Process each region
      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq obj (vlax-ename->vla-object ent))
        
        ;; Try to explode the region to get boundary curves
        (if (vl-catch-all-error-p
              (setq curves (vl-catch-all-apply 'vlax-invoke (list obj 'Explode))))
          (progn
            (princ (strcat "\nFailed to process region: " (vla-get-handle obj)))
          )
          (progn
            ;; Process the exploded curves
            (foreach curve curves
              ;; Check if the curve is valid
              (if (and curve
                       (vlax-property-available-p curve 'ObjectName))
                (progn
                  ;; Convert based on curve type
                  (cond
                    ;; If it's already a polyline, keep it
                    ((wcmatch (vla-get-ObjectName curve) "*Polyline*")
                     (setq pline-created (1+ pline-created))
                    )
                    
                    ;; If it's a line, arc, or circle - create polyline
                    ((or (= (vla-get-ObjectName curve) "AcDbLine")
                         (= (vla-get-ObjectName curve) "AcDbArc")
                         (= (vla-get-ObjectName curve) "AcDbCircle"))
                     (if (region-curve-to-pline curve)
                       (setq pline-created (1+ pline-created))
                     )
                    )
                    
                    ;; For other curve types, try to convert
                    (t
                     (if (region-curve-to-pline curve)
                       (setq pline-created (1+ pline-created))
                     )
                    )
                  )
                )
              )
            )
            
            ;; Delete original region if requested
            (if (= delete-opt "Yes")
              (vla-delete obj)
            )
          )
        )
        
        ;; Increment counter
        (setq i (1+ i))
      )
      
      ;; Report results
      (princ (strcat "\n\nCONVERSION COMPLETE"
                     "\n==================="
                     "\nRegions processed: " (itoa (sslength ss))
                     "\nPolylines created: " (itoa pline-created)))
      (if (= delete-opt "Yes")
        (princ "\nOriginal regions deleted.")
        (princ "\nOriginal regions retained.")
      )
    )
    (princ "\nNo regions selected.")
  )
  (princ)
)

(defun region-curve-to-pline (curve / pts pline start-pt end-pt)
  ;; Helper function to convert a curve to polyline
  (vl-catch-all-apply
    '(lambda ()
       (cond
         ;; Handle Line
         ((= (vla-get-ObjectName curve) "AcDbLine")
          (setq start-pt (vlax-get curve 'StartPoint))
          (setq end-pt (vlax-get curve 'EndPoint))
          
          ;; Create lightweight polyline
          (setq pline (vlax-invoke 
                        (vla-get-ModelSpace 
                          (vla-get-ActiveDocument (vlax-get-acad-object)))
                        'AddLightWeightPolyline
                        (vlax-make-variant
                          (vlax-safearray-fill
                            (vlax-make-safearray vlax-vbDouble '(0 . 3))
                            (list (car start-pt) (cadr start-pt)
                                  (car end-pt) (cadr end-pt))))))
          
          ;; Copy properties
          (vla-put-Layer pline (vla-get-Layer curve))
          (vla-put-Color pline (vla-get-Color curve))
          (vla-put-Linetype pline (vla-get-Linetype curve))
          
          ;; Delete the original curve
          (vla-delete curve)
          t  ; Return success
         )
         
         ;; Handle Arc
         ((= (vla-get-ObjectName curve) "AcDbArc")
          (setq pline (arc-to-pline curve))
          (if pline
            (progn
              ;; Copy properties
              (vla-put-Layer pline (vla-get-Layer curve))
              (vla-put-Color pline (vla-get-Color curve))
              (vla-put-Linetype pline (vla-get-Linetype curve))
              
              ;; Delete the original curve
              (vla-delete curve)
              t  ; Return success
            )
            nil
          )
         )
         
         ;; Handle Circle
         ((= (vla-get-ObjectName curve) "AcDbCircle")
          (setq pline (circle-to-pline curve))
          (if pline
            (progn
              ;; Copy properties
              (vla-put-Layer pline (vla-get-Layer curve))
              (vla-put-Color pline (vla-get-Color curve))
              (vla-put-Linetype pline (vla-get-Linetype curve))
              
              ;; Delete the original curve
              (vla-delete curve)
              t  ; Return success
            )
            nil
          )
         )
         
         ;; Default: already a polyline or other supported type
         (t nil)
       )
     )
    nil)
)

(defun arc-to-pline (arc / center radius start-angle end-angle pts num-segments i angle pt pline coords)
  ;; Convert an arc to a polyline
  (setq center (vlax-get arc 'Center))
  (setq radius (vla-get-Radius arc))
  (setq start-angle (vla-get-StartAngle arc))
  (setq end-angle (vla-get-EndAngle arc))
  
  ;; Calculate number of segments (more segments for larger arcs)
  (setq num-segments (max 8 (fix (* 16 (/ (abs (- end-angle start-angle)) pi)))))
  
  ;; Generate points along the arc
  (setq pts nil)
  (setq i 0)
  
  ;; Handle arc direction
  (if (< end-angle start-angle)
    (setq end-angle (+ end-angle (* 2 pi)))
  )
  
  (repeat (1+ num-segments)
    (setq angle (+ start-angle (* (/ (- end-angle start-angle) num-segments) i)))
    (setq pt (list (+ (car center) (* radius (cos angle)))
                   (+ (cadr center) (* radius (sin angle)))))
    (setq pts (append pts pt))
    (setq i (1+ i))
  )
  
  ;; Create polyline from points
  (if pts
    (progn
      (setq coords (vlax-make-variant
                     (vlax-safearray-fill
                       (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length pts))))
                       pts)))
      
      (setq pline (vlax-invoke
                    (vla-get-ModelSpace
                      (vla-get-ActiveDocument (vlax-get-acad-object)))
                    'AddLightWeightPolyline
                    coords))
      pline
    )
    nil
  )
)

(defun circle-to-pline (circle / center radius pts num-segments i angle pt pline coords)
  ;; Convert a circle to a closed polyline
  (setq center (vlax-get circle 'Center))
  (setq radius (vla-get-Radius circle))
  
  ;; Number of segments for circle approximation
  (setq num-segments 32)
  
  ;; Generate points around the circle
  (setq pts nil)
  (setq i 0)
  
  (repeat num-segments
    (setq angle (* 2 pi (/ i (float num-segments))))
    (setq pt (list (+ (car center) (* radius (cos angle)))
                   (+ (cadr center) (* radius (sin angle)))))
    (setq pts (append pts pt))
    (setq i (1+ i))
  )
  
  ;; Create closed polyline from points
  (if pts
    (progn
      (setq coords (vlax-make-variant
                     (vlax-safearray-fill
                       (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length pts))))
                       pts)))
      
      (setq pline (vlax-invoke
                    (vla-get-ModelSpace
                      (vla-get-ActiveDocument (vlax-get-acad-object)))
                    'AddLightWeightPolyline
                    coords))
      
      ;; Close the polyline
      (vla-put-Closed pline :vlax-true)
      pline
    )
    nil
  )
)

;;; Alternative command with automatic selection
(defun c:R2PALL ( / ss)
  ;; Convert ALL regions in drawing to polylines
  (princ "\nConverting ALL regions in drawing to polylines...")
  
  ;; Select all regions in the drawing
  (setq ss (ssget "X" '((0 . "REGION"))))
  
  (if ss
    (progn
      (princ (strcat "\nFound " (itoa (sslength ss)) " regions."))
      ;; Set selection for main command
      (sssetfirst nil ss)
      ;; Call main command
      (c:R2P)
    )
    (princ "\nNo regions found in drawing.")
  )
  (princ)
)

;;; Load-time message
(princ "\n===============================================")
(princ "\nREGION TO POLYLINE CONVERTER LOADED")
(princ "\n===============================================")
(princ "\nCommands available:")
(princ "\n  R2P    - Convert selected regions to polylines")
(princ "\n  R2PALL - Convert ALL regions in drawing")
(princ "\n")
(princ "\nThis tool will explode region entities and")
(princ "\nconvert their boundary curves into polylines.")
(princ "\n===============================================\n")

(princ)
