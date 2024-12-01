# Intro

_nvim-deck_ : A plugin for displaying, filtering, and selecting items from
customizable lists.

# Concept

nvim-deck revolves around four core concepts:

- Source:
  - A source provides a list of items to display.
- Item:
  - An item represents a single entry from the source, containing data and
    display text.
- Action:
  - Actions define what happens when the user interacts with an item.
- Context:
  - Context represents the current state, The user can control deck UI via
    invoke context methods.

# Features

- Built-in Git integration.
  - `:Deck git` to open the git launcher.
- Built-in ripgrep integration.
  - `:Deck grep` to start a grep search.
- Built-in recursive file traversal in pure Lua.
  - `:Deck files` to show files under the specified root directory.
- Highly customizable: sources, actions, previewers, decorators, views, and
  matchers.

# Setup

Here’s an example of how to set up `nvim-deck`:

```lua
local deck = require('deck')

-- Apply pre-defined easy settings.
-- For manual configuration, refer to the code in `deck/easy.lua`.
require('deck.easy').setup()

-- Set up buffer-specific key mappings for nvim-deck.
vim.api.nvim_create_autocmd('User', {
  pattern = 'DeckStart',
  callback = function(e)
    local ctx = e.data.ctx --[[@as deck.Context]]
    ctx.keymap('n', '<Tab>', deck.action_mapping('choose_action'))
    ctx.keymap('n', '<C-l>', deck.action_mapping('refresh'))
    ctx.keymap('n', 'i', deck.action_mapping('prompt'))
    ctx.keymap('n', 'a', deck.action_mapping('prompt'))
    ctx.keymap('n', '@', deck.action_mapping('toggle_select'))
    ctx.keymap('n', '*', deck.action_mapping('toggle_select_all'))
    ctx.keymap('n', 'p', deck.action_mapping('toggle_preview_mode'))
    ctx.keymap('n', 'd', deck.action_mapping('delete'))
    ctx.keymap('n', '<CR>', deck.action_mapping('default'))
    ctx.keymap('n', 'o', deck.action_mapping('open'))
    ctx.keymap('n', 'O', deck.action_mapping('open_keep'))
    ctx.keymap('n', 's', deck.action_mapping('open_s'))
    ctx.keymap('n', 'v', deck.action_mapping('open_v'))
    ctx.keymap('n', 'N', deck.action_mapping('create'))
    ctx.keymap('n', '<C-u>', deck.action_mapping('scroll_preview_up'))
    ctx.keymap('n', '<C-d>', deck.action_mapping('scroll_preview_down'))
  end
})

-- Example key bindings for launching nvim-deck sources. (These mapping required `deck.easy` calls.)
vim.keymap.set('n', '<Leader>ff', '<Cmd>Deck files<CR>', { desc = 'Show recent files, buffers, and more' })
vim.keymap.set('n', '<Leader>gr', '<Cmd>Deck grep<CR>', { desc = 'Start grep search' })
vim.keymap.set('n', '<Leader>gi', '<Cmd>Deck git<CR>', { desc = 'Open git launcher' })
vim.keymap.set('n', '<Leader>he', '<Cmd>Deck helpgrep<CR>', { desc = 'Live grep all help tags' })

-- Show the latest deck context.
vim.keymap.set('n', '<Leader>;', function()
  local ctx = require('deck').get_history()[1]
  if ctx then
    ctx.show()
  end
end)
```

# Customization

!!! We strongly recommend using `lua-language-server` !!!

### Create Your Own Action

Actions define what happens when a user interacts with an item.

The action can be registered in three different levels:

- _Global Action_ : Registered globally.
- _Source Action_ : Provided by a source.

You can register action to the global level using `deck.register_action()`.

Note: If an action has the same name in both the global and source levels, the
source action will take priority.

```lua
require('deck').register_action({
  name = 'my_open',
  resolve = function(ctx)
    -- Action is available only if there is exactly one action item with a filename.
    return #ctx.get_action_items() == 1 and ctx.get_action_items()[1].data.filename
  end,
  execute = function(ctx)
    -- Open the file.
    vim.cmd.edit(ctx.get_action_items()[1].data.filename)
  end
})
```

### Create Your Own StartPreset

