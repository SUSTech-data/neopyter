;; inherits: python
;; extends

; vanilla script, without separator
(module
  .
  (_)+ @cellcontent
  .
  (#match-cell-content? @cellcontent)
)

; first cell, follow a separator
(module
  .
  _+ @cellcontent
  .
  (comment) @_cellseparator
  (#match-cell-content? @cellcontent)
  (#match-percent-separator? @_cellseparator)
)

; cell between two separator
(module
  (comment) @_cellseparator
  .
  (_)+ @cellcontent
  .
  (comment) @_cellseparator
  (#match-cell-content? @cellcontent)
  (#match-percent-separator? @_cellseparator)
)


; latest cell after separator
(module
  (comment) @_cellseparator
  .
  _+ @cellcontent
  .
  (#match-cell-content? @cellcontent)
  (#match-percent-separator? @_cellseparator)
)

