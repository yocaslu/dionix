vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- o cache do base46 guarda as cores: recompila quando o tema muda
local theme = dofile(vim.fn.stdpath "config" .. "/dionix-theme.lua")
local stamp = vim.g.base46_cache .. "theme"
local file = io.open(stamp, "r")
local cached = file and file:read "*a"
if file then
  file:close()
end
if cached ~= theme then
  require("base46").load_all_highlights()
  file = io.open(stamp, "w")
  if file then
    file:write(theme)
    file:close()
  end
end

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)
