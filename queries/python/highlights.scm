; extends


((comment) @cellseparator.code
           (#lua-match? @cellseparator.code "^# %%%%$"))

((comment) @cellseparator.code
    (#match? @cellseparator.code "^# [%]{2} ([[]\\w\+[]])\@!"))

((comment) @cellseparator.markdown
    . (expression_statement
        (string 
            (string_start) @cellborder.markdown
            (string_content) @cellcontent.markdown
            (string_end) @cellborder.markdown
        )
    )? @cellbody.markdown
    (#match? @cellseparator.markdown "^# [%]{2} [[]\<markdown>|\<md>[]].*$")
    (#match? @cellbody.markdown "^[\"']{3}.*[\"']{3}$"))


((comment) @cellseparator.raw
    . (expression_statement
        (string
            (string_start) @cellborder.raw
            (string_content) @cellcontent.raw
            (string_end) @cellborder.raw
        )
    )? @cellbody.raw
    (#match? @cellseparator.raw "^# [%]{2} [[]\<raw>[]].*$")
    (#match? @cellbody.raw "^[\"']{3}.*[\"']{3}$"))

((comment) @cellseparator.special
    . (expression_statement
        (string
            (string_start) @cellborder.special
            (string_content) @cellcontent.special
            (string_end) @cellborder.special
        )
    )? @cellbody.special
    (#match? @cellseparator.special "^# [%]{2} [[](\<markdown>|\<md>|\<raw>)\@!\\w\+[]].*$")
    (#match? @cellbody.special "^[\"']{3}.*[\"']{3}$"))
