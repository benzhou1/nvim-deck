local IO = require('deck.kit.IO')
local System = require('deck.kit.System')

local home = IO.normalize(vim.fn.expand('~'))
local home_pre_pat = '^' .. vim.pesc(home)

---@param filename string
---@return deck.Item
local function to_item(filename)
  local display_text = filename
  if vim.startswith(display_text, home) then
    display_text = display_text:gsub(home_pre_pat, '~')
  end
  local item = {
    display_text = display_text,
    filename = filename,
  }
  item.data = item
  return item
end

---@class FilesOptions
---@field root_dir? string
---@field ignore_globs? string[]
---@field transform? fun(item: deck.Item)
---@alias deck.builtin.source.files.Finder fun(option: FilesOptions, ctx: deck.ExecuteContext)

---@type deck.builtin.source.files.Finder
local function ripgrep(opts, ctx)
  local command = { 'rg', '--files', '-.' }
  for _, glob in ipairs(opts.ignore_globs or {}) do
    table.insert(command, '--glob')
    table.insert(command, '!' .. glob)
  end

  local root_dir = vim.fs.normalize(opts.root_dir)
  ctx.on_abort(System.spawn(command, {
    cwd = root_dir,
    env = {},
    buffering = System.LineBuffering.new({
      ignore_empty = true,
    }),
    on_stdout = function(text)
      local item = to_item(IO.join(root_dir, text))
      if opts.transform ~= nil then
        opts.transform(item)
      end
      if not item.data.filename then
        return
      end
      ctx.item(item)
    end,
    on_stderr = function()
      -- noop
    end,
    on_exit = function()
      ctx.done()
    end,
  }))
end

---@type deck.builtin.source.files.Finder
local function walk(opts, ctx)
  local ignore_glob_patterns = vim
      .iter(opts.ignore_globs or {})
      :map(function(glob)
        return vim.glob.to_lpeg(glob)
      end)
      :totable()

  IO.walk(opts.root_dir, function(err, entry)
    if err then
      return
    end
    if ctx.aborted() then
      return IO.WalkStatus.Break
    end
    if entry.type ~= 'file' then
      for _, ignore_glob in ipairs(ignore_glob_patterns) do
        if ignore_glob:match(entry.path) then
          return IO.WalkStatus.SkipDir
        end
        return
      end
    end

    if entry.type == 'file' then
      ctx.item(to_item(entry.path))
    end
  end):next(function()
    ctx.done()
  end)
end

--[=[@doc
  category = "source"
  name = "files"
  desc = "Show files under specified root directory."
  example = """
    deck.start(require('deck.builtin.source.files')({
      root_dir = vim.fn.getcwd(),
      ignore_globs = { '**/node_modules/', '**/.git/' },
    }))
  """

  [[options]]
  name = "ignore_globs"
  type = "string[]?"
  default = "[]"
  desc = "Ignore glob patterns."

  [[options]]
  name = "root_dir"
  type = "string"
  desc = "Target root directory."

  [[options]]
  name = "transform"
  type = "fun(item: deck.Item)?"
  desc = "Function that allows you to modify an item before it is added to the picker"
]=]
---@param option FilesOptions
return function(option)
  local root_dir = vim.fs.normalize(vim.fn.fnamemodify(option.root_dir, ':p'))
  if vim.fn.filereadable(root_dir) == 1 then
    root_dir = vim.fs.dirname(root_dir)
  end
  local ignore_globs = option.ignore_globs or {}

  ---@type deck.Source
  return {
    name = 'files',
    execute = function(ctx)
      for _, ignore_glob in ipairs(ignore_globs) do
        if vim.glob.to_lpeg(ignore_glob):match(root_dir) then
          return ctx.done()
        end
      end

      local root_path = option.root_dir
      local config = ctx.get_config()
      if config.toggles.cwd == true then
        root_path = vim.fn.getcwd()
      end

      local new_option = vim.tbl_deep_extend('keep', { root_dir = root_path }, option)
      if vim.fn.executable('rg') == 1 then
        ripgrep(new_option, ctx)
      else
        walk(new_option, ctx)
      end
    end,
    actions = {
      require('deck').alias_action('default', 'open'),
    },
  }
end
