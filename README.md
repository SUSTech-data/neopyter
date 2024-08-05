# Neopyter

The bridge between Neovim and Jupyter Lab, edit in Neovim and preview/run in Jupyter Lab.

<!--toc:start-->
- [Neopyter](#neopyter)
  - [How does it work?](#how-does-it-work)
  - [Screenshots](#screenshots)
  - [Requirements](#requirements)
  - [Installation](#installation)
    - [JupyterLab Extension](#jupyterlab-extension)
    - [Neovim plugin](#neovim-plugin)
  - [Quick Start](#quick-start)
  - [Available Vim Commands](#available-vim-commands)
  - [Integration](#integration)
    - [neoconf.nvim](#neoconfnvim)
    - [nvim-cmp](#nvim-cmp)
    - [nvim-treesitter-textobjects](#nvim-treesitter-textobjects)
  - [API](#api)
  - [Features](#features)
  - [Acknowledges](#acknowledges)
<!--toc:end-->

## How does it work?

This project includes two parts: a [`JupyterLab extension`](https://jupyterlab.readthedocs.io/en/stable/user/extensions.html) and a Neovim plugin

- The `JupyterLab extension` exposes functions of `Jupyter lab`, and provides a remote procedure call(RPC) service
- The `Neovim plugin` calls the RPC service when it receives events from `Neovim` via `autocmd`

This project provides two work modes for different network environments. If the browser where your jupyter lab is
located cannot directly access nvim, you must use `proxy` mode; If you need to collaborate and use the same Jupyter with
others, you must use direct mode

<table>
    <tr>
        <th></th>
        <th>direct</th>
        <th>proxy</th>
    </tr>
    <tr>
        <th>Architecture</th>
        <th style="text-align:center">
            <img alt="direct mode" src="./doc/communication_direct.png">
        </th>
        <th>
            <img alt="proxy mode" src="./doc/communication_proxy.png">
        </th>
    </tr>
    <tr>
        <th>Advantage</th>
        <th style="text-align:left;font-weight:lighter">
            <ul>
                <li>Lower communication costs</li>
                <li>Shareable JupyterLab instance</li>
            </ul>
        </th>
        <th style="text-align:left;font-weight:lighter">
            <ul>
                <li>Lower Neovim load</li>
            </ul>
        </th>
    </tr>
    <tr>
        <th>Disadvantage</th>
        <th style="text-align:left;font-weight:lighter">
            <ul>
                <li>Higher Neovim load</li>
            </ul>
        </th>
        <th style="text-align:left;font-weight:lighter">
            <ul>
                <li>Exclusive JupyterLab instance</li>
            </ul>
        </th>
    </tr>
</table>

- `direct` mode: (default, recommended) In this mode, neovim is server and neovim plugin(neopyter) is listening to `remote_address`,
  the browser where jupyter lab is located will connect to neovim

- `proxy` mode: In this mode, Jupyter lab server(server side, the host you run `jupyter lab` to start JupyterLab) is server
  and jupyter lab server extension(neopyter) is listening to `${IP}:{Port}`, the neovim plugin(neopyter) will connect to `${IP}:{Port}`

Ultimately, `Neopyter` can control `Juppyter lab`. `Neopyter` can implement abilities like [jupynium.nvim](https://github.com/kiyoon/jupynium.nvim).

## Screenshots

<table>
    <tr>
        <th></th>
        <th>Completion</th>
        <th>Cell Magic</th>
        <th>Line Magic</th>
    </tr>
    <tr>
        <th>
        </th>
        <th>
            <img alt="Completion" width="100%" src="./doc/completion.png">
        </th>
        <th>
            <img alt="Cell Magic" src="./doc/cell_magic.png">
        </th>
        <th>
            <img alt="Line Magic" src="./doc/line_magic.png">
        </th>
    </tr>
</table>

## Requirements

- 📔JupyterLab >= 4.0.0
- ✌️ Neovim nightly
  - 👍`nvim-lua/plenary.nvim`
  - 🤏`AbaoFromCUG/websocket.nvim` (optional for `mode="direct"`)

## Installation

### JupyterLab Extension

To install the jupyterlab extension, execute:

```bash
pip install neopyter
```

Configure `JupyterLab` in side panel
<img alt="Neopyter side panel" width="50%" src="./doc/sidepanel.png"/>

- `mode`: Refer to the previous introduction about mode
- `IP`: If `mode=proxy`, set to the IP of the host where jupyter server is located. If `proxy=direct`, set to the IP of the
  host where neovim is located
- `Port`: Idle port of the `IP`'s' host


*NOTICE:* all settings is saved to localStorage

### Neovim plugin

With 💤lazy.nvim:

```lua

{
    "SUSTech-data/neopyter",
    ---@type neopyter.Option
    opts = {
        mode="direct",
        remote_address = "127.0.0.1:9001",
        file_pattern = { "*.ju.*" },
        trim_whitespace = false,
        on_attach = function(bufnr)
            -- do some buffer keymap
        end,
        highlight = {
            enable = true,
            shortsighted = false,
        }
    },
}
```

Suggest keymaps(`neopyter` don't provide default keymap):

```lua
on_attach = function(buf)
    local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { desc = desc, buffer = buf })
    end
    -- same, recommend the former
    map("n", "<C-Enter>", "<cmd>Neopyter execute notebook:run-cell<cr>", "run selected")
    -- map("n", "<C-Enter>", "<cmd>Neopyter run current<cr>", "run selected")

    -- same, recommend the former
    map("n", "<space>X", "<cmd>Neopyter execute notebook:run-all-above<cr>", "run all above cell")
    -- map("n", "<space>X", "<cmd>Neopyter run allAbove<cr>", "run all above cell")

    -- same, recommend the former, but the latter is silent
    map("n", "<space>nt", "<cmd>Neopyter execute kernelmenu:restart<cr>", "restart kernel")
    -- map("n", "<space>nt", "<cmd>Neopyter kernel restart<cr>", "restart kernel")

    map("n", "<S-Enter>", "<cmd>Neopyter execute runmenu:run<cr>", "run selected and select next")
    map("n", "<M-Enter>", "<cmd>Neopyter execute run-cell-and-insert-below<cr>", "run selected and insert below")

    map("n", "<F5>", "<cmd>Neopyter execute notebook:restart-run-all<cr>", "restart kernel and run all")
end
```

## Quick Start

- Open JupyterLab `jupyter lab`, there is a sidebar named `Neopyter`, which display neopyter ip+port
- Open a `*.ju.py` file in neovim
- Now you can type `# %%` in Neovim to create a code cell.
  - You'll see everything you type below that will be synchronised in the browser

## Available Vim Commands

- Status
  - `:Neopyter status` alias to `:checkhealth neopyter` currently
- Server
  - `:Neopyter connect [remote 'ip:port']`, e.g. `:Neopyter command 127.0.0.1:9001`, connect `Jupyter lab` manually
  - `:Neopyter disconnect`
- Sync
  - `:Neopyter sync current`, make sync current `*.ju.*` file with the currently open `*.ipynb`
  - `:Neopyter sync [filename]`, e.g. `:Neopyter sync main.ipynb`
- Run
  - `:Neopyter run current`, same as `Run`>`Run Selected Cell and Do not Advance` menu in `Jupyter lab`
  - `:Neopyter run allAbove`, same as `Run`>`Run All Above Selected Cell` menu in `Jupyter lab`
  - `:Neopyter run allBelow`, same as `Run`>`Run Selected Cell and All Below` menu in `Jupyter lab`
  - `:Neopyter run all`, same as `Run`>`Run All Cells` menu in `Jupyter lab`
- Kernel
  - `:Neopyter kernel restart`, same as `Kernel`>`Restart Kernel` menu in `Jupyter lab`
  - `:Neopyter kernel restartRunAll`, same as `Kernel`>`Restart Kernel and Run All Cells` menu in `Jupyter lab`
- Jupyter
  - `:Neopyter execute [command_id] [args]`, execute `Jupyter lab`'s
    [command](https://jupyterlab.readthedocs.io/en/stable/user/commands.html#commands-list)
    directly, e.g. `:Neopyter execute notebook:export-to-format {"format":"html"}`


## Integration

### neoconf.nvim

If [neoconf.nvim](https://github.com/SUSTech-data/neopyter) is available, `neopyter` will automatically register/read `neoconf` settings

[`.neoconf.json`](./.neoconf.json)

```json
{
  "neopyter": {
    "mode": "proxy",
    "remote_address": "127.0.0.1:9001"
  }
}
```

### nvim-cmp

- `nvim-cmp`
- `lspkind.nvim`

```lua

local lspkind = require("lspkind")
local cmp = require("cmp")

cmp.setup({
    sources = cmp.config.sources({
        -- addition source
        { name = "neopyter" },
    }),
    formatting = {
        format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
            menu = {
                neopyter = "[Neopyter]",
            },
            symbol_map = {
                -- specific complete item kind icon
                ["Magic"] = "🪄",
                ["Path"] = "📁",
                ["Dict key"] = "🔑",
                ["Instance"]="󱃻",
                ["Statement"]="󱇯",
            },
        }),
    },
)}

    -- menu item highlight
vim.api.nvim_set_hl(0, "CmpItemKindMagic", { bg = "NONE", fg = "#D4D434" })
vim.api.nvim_set_hl(0, "CmpItemKindPath", { link = "CmpItemKindFolder" })
vim.api.nvim_set_hl(0, "CmpItemKindDictkey", { link = "CmpItemKindKeyword" })
vim.api.nvim_set_hl(0, "CmpItemKindInstance", { link = "CmpItemKindVariable" })
vim.api.nvim_set_hl(0, "CmpItemKindStatement", { link = "CmpItemKindVariable" })

```

More information, see [nvim-cmp wiki](https://github.com/hrsh7th/nvim-cmp/wiki/Menu-Appearance)

### nvim-treesitter-textobjects

Supported captures in `textobjects` query group

- @cell
  - @cell.code
  - @cell.magic
  - @cell.markdown
  - @cell.raw
  - @cell.special
- @cellseparator
  - @cellseparator.code
  - @cellseparator.magic
  - @cellseparator.markdown
  - @cellseparator.raw
  - @cellseparator.special
- @cellbody
  - @cellbody.code
  - @cellbody.magic
  - @cellbody.markdown
  - @cellbody.raw
  - @cellbody.special
- @cellcontent
  - @cellcontent.code
  - @cellcontent.magic
  - @cellcontent.markdown
  - @cellcontent.raw
  - @cellcontent.special
- @cellborder
  - @cellborder.start
    - @cellborder.start.markdown
    - @cellborder.start.raw
    - @cellborder.start.special
  - @cellborder.end
    - @cellborder.end.markdown
    - @cellborder.end.raw
    - @cellborder.end.special
- @linemagic

```lua
require'nvim-treesitter.configs'.setup {
    textobjects = {
        move = {
            enable = true,
            goto_next_start = {
                ["]j"] = "@cellseparator",
                ["]c"] = "@cellcontent",
            },
            goto_previous_start = {
                ["[j"] = "@cellseparator",
                ["[c"] = "@cellcontent",
            },
        },
    },
}

```

## API

`Neopyter` provides rich lua APIs

- Jupyter Lab

  - `Neopyter execute ...` <-> `require("neopyter.jupyter").jupyterlab:execute_command(...)`
  - All APIs see `:lua =require("neopyter.jupyter.jupyterlab").__injected_methods`

- Notebook
  - `:Neopyter run current` <-> `require("neopyter.jupyter").notebook:run_selected_cell()`
  - `:Neopyter run allAbove` <-> `require("neopyter.jupyter").notebook:run_all_above()`
  - `:Neopyter run allBelow` <-> `require("neopyter.jupyter").notebook:run_all_below()`
  - All APIs see `:lua =require("neopyter.jupyter.notebook").__injected_methods`

## Features

- Neovim
  - [x] Full sync
  - [x] Partial sync
  - [x] Scroll view automatically
  - [x] Activate cell automatically
  - [x] Save notebook automatically
  - Completion
    - [x] Magic completion item
    - [x] Path completion item
    - [ ] Disable others?
  - Tree-sitter
    - [x] Highlight
      - Separator+non-code
      - Shortsighted
    - [x] Textobjects
    - [ ] Fold
  - Kernel manage
    - [x] Restart kernel
    - [x] Restart kernel and run all
  - Run cell
    - [x] Run selected cell
    - [x] Run all above selected cell
    - [x] Run selected cell and all below
    - [x] Run all cell
  - Sync
    - [x] Set synchronized `.ipynb` manually
  - Notebook manager
    - [x] Open corresponding notebook if exists
    - [x] Sync with untitled notebook default
    - [ ] Close notebook when buffer unload
- Jupyter Lab
  - Settings
    - [x] TCP server host/port settings
  - Status [Sidebar](https://jupyterlab.readthedocs.io/en/stable/user/interface.html#left-and-right-sidebar)
    - [x] Settings `ip:port`
    - [ ] Display client info
- Performance
  - [x] Rewrite `RpcClient`, support async RPC request
        `vim.rpcrequest` and `vim.rpcnotify`
- Document
  - [ ] API Document

## Acknowledges

- [jupynium.nvim](https://github.com/kiyoon/jupynium.nvim): Selenium-automated Jupyter Notebook that is synchronised with Neovim in real-time.
