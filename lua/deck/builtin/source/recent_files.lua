local MemoryFile = require('deck.x.MemoryFile')
local IO = require('deck.kit.IO')
local Async = require('deck.kit.Async')

--[=[@doc
  category = "source"
  name = "recent_files"
  desc = "List recent files."
  example = """
    require('deck.builtin.source.recent_files'):setup({
      path = '~/.deck.recent_files'
    })
    vim.api.nvim_create_autocmd('BufEnter', {
      callback = function()
        local bufname = vim.api.nvim_buf_get_name(0)
        if vim.fn.filereadable(bufname) == 1 then
          require('deck.builtin.source.recent_files'):add(vim.fs.normalize(bufname))
        end
      end,
    })
    deck.start(require('deck.builtin.source.recent_files')({
      ignore_paths = { '**/node_modules/', '**/.git/' },
    }))
  """

  [[options]]
  name = "ignore_paths"
  type = "string[]?"
  default = "[]"
  desc = "Ignore paths."

  [[options]]
  name = "transform"
  type = "fun(item: deck.Item)?"
  default = "nil"
  desc = "Transform item before listing."

  [[options]]
  name = "limit"
  type = "integer?"
  default = "nil"
  desc = "Limits the number of recent items."
]=]
return setmetatable({
  file = MemoryFile.new(vim.fs.normalize('~/.deck.recent_files')),

  ---Setup.
  ---@param config { path: string }
  setup = function(self, config)
    local path = vim.fs.normalize(config.path)
    if vim.fn.filereadable(path) == 0 then
      error('`config.path` must be readable file.')
    end
    self.file = MemoryFile.new(path)
  end,

  ---Prune entries (remove duplicates and non-existent entries).
  ---@param self unknown
  prune = function(self)
    local seen = {}
    for i = #self.file.contents, 1, -1 do
      local path = self.file.contents[i]
      if seen[path] or vim.fn.filereadable(path) == 0 then
        table.remove(self.file.contents, i)
      end
      seen[path] = true
    end
  end,

  --- Remove entry.
  ---@param self unknown
  ---@param target_path string
  remove = function(self, target_path)
    for i, path in ipairs(self.file.contents) do
      if path == target_path then
        table.remove(self.file.contents, i)
        return
      end
    end
  end,

  ---Add entry.
  ---@param self unknown
  ---@param target_path string
  add = function(self, target_path)
    if not target_path then
      return
    end
    target_path = vim.fs.normalize(target_path)

    local exists = vim.fn.filereadable(target_path) == 1
    if not exists then
      return
    end

    local seen = { [target_path] = true }
    for i = #self.file.contents, 1, -1 do
      local path = self.file.contents[i]
      if seen[path] then
        table.remove(self.file.contents, i)
      end
      seen[path] = true
    end
    table.insert(self.file.contents, target_path)
  end,
}, {
  ---@class RecentFilesOptions
  ---@field ignore_paths string[]
  ---@field transform fun(item: deck.Item)
  ---@field limit integer?
  ---@param option RecentFilesOptions
  __call = function(self, option)
    option = option or {}
    option.ignore_paths = option.ignore_paths or { vim.fn.expand('%:p'):gsub('/$', '') }

    local ignore_path_map = {}
    for _, ignore_path in ipairs(option.ignore_paths) do
      ignore_path_map[ignore_path] = true
    end

    ---@type deck.Source
    return {
      name = 'recent_files',
      execute = function(ctx)
        local sync_count = vim.o.lines
        local contents = self.file.contents
        Async.run(function()
          local i = #contents
          local count = 0
          -- sync items.
          while i >= 1 do
            local path = contents[i]
            if not ignore_path_map[path] then
              if vim.fn.filereadable(path) == 1 then
                local item = {
                  display_text = vim.fn.fnamemodify(path, ':~'),
                  data = {
                    filename = path,
                  },
                }
                if not item.display_text then
                  return
                end
                if option.transform ~= nil then
                  option.transform(item)
                end
                ctx.item(item)
                sync_count = sync_count - 1
                count = count + 1
                if option.limit and count >= option.limit then
                  break
                end
              end
            end
            if sync_count == 0 then
              break
            end
            i = i - 1
          end
          -- async items.
          while i >= 1 do
            local path = contents[i]
            if not ignore_path_map[path] then
              if IO.exists(path):await() then
                local item = {
                  display_text = vim.fn.fnamemodify(path, ':~'),
                  data = {
                    filename = path,
                  },
                }
                if option.transform ~= nil then
                  option.transform(item)
                end
                ctx.item(item)
                count = count + 1
                if option.limit and count >= option.limit then
                  break
                end
              end
            end
            i = i - 1
          end

          ctx.done()
        end)
      end,
      actions = {
        require('deck').alias_action('default', 'open'),
      },
    }
  end,
})