A start-preset in `nvim-deck` allows you to define a set of sources that can be
triggered by a single command. This is useful for creating custom workflows or
predefined lists of sources that you want to display when starting a specific
context.

```lua
-- Register a start preset
-- After registration, you can start the preset using the `:Deck recent` command.
require('deck').register_start_preset('recent', {
  require('deck').start({
    require('deck.builtin.source.recent_files')(),
    require('deck.builtin.source.buffers')(),
  })
})
```

After registering the start-preset, you can use `:Deck recent` command.

### Create Your Own Decorator

nvim-deck has `decorator` concept. It's designed to decorate the buffer via
`nvim_buf_set_extmark`.

The below example shows how to create your own decorator.

```lua
--- This is example decorator.
--- To display the basename of the file and dirname as a comment.
--- This decorator highlight basename and make dirname less noticeable.
require('deck').register_decorator({
  name = 'basename_dirname',
  resolve = function(_, item)
    -- This decorator is available only if the item has a filename.
    return item.data.filename
  end,
  decorate = function(ctx, item, row)
    local dirname = vim.fn.fnamemodify(item.data.filename, ':~:h')
    local display_text = item.display_text
    local s, e = display_text:find(dirname, 1, true)
    if s then
      -- Hide the directory part (using conceal)
      vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, s - 1, {
        end_row = row,
        end_col = e + 1,
        conceal = '',
        ephemeral = true,
      })
      -- Display the directory name as a comment at the end of the line
      vim.api.nvim_buf_set_extmark(ctx.buf, ctx.ns, row, 0, {
        virt_text = { { dirname, 'Comment' } },
        virt_text_pos = 'eol'
      })
    end
  end
})
```

# Built-in

## Sources

<!-- auto-generate-s:source -->

### git

Show git launcher.

| Name | Type   | Default | Description      |
| ---- | ------ | ------- | ---------------- |
| cwd  | string |         | Target git root. |

```lua
deck.start(require('deck.builtin.source.git.changeset')({
  cwd = vim.fn.getcwd(),
}))
```

### git

Show git log.

| Name | Type   | Default | Description      |
| ---- | ------ | ------- | ---------------- |
| cwd  | string |         | Target git root. |

```lua
deck.start(require('deck.builtin.source.git.log')({
  cwd = vim.fn.getcwd(),
}))
```

### git

Show git remotes.

| Name | Type   | Default | Description      |
| ---- | ------ | ------- | ---------------- |
| cwd  | string |         | Target git root. |

```lua
deck.start(require('deck.builtin.source.git.remote')({
  cwd = vim.fn.getcwd(),
}))
```

### git

Show git status.

| Name | Type   | Default | Description      |
| ---- | ------ | ------- | ---------------- |
| cwd  | string |         | Target git root. |

```lua
deck.start(require('deck.builtin.source.git.status')({
  cwd = vim.fn.getcwd(),
}))
```

### grep

Grep files under specified root directory. (required `ripgrep`)

| Name         | Type      | Default | Description                                                                                   |
| ------------ | --------- | ------- | --------------------------------------------------------------------------------------------- |
| root_dir     | string    |         | Target root directory.                                                                        |
| pattern      | string?   |         | Grep pattern. If you omit this option, you must set `dynamic` option to true.                 |
| dynamic      | boolean?  | false   | If true, use dynamic pattern. If you set this option to false, you must set `pattern` option. |
| ignore_globs | string[]? | []      | Ignore glob patterns.                                                                         |

```lua
deck.start(require('deck.builtin.source.grep')({
  root_dir = vim.fn.getcwd(),
  pattern = vim.fn.input('grep: '),
  ignore_globs = { '**/node_modules/', '**/.git/' },
}))
```

### files

Show files under specified root directory.

| Name         | Type      | Default | Description            |
| ------------ | --------- | ------- | ---------------------- |
| ignore_globs | string[]? | []      | Ignore glob patterns.  |
| root_dir     | string    |         | Target root directory. |

```lua
deck.start(require('deck.builtin.source.files')({
  root_dir = vim.fn.getcwd(),
  ignore_globs = { '**/node_modules/', '**/.git/' },
}))
```

### items

Listing any provided items.

| Name  | Type                           | Default | Description    |
| ----- | ------------------------------ | ------- | -------------- |
| items | string[]\|deck.ItemSpecifier[] |         | Items to list. |

