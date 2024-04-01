MINI_INIT=scripts/minimal_init.lua
TESTS_DIR=lua-tests/

# .PHONY: test doc

test:
	@nvim \
		--headless \
		--noplugin \
		-u ${MINI_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${MINI_INIT}' }"

document:
	@nvim \
		--headless \
		--noplugin \
		-u ${MINI_INIT}  \
		-c 'lua require("mini.doc").generate()' \
		-c 'qa'

