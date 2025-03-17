.PHONY: lint
lint:
	@./scripts/type_check.sh

nvim:
	@nvim -u tests/nvim_test/init.lua

.PHONY: test
test:
	# Before running the tests for the first time, open Neovim with the following command
	# to allow it to install all the Treesitter parsers: nvim -u tests/nvim_test/init.lua
	#
	# To update tests - remove files manually from tests/screenshots directory.
	#
	@nvim --headless --noplugin -u tests/nvim_tester/init.lua -c "lua MiniTest.run()"

.PHONY: gen-docs
docs:
	@deps/panvimdoc/panvimdoc.sh \
		--project-name "symbols" \
		--vim-version "NVIM v0.10.0" \
		--input-file README.md \
		--treesitter true \
		--toc true
	@sed -i "" "1,2d" ./doc/symbols.txt

.PHONY: deps
deps:
	mkdir -p deps
	$(MAKE) deps-panvimdoc
	$(MAKE) deps-treesitter
	$(MAKE) deps-lua-lsp
	$(MAKE) deps-solargraph-lsp

.PHONY: deps-panvimdoc
deps-panvimdoc:
	cd deps; git clone --depth 1 https://github.com/kdheepak/panvimdoc.git
	sed -i.bak "s/\r$$//" deps/panvimdoc/panvimdoc.sh

.PHONY: deps-treesitter
deps-treesitter:
	cd deps; git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git

# macOS specific
.PHONY: deps-lua-lsp
deps-lua-lsp:
	cd deps; curl -L --remote-name https://github.com/LuaLS/lua-language-server/releases/download/3.13.2/lua-language-server-3.13.2-darwin-arm64.tar.gz
	mkdir -p deps/lua-language-server
	cd deps; tar -xvzf lua-language-server-3.13.2-darwin-arm64.tar.gz -C lua-language-server
	rm deps/lua-language-server-3.13.2-darwin-arm64.tar.gz

# assumes Ruby 3.3.0 (or similar) and bundler (https://bundler.io) installed
.PHONY: deps-solargraph-lsp
deps-solargraph-lsp:
	mkdir -p deps/solargraph
	cd deps/solargraph; bundle init; echo 'gem "solargraph"' >> Gemfile;
	cd deps/solargraph; bundle config set path "vendor/bundle"; bundle install

.PHONY: deps
deps-clean:
	rm -rf deps
