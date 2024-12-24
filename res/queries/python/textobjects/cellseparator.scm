;; inherits: python
;; extends

(module
  (comment) @cellseparator.code
  (#match-percent-separator? @cellseparator.code "code"))

(module
  (comment) @cellseparator.markdown
  (#match-percent-separator? @cellseparator.markdown "markdown"))


(module
  (comment) @cellseparator.raw
  (#match-percent-separator? @cellseparator.raw "raw"))