```lua
deck.start(require('deck.builtin.source.items')({
  items = vim.iter(vim.api.nvim_list_bufs()):map(function(buf)
    return ('#%s'):format(buf)
  end):totable()
}))
```

### buffers

Show buffers.

| Name         | Type      | Default                | Description                                                         |
| ------------ | --------- | ---------------------- | ------------------------------------------------------------------- |
| ignore_paths | string[]? | [vim.fn.expand('%:p')] | Ignore paths. The default value is intented to hide current buffer. |
| nofile       | boolean?  | false                  | Ignore nofile buffers.                                              |

```lua
deck.start(require('deck.builtin.source.buffers')({
  ignore_paths = { vim.fn.expand('%:p'):gsub('/$', '') },
  nofile = false,
}))
```

### helpgrep

Live grep all helptags. (required `ripgrep`)

_No options_

```lua
deck.start(require('deck.builtin.source.helpgrep')())
```

### git.branch

Show git branches

| Name | Type   | Default | Description      |
| ---- | ------ | ------- | ---------------- |
| cwd  | string |         | Target git root. |

```lua
deck.start(require('deck.builtin.source.git.branch')({
  cwd = vim.fn.getcwd() 
}))
```

### recent_dirs

List recent directories.

| Name         | Type      | Default | Description   |
| ------------ | --------- | ------- | ------------- |
| ignore_paths | string[]? | []      | Ignore paths. |

```lua
deck.start(require('deck.builtin.source.recent_dirs')({
  ignore_paths = { '**/node_modules/', '**/.git/' },
}))
```

### deck.actions

Show available actions from |deck.Context|

| Name    | Type             | Default | Description |
| ------- | ---------------- | ------- | ----------- |
| context | \|deck.Context\| |         |             |

```lua
deck.start(require('deck.builtin.source.deck.actions')({
  context = context
}))
```

### deck.history

Show deck.start history.

_No options_

```lua
deck.start(require('deck.builtin.source.deck.history')())
```

### recent_files

List recent files.

| Name         | Type      | Default | Description   |
| ------------ | --------- | ------- | ------------- |
| ignore_paths | string[]? | []      | Ignore paths. |

```lua
deck.start(require('deck.builtin.source.recent_dirs')({
  ignore_paths = { '**/node_modules/', '**/.git/' },
}))
```

### git.changeset

Show git changeset for specified revision.

| Name     | Type    | Default | Description                                            |
| -------- | ------- | ------- | ------------------------------------------------------ |
| cwd      | string  |         | Target git root.                                       |
| from_rev | string  |         | From revision.                                         |
| to_rev   | string? |         | To revision. If you omit this option, it will be HEAD. |

```lua
deck.start(require('deck.builtin.source.git.changeset')({
  cwd = vim.fn.getcwd(),
  from_rev = 'HEAD~3',
  to_rev = 'HEAD'
}))
```

<!-- auto-generate-e:source -->

## Actions

<!-- auto-generate-s:action -->

- `yank`
  - Yank item.display_text field to default register.

- `prompt`
  - Open filtering prompt

- `refresh`
  - Re-execute source. (it can be used to refresh the items)

- `substitute`
  - Open substitute buffer with selected items (`item.data.filename` and
    `item.data.lnum` are required).

    You can modify and save the buffer to reflect the changes to the original
    files.

- `choose_action`
  - Open action source.

    The actions listed are filtered by whether they are valid in the current
    context.

- `toggle_select`
  - Toggle selected state of the cursor item.

- `scroll_preview_up`
  - Scroll preview window up.

- `toggle_select_all`
  - Toggle selected state of all items.

- `scroll_preview_down`
  - Scroll preview window down.

- `toggle_preview_mode`
  - Toggle preview mode

<!-- auto-generate-e:action -->

## Autocmd

<!-- auto-generate-s:autocmd -->

- `DeckStart`
  - Triggered when deck starts.

- `DeckStart:{source_name}`
  - Triggered when deck starts for source.

<!-- auto-generate-e:autocmd -->

# API

<!-- auto-generate-s:api -->

<!-- panvimdoc-include-comment deck.setup(config) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.setup(config)

