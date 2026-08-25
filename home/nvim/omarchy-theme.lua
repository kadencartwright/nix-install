local definition_path = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")
local loaded, definition = pcall(dofile, definition_path)

local specs = {}
local colorscheme
local background

if loaded and type(definition) == "table" then
	for _, spec in ipairs(definition) do
		if type(spec) == "table" and spec[1] == "LazyVim/LazyVim" then
			if type(spec.opts) == "table" then
				colorscheme = spec.opts.colorscheme or colorscheme
				background = spec.opts.background or background
			end
		else
			table.insert(specs, spec)
		end
	end
end

if not colorscheme then
	colorscheme = "onedark"
	specs = {
		{
			"navarasu/onedark.nvim",
			priority = 1000,
		},
	}
end

-- Omarchy's definitions target LazyVim, where colorscheme plugins are loaded
-- during startup. Preserve that behavior in this smaller, plain lazy.nvim setup.
for _, spec in ipairs(specs) do
	if type(spec) == "table" then
		spec.lazy = false
		spec.priority = math.max(spec.priority or 0, 1000)
	end
end

table.insert(specs, {
	dir = vim.fn.stdpath("config"),
	name = "omarchy-theme-loader",
	lazy = false,
	priority = 900,
	config = function()
		require("omarchy_theme").setup()
	end,
})

return specs
