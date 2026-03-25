TESTS_DIR := tests
INIT := $(TESTS_DIR)/minimal_init.lua

# Run all test files via plenary (requires Neovim + plenary.nvim installed)
test:
	@for f in $(TESTS_DIR)/*_spec.lua; do \
		echo ""; \
		nvim --headless -u $(INIT) \
			-c "lua require('plenary.busted').run('$$f')" +qa 2>&1; \
	done

# Run a single test file, e.g.: make test-file FILE=tests/config_spec.lua
test-file:
	nvim --headless -u $(INIT) \
		-c "lua require('plenary.busted').run('$(FILE)')" +qa 2>&1

.PHONY: test test-file
