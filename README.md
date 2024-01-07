# JupyterLab + Neovim

- A JupyterLab extension.
- A Neovim plugin

## Installation

### Requirements

- JupyterLab >= 4.0.0
- Neovim >= 9.0

### JupyterLab Extension

To install the jupyterlab extension, execute:

```bash
pip install git+https://github.com/SUSTech-data/neopyter.git
```

To remove the extension, execute:

```bash
pip uninstall neopyter
```

### Neovim plugin

With 💤lazy.nvim:

```lua
{
    "SUSTech-data/neopyter",
    opts = {
        auto_attach = true,
        -- your jupyter host + neopyter port
        remote_address = "127.0.0.1:9001",
        file_pattern = { "*.ju.*" },
    }
}
```

## Quick Start

- Open JupyterLab `jupyter lab`, there is a sidepane named `Neopyter`, which diplay neopyter ip+port
- Open a `*.ju.py` file in neovim
- [Optional] if `auto_attach` is `false`, you can connect jupyterlab manually via `:Neopyter connect 127.0.0.1:9001`
- Now you can type `# %%` in Neovim to create a code cell.
  - You'll see everything you type below that will be synchronised in the browser

## Features

- Notebook
  - [x] Full sync
  - [ ] Partial sync: need diff utility
  - [x] Scoll view automatically
  - [x] Activate cell automatically
  - [x] Save notebook automatically
- Jupyter Lab
  - Notebook manager
    - [x] Open corresponding notebook if exists
    - [x] Sync with untitled notebook default
    - [ ] Close notebook when buf unload
  - Status SidePanel
    - [x] Display `ip:port`
    - [ ] Display client info
- Performance
  - [ ] Use [promise-async](https://github.com/kevinhwang91/promise-async) and `luv` rewrite RpcClient, replace
        `vim.rpcrequest` and `vim.rpcnotify`

## Acknowledges

- [jupynium.nvim](https://github.com/kiyoon/jupynium.nvim): Selenium-automated Jupyter Notebook that is synchronised with NeoVim in real-time.

## Contributing

### JupyterLab Extension

#### Development install

Note: You will need NodeJS to build the extension package. Recommend use `pnpm`

```bash
# Clone the repo to your local environment
# Change directory to the current project directory
# Install package in development mode
pip install -e "."
# Link your development version of the extension with JupyterLab
jupyter labextension develop . --overwrite
# Rebuild extension Typescript source after making changes
pnpm build
```

You can watch the source directory and run JupyterLab at the same time in different terminals to watch for changes in the extension's source and automatically rebuild the extension.

```bash
# Watch the source directory in one terminal, automatically rebuilding when needed
pnpm watch
# Run JupyterLab in another terminal
jupyter lab
```

With the watch command running, every saved change will immediately be built locally and available in your running JupyterLab. Refresh JupyterLab to load the change in your browser (you may need to wait several seconds for the extension to be rebuilt).

By default, the `pnpm build` command generates the source maps for this extension to make it easier to debug using the browser dev tools. To also generate source maps for the JupyterLab core extensions, you can run the following command:

```bash
jupyter lab build --minimize=False
```

#### Development uninstall

```bash
pip uninstall neopyter
```

In development mode, you will also need to remove the symlink created by `jupyter labextension develop`
command. To find its location, you can run `jupyter labextension list` to figure out where the `labextensions`
folder is located. Then you can remove the symlink named `neopyter` within that folder.

#### Testing the extension

##### Frontend tests

This extension is using [Jest](https://jestjs.io/) for JavaScript code testing.

To execute them, execute:

```sh
pnpm
pnpm test
```

##### Integration tests

This extension uses [Playwright](https://playwright.dev/docs/intro) for the integration tests (aka user level tests).
More precisely, the JupyterLab helper [Galata](https://github.com/jupyterlab/jupyterlab/tree/master/galata) is used to handle testing the extension in JupyterLab.

More information are provided within the [ui-tests](./ui-tests/README.md) README.

#### Packaging the extension

See [RELEASE](RELEASE.md)
