;; inherits: python
;; extends

; code cell without content
(module
  (comment) @cellseparator
  . (expression_statement
      (string 
        (string_start)
        (string_content) @injection.content
        (string_end)
        (#set! injection.language "markdown"))
      )
  (#match-percent-separator? @cellseparator "markdown")
  )


