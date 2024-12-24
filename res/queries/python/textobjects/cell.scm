;; inherits: python
;; extends

(module
  (comment) @cellseparator
  (_) @_noncellseparator
  (comment) @cellseparator
  (#not-match-percent-separator? @_noncellseparator)
  (#match-percent-separator? @cellseparator)
  )



