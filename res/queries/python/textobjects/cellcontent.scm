;; inherits: python
;; extends

; vanilla script, without separator
(module
  .
  (_) @_nonseparator @_start @_end
  .
  (_)* @_nonseparator @_end
  .
  (#match-cell-content? @_nonseparator)
  (#make-range! "cellcontent" @_start @_end)
)

; first cell, follow a separator
(module
  .
  (_) @_nonseparator @_start @_end
  .
  (_)* @_nonseparator @_end
  .
  (comment) @_cellseparator
  (#match-cell-content? @_nonseparator)
  (#match-percent-separator? @_cellseparator)
  (#make-range! "cellcontent" @_start @_end)
)

; cell between two separator
(module
  (comment) @_cellseparator
  .
  (_) @_nonseparator @_start @_end
  (_)* @_nonseparator @_end
  .
  (comment) @_cellseparator
  (#match-cell-content? @_nonseparator)
  (#match-percent-separator? @_cellseparator)
  (#make-range! "cellcontent" @_start @_end)
)


; latest cell after separator
(module
  (comment) @_cellseparator
  .
  (_) @_nonseparator @_start @_end
  (_)* @_nonseparator @_end
  .
  (#match-cell-content? @_nonseparator)
  (#match-percent-separator? @_cellseparator)
  (#make-range! "cellcontent" @_start @_end)
)

