;; inherits: r
;; extends

; code cell without content
(program
  (comment) @cellseparator
  . (string
      (string_content) @injection.content
      (#set! injection.language "markdown")
    )
  (#match-percent-separator? @cellseparator "markdown")
  )
