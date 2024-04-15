# JupyterLab + Neovim

- A JupyterLab extension.
- A Neovim plugin

## How does it work?

This project includes two parts: a [`JupyterLab extension`](https://jupyterlab.readthedocs.io/en/stable/user/extensions.html) and a Neovim plugin

- The `JupyterLab extension` exposes functions of `Jupyter lab`, and provides a remote procedure call(RPC) service
- The `Neovim plugin` calls the RPC service when it receives events from `Neovim` via `autocmd`

|                           proxy                            |                            direct                            |
| :--------------------------------------------------------: | :----------------------------------------------------------: |
| <img alt="proxy mode" src="./doc/communication_proxy.png"> | <img alt="direct mode" src="./doc/communication_direct.png"> |

This project provides two working modes for different network environments. If the browser where your jupyiter lab is
located cannot directly access nvim, you must use `proxy` mode; If you need to collaborate and use the same Jupyter with
others, you must use direct mode

- `proxy` mode: Jupyterlab server
  proxies the RPC service as a TCP server which `Neovim`s plugin connects to
- `direct` mode: Neovim plugin accesses these RPC service directly

Ultimately, `Neopyter` can control `Juppyter lab`. `Neopyter` can implement abilities like [jupynium.nvim](https://github.com/kiyoon/jupynium.nvim).

## Screenshots

|                    Completion                     |                    Cell Magic                     |                    Line Magic                     |
| :-----------------------------------------------: | :-----------------------------------------------: | :-----------------------------------------------: |
| <img alt="Completion" src="./doc/completion.png"> | <img alt="Cell Magic" src="./doc/cell_magic.png"> | <img alt="Line Magic" src="./doc/line_magic.png"> |

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
![side panel](./doc/sidepanel.png)

- `mode`: refer to the previous introduction about mode
- `IP`: if `mode=proxy`, set to the IP of the host where jupyter is located. If `proxy=direct`, set to the IP of the
  host where neovim is located
- `port`: idle port

### Neovim plugin

With 💤lazy.nvim:

```lua
{
    "SUSTech-data/neopyter",
    opts = {
        -- auto define autocmd
        auto_attach = true,
        -- auto connect rpc service
        auto_connect = true,
        mode="direct",
        -- same with JupyterLab settings
        remote_address = "127.0.0.1:9001",
        file_pattern = { "*.ju.*" },
        on_attach = function(bufnr)
        end,

        highlight = {
            enable = true,
            shortsighted = true,
        }
    },
}
```

#### Integration

##### nvim-cmp

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

##### nvim-treesitter-textobjects

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

## Quick Start

- Open JupyterLab `jupyter lab`, there is a sidebar named `Neopyter`, which display neopyter ip+port
- Open a `*.ju.py` file in neovim
- Now you can type `# %%` in Neovim to create a code cell.
  - You'll see everything you type below that will be synchronised in the browser

### Available Vim Commands

- Server
  - `:Neopyter connect [remote 'ip:port']`, e.g. `:Neopyter command 127.0.0.1:9001`, connect `Jupyter lab` manually
  - `:Neopyter disconnect`
  - `:Neopyter status` alias to `:checkhealth neopyter` currently
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
  - `:Neopyter execute [command_id] [args]`, execute `Jupyter lab`'s [command](https://jupyterlab.readthedocs.io/en/stable/user/commands.html#commands-list) directly, e.g. `:Neopyter execute notebook:export-to-format {"format":"html"}`

### API

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
    - [x] Tcp server host/port settings
  - Status [Sidebar](https://jupyterlab.readthedocs.io/en/stable/user/interface.html#left-and-right-sidebar)
    - [x] Display `ip:port`
    - [ ] Display client info
- Performance
  - [x] Rewrite `RpcClient`, support async rpc request
        `vim.rpcrequest` and `vim.rpcnotify`
- Document
  - [ ] API Document

## Acknowledges

- [jupynium.nvim](https://github.com/kiyoon/jupynium.nvim): Selenium-automated Jupyter Notebook that is synchronised with NeoVim in real-time.
