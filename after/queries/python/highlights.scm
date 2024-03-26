;; extends

; first cell without separator
(module
  .
  (_) @_non_header @_start
  .
  (_)* @_non_header @_end 
  .

  ((comment) @_cellseparator
             (#match? @_cellseparator "^# [%][%](( |\\w).*)?$"))?
  (#not-any-match? @_non_header "^# [%][%](( |\\w).*)?$"))

; code cell without content
(module
  ((comment) @cellseparator.code
             (#match? @cellseparator.code "^# [%][%]( .*)?$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](markdown>|md)[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[]raw[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](\<markdown>|\<md>|\<raw>|\<code>)\@!\\w\+[]].*$")
             ) @_start @_end
  .
  ((comment) @_cellseparator
             (#match? @_cellseparator "^# [%][%](( |\\w).*)?$"))
  )


; cell with one expression
(module
  ((comment) @cellseparator.code
             (#match? @cellseparator.code "^# [%][%]( .*)?$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](markdown>|md)[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[]\<raw>[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](\<markdown>|\<md>|\<raw>|\<code>)\@!\\w\+[]].*$")
             ) @_start
  .
  (_) @_non_header @_innerstart @_end
  .
  ((comment) @_cellseparator
             (#match? @_cellseparator "^# [%][%](( |\\w).*)?$"))
  (#not-any-match? @_non_header "^# [%][%](( |\\w).*)?$"))

; cell with two+ expression
(module
  ((comment) @cellseparator.code
             (#match? @cellseparator.code "^# [%][%]( .*)?$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](markdown>|md)[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[]\<raw>[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](\<markdown>|\<md>|\<raw>|\<code>)\@!\\w\+[]].*$")
             ) @_start @_end @_innerstart
  .
  (_) @_non_header @_innerstart @_end
  .
  (_)+ @_non_header @_end
  .
  ((comment) @_cellseparator
             (#match? @_cellseparator "^# [%][%](( |\\w).*)?$"))
  (#not-any-match? @_non_header "^# [%][%](( |\\w).*)?$"))

; last code cell(empty)
(module
  ((comment) @cellseparator.code @_start @_end
             (#match? @cellseparator.code "^# [%][%]( .*)?$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](markdown>|md)[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[]\<raw>[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](\<markdown>|\<md>|\<raw>|\<code>)\@!\\w\+[]].*$") 
             )
  .
  )

; last code cell(one-expression)
(module
  ((comment) @cellseparator.code @_start @_end
             (#match? @cellseparator.code "^# [%][%]( .*)?$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](markdown>|md)[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[]\<raw>[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](\<markdown>|\<md>|\<raw>|\<code>)\@!\\w\+[]].*$") 
             )
  .
  (
   (_) @_non_header  @_innerstart @_end
   (#not-any-match? @_non_header "^# [%][%](( |\\w).*)?$")
   )
  .
  )
; last code cell(2+ expression)
(module
  ((comment) @cellseparator.code @_start
             (#match? @cellseparator.code "^# [%][%]( .*)?$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](markdown>|md)[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[]\<raw>[]].*$")
             (#not-match? @cellseparator.code "^# [%]{2} [[](\<markdown>|\<md>|\<raw>|\<code>)\@!\\w\+[]].*$") 
             )
  .
  (_) @_non_header @_innerstart
  .
  (_)+ @_non_header @_end
  (#not-any-match? @_non_header "^# [%][%](( |\\w).*)?$")
  .
  )

; markdown cell
(
 ((comment) @cellseparator.markdown @_start
            (#match? @cellseparator.markdown "^# [%]{2} [[](markdown>|md)[]].*$"))
 . 
 (expression_statement
   (string
     (string_start) @cellborder.start.markdown
     (string_content) @cellcontent.markdown
     (string_end) @cellborder.end.markdown
     )
   )? @cellbody.markdown @_end
 .
 (#match? @cellbody.markdown "^[\"']{3}.*[\"']{3}$")
 )


; raw cell
(

 ((comment) @cellseparator.raw
            (#match? @cellseparator.raw "^# [%]{2} [[]\<raw>[]].*$")) @_start
 . 
 (expression_statement
   (string 
     (string_start) @cellborder.start.raw
     (string_content) @cellcontent.raw
     (string_end) @cellborder.end.raw
     )
   )? @cellbody.raw @_end
 .
 (#match? @cellbody.raw "^[\"']{3}.*[\"']{3}$")
 )


; special(other) cell
(
 ((comment) @cellseparator.special
            (#match? @cellseparator.special "^# [%]{2} [[](\<markdown>|\<md>|\<raw>|\<code>)\@!\\w\+[]].*$"))@_start
 . 
 (expression_statement
   (string 
     (string_start) @cellborder.start.special
     (string_content) @cellcontent.special
     (string_end) @cellborder.end.special
     )
   )? @cellbody.special @_end
 .
 (#match? @cellbody.special "^[\"']{3}.*[\"']{3}$")
 )


; magic cell
(
 ((comment) @cellseparator.magic
            (#match? @cellseparator.magic "^# [%][%]\\w.*$"))@_start
 . 
 (expression_statement
   (string 
     (string_start) @cellborder.start.magic
     (string_content) @cellcontent.magic
     (string_end) @cellborder.end.magic
     )
   )? @cellbody.magic @_end
 .
 (#match? @cellbody.magic "^[\"']{3}.*[\"']{3}$")
 )


; line magic
((comment) @linemagic
           (#match? @linemagic "^# [%]\\w.*$"))
