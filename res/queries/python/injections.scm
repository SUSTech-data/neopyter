;; inherits: python
;; extends

; code cell without content
(module
  (comment) @cellseparator
  . (expression_statement
      (string 
        (string_start) @cellborder.markdown
        (string_content) @cellcontent.markdown @injection.content
        (string_end) @cellborder.markdown
        (#set! injection.language "markdown")
        )
      )? @cellbody.markdown
  (#match-cellseparator? @cellseparator "markdown")
)


