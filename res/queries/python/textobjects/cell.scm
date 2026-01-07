
;; inherits: python
;; extends

; vanilla script, without separator
(module
  .
  (_)+ @cell
  .
  (#match-cell-content? @cell)
)

; first cell, follow a separator
(module
  .
  _+ @cell
  .
  (comment) @_cellseparator
  (#match-cell-content? @cell)
  (#match-percent-separator? @_cellseparator)
)

; cell between two separator
(module
    (comment) @_cellseparator @cell
    (_)* @_cellcontent @cell
    (comment) @_cellseparator
    (#match-cell-content? @_cellcontent)
    (#match-percent-separator? @_cellseparator)
)


; latest cell after separator
(module
  (
    (comment) @_cellseparator @cell
    (_)* @_cellcontent @cell
    .
    (#match-cell-content? @_cellcontent)
    (#match-percent-separator? @_cellseparator)
  )
)


