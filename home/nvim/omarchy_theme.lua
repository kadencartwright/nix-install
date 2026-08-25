local M = {}

local uv = vim.uv or vim.loop
local definition_path = vim.fn.expand("~/.local/state/omarchy/current/theme/neovim.lua")
local marker_path = vim.fn.expand("~/.local/state/omarchy/neovim-theme")

local function read_definition()
	local loaded, definition = pcall(dofile, definition_path)
	if not loaded or type(definition) ~= "table" then
		return nil, nil, nil
	end

	local theme_spec
	local colorscheme
	local background
	for _, spec in ipairs(definition) do
		if type(spec) == "table" and spec[1] == "LazyVim/LazyVim" then
			if type(spec.opts) == "table" then
				colorscheme = spec.opts.colorscheme or colorscheme
				background = spec.opts.background or background
			end
		elseif not theme_spec then
			theme_spec = spec
		end
	end

	return theme_spec, colorscheme, background
end

local function normalize_spec(spec)
	if type(spec) == "string" then
		return { spec }
	end
	return spec
end

local function plugin_name(spec)
	spec = normalize_spec(spec)
	if type(spec) ~= "table" then
		return nil
	end
	return spec.name or (type(spec[1]) == "string" and spec[1]:match("([^/]+)$"))
end

local function add_runtime(spec)
	spec = normalize_spec(spec)
	if type(spec) ~= "table" then
		return false
	end

	if type(spec.dependencies) == "table" then
		for _, dependency in ipairs(spec.dependencies) do
			add_runtime(dependency)
		end
	end

	local name = plugin_name(spec)
	if not name then
		return false
	end

	local directory = vim.fn.stdpath("data") .. "/lazy/" .. name
	if not uv.fs_stat(directory) then
		return false
	end

	if not vim.tbl_contains(vim.opt.rtp:get(), directory) then
		vim.opt.rtp:prepend(directory)
	end

	return true
end

local function setup_plugin(spec)
	spec = normalize_spec(spec)
	if type(spec) ~= "table" or type(spec.opts) ~= "table" then
		return
	end

	local name = plugin_name(spec)
	local candidates = {
		spec.main,
		spec.name,
		name and name:gsub("%.nvim$", ""),
		name and name:gsub("%-nvim$", ""),
		name and name:gsub("%-neovim$", ""),
	}
	local tried = {}
	for _, candidate in ipairs(candidates) do
		if candidate and not tried[candidate] then
			tried[candidate] = true
			local found, module = pcall(require, candidate)
			if found and type(module) == "table" and type(module.setup) == "function" then
				module.setup(spec.opts)
				return
			end
		end
	end
end

function M.apply()
	local spec, colorscheme, background = read_definition()
	if not spec or not colorscheme then
		return false
	end

	if not add_runtime(spec) then
		vim.notify("Omarchy theme plugin is not installed yet", vim.log.levels.WARN)
		return false
	end

	setup_plugin(spec)
	if background == "dark" or background == "light" then
		vim.o.background = background
	end

	local applied, err = pcall(vim.cmd.colorscheme, colorscheme)
	if not applied then
		vim.notify(
			("Could not apply Omarchy colorscheme %q: %s"):format(colorscheme, err),
			vim.log.levels.ERROR
		)
		return false
	end

	return true
end

function M.setup()
	M.apply()
	if M.watcher then
		return
	end

	vim.fn.mkdir(vim.fn.fnamemodify(marker_path, ":h"), "p")
	local marker = io.open(marker_path, "a")
	if marker then
		marker:close()
	end

	M.timer = uv.new_timer()
	M.watcher = uv.new_fs_event()
	M.watcher:start(marker_path, {}, function()
		M.timer:stop()
		M.timer:start(75, 0, vim.schedule_wrap(M.apply))
	end)
end

return M
