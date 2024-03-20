; extends


((comment) @cell.header.code
           (#lua-match? @cell.header.code "^# %%%%$"))

((comment) @cell.header.code
    (#match? @cell.header.code "^# [%]{2} ([[]\\w\+[]])\@!"))

((comment) @cell.header.markdown
    . (expression_statement
        (string 
            (string_start) @cell.border.markdown
            (string_content) @cell.content.markdown
            (string_end) @cell.border.markdown
        )
    )? @cell.body.markdown
    (#match? @cell.header.markdown "^# [%]{2} [[]\<markdown>|\<md>[]].*$")
    (#match? @cell.body.markdown "^[\"']{3}.*[\"']{3}$"))


((comment) @cell.header.raw
    . (expression_statement
        (string
            (string_start) @cell.border.raw
            (string_content) @cell.content.raw
            (string_end) @cell.border.raw
        )
    )? @cell.body.raw
    (#match? @cell.header.raw "^# [%]{2} [[]\<raw>[]].*$")
    (#match? @cell.body.raw "^[\"']{3}.*[\"']{3}$"))

((comment) @cell.header.special
    . (expression_statement
        (string
            (string_start) @cell.border.special
            (string_content) @cell.content.special
            (string_end) @cell.border.special
        )
    )? @cell.body.special
    (#match? @cell.header.special "^# [%]{2} [[](\<markdown>|\<md>|\<raw>)\@!\\w\+[]].*$")
    (#match? @cell.body.special "^[\"']{3}.*[\"']{3}$"))
