-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local uv = vim.uv or vim.loop
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not uv.fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- Home Manager makes the config tree read-only. Keep Lazy's changing lockfile
-- in XDG state, seeded from the declarative lockfile on first use.
local lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json"
if not uv.fs_stat(lockfile) then
	vim.fn.mkdir(vim.fn.fnamemodify(lockfile, ":h"), "p")
	local seed = vim.fn.stdpath("config") .. "/lazy-lock.json"
	if uv.fs_stat(seed) then
		assert(uv.fs_copyfile(seed, lockfile))
	end
end
if uv.fs_stat(lockfile) then
	assert(uv.fs_chmod(lockfile, tonumber("600", 8)))
end

require("lazy").setup({
	spec = {
		{ import = "plugins" },
	},
	lockfile = lockfile,
	install = { colorscheme = { "habamax" } },
})
