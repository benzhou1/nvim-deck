local x = require('deck.x')
local kit = require('deck.kit')
local Keymap = require('deck.kit.Vim.Keymap')
local ScheduledTimer = require('deck.kit.Async.ScheduledTimer')
local Context = require('deck.Context')

local RedrawInterval = 80

---Check the window is visible or not.
---@param win? integer
---@return boolean
local function is_visible(win)
  if not win then
    return false
  end
  return vim.api.nvim_win_is_valid(win)
end

---@param position 'top' | 'bottom' | 'left' | 'right'
---@param calc_height_or_width fun(ctx: deck.Context, view: deck.View): integer
---@return deck.View
return function(position, calc_height_or_width)
  ---@type 'vertical' | 'horizontal'
  local split = (position == 'top' or position == 'bottom') and 'horizontal' or 'vertical'

  local spinner = {
    idx = 1,
    frame = { '.', '..', '...', '....' },
  }

  local state = {
    win = nil, --[[@type integer?]]
    preview_win = nil, --[[@type integer?]]
    preview_cache = {},--[[@as table<string, table>]]
    timer = ScheduledTimer.new(),
    dirty = false,
  }

  local view ---@type deck.View

  ---Redraw dirty.
  ---@param ctx deck.Context
  local function redraw_dirty(ctx)
    if not state.dirty then
      return
    end
    state.dirty = false

    -- update window height or width.
    local next_height_or_width = calc_height_or_width(ctx, view)
    local curr_height_or_width = split == 'horizontal' and vim.api.nvim_win_get_height(state.win) or vim.api.nvim_win_get_width(state.win)
    if curr_height_or_width ~= next_height_or_width then
      vim.api.nvim_win_call(state.win, function()
        local winnr = vim.fn.winnr()
        if split == 'horizontal' then
          if winnr ~= vim.fn.winnr('j') or winnr ~= vim.fn.winnr('k') then
            vim.api.nvim_win_set_height(state.win, next_height_or_width)
          end
        else
          if winnr ~= vim.fn.winnr('h') or winnr ~= vim.fn.winnr('l') then
            vim.api.nvim_win_set_width(state.win, next_height_or_width)
          end
        end
      end)
    end

    -- update statusline.
    do
      spinner.idx = spinner.idx + 1

      local is_running = (ctx.get_status() ~= Context.Status.Success or ctx.is_filtering())
      vim.api.nvim_set_option_value('statusline', ('[%s] %s/%s%s'):format(ctx.name, #ctx.get_filtered_items(), #ctx.get_items(), is_running and (' %s'):format(spinner.frame[spinner.idx % #spinner.frame + 1]) or ''), {
        win = state.win,
      })
    end

    -- update preview.
    local item = ctx.get_cursor_item()
    local start_config = ctx:get_config()
    local deps = {
      item = item,
      preview_mode = ctx.get_preview_mode(),
      height_or_width = next_height_or_width,
    }
    if not kit.shallow_equals(state.preview_cache or {}, deps) then
      state.preview_cache = deps
      if not item or not ctx.get_preview_mode() or not ctx.get_previewer() then
        if is_visible(state.preview_win) then
          vim.api.nvim_win_hide(state.preview_win)
          state.preview_win = nil
        end
      else
        local available_height = vim.o.lines - (split == 'horizontal' and next_height_or_width or 0)
        local available_width = vim.o.columns - (split == 'vertical' and next_height_or_width or 0)
        local win_config = {
          noautocmd = true,
          relative = 'editor',
          width = math.floor(available_width * 0.8),
          height = math.floor(available_height * 0.8),
          row = math.max(1, math.floor(available_height * 0.1) - 2) + (position == 'top' and next_height_or_width or 0),
          col = math.floor(available_width * 0.1) + (position == 'left' and next_height_or_width or 0),
          style = 'minimal',
          border = 'rounded',
        }
        if start_config.preview.win_opts then
          win_config = vim.tbl_deep_extend('keep', start_config.preview.win_opts(next_height_or_width), win_config)
        end
        if not is_visible(state.preview_win) then
          state.preview_win = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false, win_config)
        else
          win_config.noautocmd = nil
          vim.api.nvim_win_set_config(state.preview_win, win_config)
        end
        ctx.get_previewer().preview(ctx, item, { win = state.preview_win })
        vim.api.nvim_set_option_value('wrap', false, { win = state.preview_win })
        vim.api.nvim_set_option_value('winhighlight', start_config.preview.win_hl or 'Normal:Normal,FloatBorder:Normal,FloatTitle:Normal,FloatFooter:Normal', { win = state.preview_win })
        vim.api.nvim_set_option_value('number', true, { win = state.preview_win })
        vim.api.nvim_set_option_value('numberwidth', 5, { win = state.preview_win })
        vim.api.nvim_set_option_value('scrolloff', 0, { win = state.preview_win })
        vim.api.nvim_set_option_value('modified', false, { buf = vim.api.nvim_win_get_buf(state.preview_win) })
      end
    end

    -- redraw if cmdline.
    if vim.fn.mode(1):sub(1, 1) == 'c' then
      vim.api.nvim__redraw({
        flush = true,
        valid = true,
        win = state.win,
      })
      vim.api.nvim__redraw({
        flush = true,
        valid = true,
        win = state.preview_win,
      })
    end
  end

  view = {
    ---Get window.
    ---@return integer?
    get_win = function()
      if is_visible(state.win) then
        return state.win
      end
    end,

    ---Check if window is visible.
    is_visible = function(ctx)
      return is_visible(state.win) and vim.api.nvim_win_get_buf(state.win) == ctx.buf
    end,

    ---Show window.
    show = function(ctx)
      -- ensure main window.
      if not view.is_visible(ctx) then
        ctx.sync()

        state.win = x.ensure_win(('deck.builtin.view.edge_picker:%s'):format(split), function()
          vim.cmd[split == 'horizontal' and 'split' or 'vsplit']({
            range = { calc_height_or_width(ctx, view) },
            mods = {
              split = (position == 'top' or position == 'left') and 'topleft' or 'botright',
              keepalt = true,
              keepjumps = true,
              keepmarks = true,
              noautocmd = true,
            },
          })
          return vim.api.nvim_get_current_win()
        end, function(win)
          vim.api.nvim_set_current_win(win)
          vim.api.nvim_set_option_value('wrap', false, { win = win })
          vim.api.nvim_set_option_value('number', false, { win = win })
          vim.api.nvim_set_option_value(split == 'horizontal' and 'winfixheight' or 'winfixwidth', true, { win = win })
        end)

        vim.cmd('normal! m`')
        vim.api.nvim_win_set_buf(state.win, ctx.buf)
      end

      state.timer:start(0, RedrawInterval, function()
        redraw_dirty(ctx)
      end)
    end,

    ---Hide window.
    hide = function(ctx)
      state.timer:stop()
      if view.is_visible(ctx) then
        vim.api.nvim_win_hide(state.win)
      end
      if is_visible(state.preview_win) then
        vim.api.nvim_win_hide(state.preview_win)
      end
    end,

    ---Redraw window.
    redraw = function(ctx)
      state.dirty = true

      local curr = split == 'horizontal' and vim.api.nvim_win_get_height(state.win) or vim.api.nvim_win_get_width(state.win)
      local next = calc_height_or_width(ctx, view)
      -- update winheight.
      if curr ~= next then
        state.timer:start(0, RedrawInterval, function()
          redraw_dirty(ctx)
        end)
      end
    end,

    ---Start query edit prompt.
    prompt = function(ctx)
      Keymap.send(Keymap.to_sendable(function()
        if not view.is_visible(ctx) then
          return
        end
        local group = vim.api.nvim_create_augroup(('deck.builtin.view.edge_picker:%s.prompt'):format(position), {
          clear = true,
        })
        vim.schedule(function()
          vim.api.nvim__redraw({
            flush = true,
            valid = true,
            win = state.win,
          })
          vim.api.nvim_create_autocmd('CmdlineChanged', {
            group = group,
            callback = function()
              ctx.set_query(vim.fn.getcmdline())
            end,
          })
        end)
        vim.fn.input('$ ', ctx.get_query())
        vim.api.nvim_clear_autocmds({ group = group })
      end))
    end,

    ---Scroll preview window.
    scroll_preview = function(_, delta)
      if not is_visible(state.preview_win) then
        return
      end
      vim.api.nvim_win_call(state.preview_win, function()
        local topline = vim.fn.getwininfo(state.preview_win)[1].topline
        topline = math.max(1, topline + delta)
        topline = math.min(vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(state.preview_win)) - vim.api.nvim_win_get_height(state.preview_win) + 1, topline)
        vim.cmd.normal({
          ('%szt'):format(topline),
          bang = true,
          mods = {
            keepmarks = true,
            keepjumps = true,
            keepalt = true,
            noautocmd = true,
          },
        })
      end)
      vim.api.nvim__redraw({
        flush = true,
        valid = true,
        win = state.preview_win,
      })
    end,
  }
  return view
end
