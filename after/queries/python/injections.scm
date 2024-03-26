;; extends

(
 [
  ((comment) @cellseparator.code
             (#lua-match? @cellseparator.code "^# %%%%$"))
  ((comment) @cellseparator.code
             (#match? @cellseparator.code "^# [%]{2} ([[]\\w\+[]])\@!"))
  ] @_start
 (comment) @_end
 (#make-range! "cell.code" @_start @_end)
 )


((comment) @cellseparator.markdown
           . (expression_statement
               (string 
                 (string_start) @cellborder.markdown
                 (string_content) @cellcontent.markdown @injection.content
                 (string_end) @cellborder.markdown
                 (#set! injection.language "markdown")
                 )
               )? @cellbody.markdown
           (#match? @cellseparator.markdown "^# [%]{2} [[]\<markdown>|\<md>[]].*$")
           (#match? @cellbody.markdown "^[\"']{3}.*[\"']{3}$"))