<!-- panvimdoc-ignore-end -->

Setup deck globally.

| Name   | Type                 | Description               |
| ------ | -------------------- | ------------------------- |
| config | deck.ConfigSpecifier | Setup deck configuration. |

&nbsp;

<!-- panvimdoc-include-comment deck.register_action(action) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.register_action(action)

<!-- panvimdoc-ignore-end -->

Register action.

| Name   | Type            | Description         |
| ------ | --------------- | ------------------- |
| action | \|deck.Action\| | action to register. |

&nbsp;

<!-- panvimdoc-include-comment deck.remove_actions(predicate) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.remove_actions(predicate)

<!-- panvimdoc-ignore-end -->

Remove specific action.

| Name      | Type                                  | Description                                        |
| --------- | ------------------------------------- | -------------------------------------------------- |
| predicate | fun(action: \|deck.Action\|): boolean | Predicate function. If return true, remove action. |

&nbsp;

<!-- panvimdoc-include-comment deck.remove_decorators(predicate) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.remove_decorators(predicate)

<!-- panvimdoc-ignore-end -->

Remove specific decorator.

| Name      | Type                                        | Description                                           |
| --------- | ------------------------------------------- | ----------------------------------------------------- |
| predicate | fun(decorator: \|deck.Decorator\|): boolean | Predicate function. If return true, remove decorator. |

&nbsp;

<!-- panvimdoc-include-comment deck.remove_previewers(predicate) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.remove_previewers(predicate)

<!-- panvimdoc-ignore-end -->

Remove previewer.

| Name      | Type                                        | Description                                           |
| --------- | ------------------------------------------- | ----------------------------------------------------- |
| predicate | fun(previewer: \|deck.Previewer\|): boolean | Predicate function. If return true, remove previewer. |

&nbsp;

<!-- panvimdoc-include-comment deck.register_decorator(decorator) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.register_decorator(decorator)

<!-- panvimdoc-ignore-end -->

Register decorator.

| Name      | Type               | Description            |
| --------- | ------------------ | ---------------------- |
| decorator | \|deck.Decorator\| | decorator to register. |

&nbsp;

<!-- panvimdoc-include-comment deck.register_previewer(previewer) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.register_previewer(previewer)

<!-- panvimdoc-ignore-end -->

Register previewer.

| Name      | Type               | Description            |
| --------- | ------------------ | ---------------------- |
| previewer | \|deck.Previewer\| | previewer to register. |

&nbsp;

<!-- panvimdoc-include-comment deck.get_actions(): |deck.Action|[] ~ -->

<!-- panvimdoc-ignore-start -->

### deck.get_actions(): |deck.Action|[]

<!-- panvimdoc-ignore-end -->

Get all registered actions.

_No arguments_ &nbsp;

<!-- panvimdoc-include-comment deck.get_history(): |deck.Context|[] ~ -->

<!-- panvimdoc-ignore-start -->

### deck.get_history(): |deck.Context|[]

<!-- panvimdoc-ignore-end -->

Get all history (first history is latest).

_No arguments_ &nbsp;

<!-- panvimdoc-include-comment deck.remove_start_presets(predicate) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.remove_start_presets(predicate)

<!-- panvimdoc-ignore-end -->

Remove specific start_preset.

| Name      | Type                                             | Description                                              |
| --------- | ------------------------------------------------ | -------------------------------------------------------- |
| predicate | fun(start_preset: \|deck.StartPreset\|): boolean | Predicate function. If return true, remove start_preset. |

&nbsp;

<!-- panvimdoc-include-comment deck.register_start_preset(start_preset) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.register_start_preset(start_preset)

<!-- panvimdoc-ignore-end -->

Register start_preset.

| Name         | Type             | Description          |
| ------------ | ---------------- | -------------------- |
| start_preset | deck.StartPreset | \|deck.StartPreset\| |

&nbsp;

<!-- panvimdoc-include-comment deck.get_decorators(): |deck.Decorator|[] ~ -->

<!-- panvimdoc-ignore-start -->

### deck.get_decorators(): |deck.Decorator|[]

<!-- panvimdoc-ignore-end -->

Get all registered decorators.

_No arguments_ &nbsp;

<!-- panvimdoc-include-comment deck.get_previewers(): |deck.Previewer|[] ~ -->

