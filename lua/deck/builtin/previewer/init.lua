local helper = require('deck.helper')

local previewer = {}

---filename previewer.
---@type deck.Previewer
previewer.filename = {
  name = 'filename',
  resolve = function(ctx)
    local item = ctx.get_cursor_item()
    if not item then
      return false
    end
    return item.data.filename ~= nil and vim.fn.filereadable(item.data.filename) == 1
  end,
  preview = function(ctx, env)
    local item = ctx.get_cursor_item()
    if item then
      helper.open_preview_buffer(env.win, {
        contents = vim.split(assert(io.open(item.data.filename, "r")):read('*a'), '\n'),
        filename = item.data.filename,
        lnum = item.data.lnum,
        col = item.data.col,
        end_lnum = item.data.end_lnum,
        end_col = item.data.end_col,
      })
    end
  end
}

---bufnr previewer.
---@type deck.Previewer
previewer.bufnr = {
  name = 'bufnr',
  resolve = function(ctx)
    local item = ctx.get_cursor_item()
    if not item then
      return false
    end
    return item.data.bufnr
  end,
  preview = function(ctx, env)
    local item = ctx.get_cursor_item()
    if item then
      helper.open_preview_buffer(env.win, {
        contents = vim.api.nvim_buf_get_lines(item.data.bufnr, 0, -1, false),
        filetype = vim.api.nvim_get_option_value('filetype', { buf = item.data.bufnr }),
        lnum = item.data.lnum,
        col = item.data.col,
        end_lnum = item.data.end_lnum,
        end_col = item.data.end_col,
      })
    end
  end
}

return previewer
