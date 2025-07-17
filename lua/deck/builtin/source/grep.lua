local notify = require('deck.notify')
local IO = require('deck.kit.IO')
local System = require('deck.kit.System')

--[=[@doc
  category = "source"
  name = "grep"
  desc = "Grep files under specified root directory. (required `ripgrep`)"
  example = """
    deck.start(require('deck.builtin.source.grep')({
      root_dir = vim.fn.getcwd(),
      pattern = vim.fn.input('grep: '),
      ignore_globs = { '**/node_modules/', '**/.git/' },
    }))
  """

  [[options]]
  name = "name"
  type = "string?"
  desc = "Override grep source name."

  [[options]]
  name = "root_dir"
  type = "string"
  desc = "Target root directory."

  [[options]]
  name = "ignore_globs"
  type = "string[]?"
  default = "[]"
  desc = "Ignore glob patterns."

  [[options]]
  name = "sort"
  type = "boolean?"
  default = "false"
  desc = "Sort results by filename and line number."

  [[options]]
  name = "transform"
  type = "fun(item: deck.Item, text: string, root_dir: string)?"
  desc = "Transform item with matched text."

  [[options]]
  name = "cmd"
  type = "fun(query: string): string[]?"
  desc = "Custom command to execute."

  [[options]]
  name = "live"
  type = "boolean?"
  default = "false"
  desc = "Enable live grep."
]=]
---@class deck.builtin.source.grep.Option
---@field root_dir string
---@field ignore_globs? string[]
---@field sort? boolean
---@field transform? fun(item: deck.Item, text: string, root_dir: string)
---@field live? boolean
---@field cmd? fun(query: string): string[]
---@field name? string
---@param option deck.builtin.source.grep.Option
return function(option)
  local function parse_query(query)
    local sep = query:find('  ') or #query
    local dynamic_query = query:sub(1, sep)
    local matcher_query = query:sub(sep + 2)
    return {
      dynamic_query = dynamic_query:gsub('^%s+', ''):gsub('%s+$', ''),
      matcher_query = matcher_query:gsub('^%s+', ''):gsub('%s+$', ''),
    }
  end

  ---@type deck.Source
  return {
    name = option.name or 'grep',
    parse_query = parse_query,
    execute = function(ctx)
      local query = parse_query(ctx.get_query()).dynamic_query
      if option.live ~= true and query == '' then
        return ctx.done()
      end

      local command = {
        'rg',
        '--column',
        '--line-number',
        '--ignore-case',
      }
      if option.ignore_globs then
        for _, glob in ipairs(option.ignore_globs) do
          table.insert(command, '--glob')
          table.insert(command, '!' .. glob)
        end
      end
      if option.sort then
        table.insert(command, '--sort-files')
      end
      table.insert(command, query)

      if option.cmd ~= nil then
        command = option.cmd(query)
      end

      local root_dir = option.root_dir
      local config = ctx.get_config()
      if config.toggles.cwd == true then
        root_dir = vim.fn.getcwd()
      end

      ctx.on_abort(System.spawn(command, {
        cwd = root_dir,
        env = {},
        buffering = System.LineBuffering.new({
          ignore_empty = true,
        }),
        on_stdout = function(text)
          local item = { data = { query = query } }
          if not option.transform then
            local filename = text:match('^[^:]+')
            local lnum = tonumber(text:match(':(%d+):'))
            local col = tonumber(text:match(':%d+:(%d+):'))
            local match = text:match(':%d+:%d+:(.*)$')
            if filename and match then
              item = {
                display_text = {
                  { ('%s (%s:%s): '):format(filename, lnum, col) },
                  { match, 'Comment' },
                },
                data = {
                  filename = IO.join(root_dir, filename),
                  lnum = lnum,
                  col = col,
                  query = query,
                },
              }
            end
          end
          if option.transform ~= nil then
            option.transform(item, text, option.root_dir)
          end
          if item.display_text ~= nil then
            ctx.item(item)
          end
        end,
        on_exit = function()
          ctx.done()
        end,
      }))
    end,
    actions = {
      require('deck').alias_action('default', 'open'),
    },
  }
end