<!-- panvimdoc-ignore-start -->

### deck.get_previewers(): |deck.Previewer|[]

<!-- panvimdoc-ignore-end -->

Get all registered previewers.

_No arguments_ &nbsp;

<!-- panvimdoc-include-comment deck.register_start_preset(name, start_fn) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.register_start_preset(name, start_fn)

<!-- panvimdoc-ignore-end -->

Register start_preset.

| Name     | Type   | Description     |
| -------- | ------ | --------------- |
| name     | string | preset name.    |
| start_fn | fun()  | Start function. |

&nbsp;

<!-- panvimdoc-include-comment deck.get_start_presets(): |deck.StartPreset|[] ~ -->

<!-- panvimdoc-ignore-start -->

### deck.get_start_presets(): |deck.StartPreset|[]

<!-- panvimdoc-ignore-end -->

Get all registered start presets.

_No arguments_ &nbsp;

<!-- panvimdoc-include-comment deck.start(sources, start_config): |deck.Context| ~ -->

<!-- panvimdoc-ignore-start -->

### deck.start(sources, start_config): |deck.Context|

<!-- panvimdoc-ignore-end -->

Start deck with given sources.

| Name         | Type                        | Description                 |
| ------------ | --------------------------- | --------------------------- |
| source       | deck.Source\\|deck.Source[] | source or sources to start. |
| start_config | deck.StartConfigSpecifier   | start configuration.        |

&nbsp;

<!-- panvimdoc-include-comment deck.action_mapping(mapping): fun(ctx: |deck.Context|) ~ -->

<!-- panvimdoc-ignore-start -->

### deck.action_mapping(mapping): fun(ctx: |deck.Context|)

<!-- panvimdoc-ignore-end -->

Create action mapping function for ctx.keymap.

| Name         | Type              | Description                                      |
| ------------ | ----------------- | ------------------------------------------------ |
| action_names | string\\|string[] | action name or action names to use for mappings. |

&nbsp;

<!-- panvimdoc-include-comment deck.alias_action(alias_name, alias_action_name): |deck.Action| ~ -->

<!-- panvimdoc-ignore-start -->

### deck.alias_action(alias_name, alias_action_name): |deck.Action|

<!-- panvimdoc-ignore-end -->

Create alias action.

| Name              | Type   | Description           |
| ----------------- | ------ | --------------------- |
| alias_name        | string | new action name.      |
| alias_action_name | string | existing action name. |

&nbsp;

<!-- auto-generate-e:api -->

# Type

<!-- auto-generate-s:type -->

```vimdoc
*deck.Item*
```

```lua
---@class deck.Item: deck.ItemSpecifier
---@field public display_text string
---@field public data table
```

```vimdoc
*deck.View*
```

```lua
---@class deck.View
---@field public get_win fun(): integer?
---@field public is_visible fun(ctx: deck.Context): boolean
---@field public show fun(ctx: deck.Context)
---@field public hide fun(ctx: deck.Context)
---@field public prompt fun(ctx: deck.Context)
---@field public scroll_preview fun(ctx: deck.Context, delta: integer)
---@field public render fun(ctx: deck.Context)
```

```vimdoc
*deck.Action*
```

```lua
---@class deck.Action
---@field public name string
---@field public desc? string
---@field public hidden? boolean
---@field public resolve? deck.ActionResolveFunction
---@field public execute deck.ActionExecuteFunction
---@alias deck.ActionResolveFunction fun(ctx: deck.Context): any
---@alias deck.ActionExecuteFunction fun(ctx: deck.Context)
```

```vimdoc
*deck.Config*
```

```lua
---@class deck.Config: deck.ConfigSpecifier
---@field public max_history_size integer
---@field public default_start_config? deck.StartConfigSpecifier
```

```vimdoc
*deck.Source*
```

```lua
---@class deck.Source
---@field public name string
---@field public dynamic? boolean
---@field public events? { Start?: fun(ctx: deck.Context), BufWinEnter?: fun(ctx: deck.Context) }
---@field public execute deck.SourceExecuteFunction
---@field public actions? deck.Action[]
---@field public decorators? deck.Decorator[]
---@field public previewers? deck.Previewer[]
---@alias deck.SourceExecuteFunction fun(ctx: deck.ExecuteContext)
```

