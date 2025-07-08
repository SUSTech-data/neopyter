MINI_INIT=scripts/minimal_init.lua
GEN_DOC=scripts/gen_doc.lua
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
		--clean \
		--noplugin \
		-l ${GEN_DOC}
	@nvim \
		--headless\
		--clean \
		--noplugin \
		-c "helptags ./doc" \
		-c "qall!"