```vimdoc
*deck.Context*
```

```lua
---@class deck.Context
---@field id integer
---@field ns integer
---@field buf integer
---@field name string
---@field execute fun()
---@field is_visible fun(): boolean
---@field show fun()
---@field hide fun()
---@field prompt fun()
---@field scroll_preview fun(delta: integer)
---@field get_status fun(): deck.Context.Status
---@field get_cursor fun(): integer
---@field set_cursor fun(cursor: integer)
---@field get_query fun(): string
---@field set_query fun(query: string)
---@field set_selected fun(item: deck.Item, selected: boolean)
---@field get_selected fun(item: deck.Item): boolean
---@field set_select_all fun(select_all: boolean)
---@field get_select_all fun(): boolean
---@field set_preview_mode fun(preview_mode: boolean)
---@field get_preview_mode fun(): boolean
---@field get_items fun(): deck.Item[]
---@field get_cursor_item fun(): deck.Item?
---@field get_action_items fun(): deck.Item[]
---@field get_filtered_items fun(): deck.Item[]
---@field get_selected_items fun(): deck.Item[]
---@field get_actions fun(): deck.Action[]
---@field get_decorators fun(): deck.Decorator[]
---@field get_previewer fun(): deck.Previewer?
---@field get_revision fun(): deck.Context.Revision
---@field get_source_names fun(): string[]
---@field sync fun(option: { count: integer })
---@field keymap fun(mode: string, lhs: string, rhs: fun(ctx: deck.Context))
---@field do_action fun(name: string)
---@field dispose fun()
---@field disposed fun(): boolean
---@field on_dispose fun(callback: fun()): fun()
```

```vimdoc
*deck.Decorator*
```

```lua
---@class deck.Decorator
---@field public name string
---@field public resolve? deck.DecoratorResolveFunction
---@field public decorate deck.DecoratorDecorateFunction
---@alias deck.DecoratorResolveFunction fun(ctx: deck.Context, item: deck.Item): any
---@alias deck.DecoratorDecorateFunction fun(ctx: deck.Context, item: deck.Item, row: integer): any
```

```vimdoc
*deck.Previewer*
```

```lua
---@class deck.Previewer
---@field public name string
---@field public resolve? deck.PreviewerResolveFunction
---@field public preview deck.PreviewerPreviewFunction
---@alias deck.PreviewerResolveFunction fun(ctx: deck.Context): any
---@alias deck.PreviewerPreviewFunction fun(ctx: deck.Context, env: { win: integer })
```

```vimdoc
*deck.StartConfig*
```

```lua
---@class deck.StartConfig: deck.StartConfigSpecifier
---@field public name string
---@field public view fun(): deck.View
---@field public matcher deck.Matcher
---@field public history boolean
---@field public performance { interrupt_interval: integer, interrupt_timeout: integer }
```

```vimdoc
*deck.StartPreset*
```

```lua
---@class deck.StartPreset
---@field public name string
---@field public args? table<string|integer, fun(input: string): string[]>
---@field public start fun(args: table<string|integer, string>)
```

```vimdoc
*deck.ItemSpecifier*
```

```lua
---@class deck.ItemSpecifier
---@field public display_text string|(deck.VirtualText[])
---@field public highlights? deck.Highlight[]
---@field public filter_text? string
---@field public data? table
```

```vimdoc
*deck.ExecuteContext*
```

```lua
---@class deck.ExecuteContext
---@field public item fun(item: deck.ItemSpecifier)
---@field public done fun( )
---@field public get_query fun(): string
---@field public aborted fun(): boolean
---@field public on_abort fun(callback: fun())
```

```vimdoc
*deck.ConfigSpecifier*
```

```lua
---@class deck.ConfigSpecifier
---@field public max_history_size? integer
---@field public default_start_config? deck.StartConfigSpecifier
```

```vimdoc
*deck.StartConfigSpecifier*
```

```lua
---@class deck.StartConfigSpecifier
---@field public name? string
---@field public view? fun(): deck.View
---@field public matcher? deck.Matcher
---@field public history? boolean
---@field public performance? { interrupt_interval: integer, interrupt_timeout: integer }
```

<!-- auto-generate-e:type -->
