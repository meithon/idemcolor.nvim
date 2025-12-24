# idemcolor

A Neovim extension to highlight same-name identifiers with the same color.

> **Note**: This is a maintained fork of [markid](https://github.com/David-Kunz/markid) by David Kunz, which is no longer actively maintained.

## Motivation

Syntax highlighting is mostly based on element kinds of the abstract syntax tree.
This sometimes leads to different visual representations of the same variable, consider this example:

<img src="https://user-images.githubusercontent.com/1009936/189521828-cca98d82-1959-4c7f-8d54-8f9bd9ceaa65.png" height="100">

Here, `myParam` has the colors yellow and white, making it hard for the developer to recognise that both represent the same thing.

Now with idemcolor, it's ensured that same-name identifiers are represented with the same color:

<img src="https://user-images.githubusercontent.com/1009936/189521962-680a28f2-2351-4c8c-96b1-12cc67ff59f4.png" height="100">

Here's a slightly more complicated example, try to track the flow of `qux`:

<img src="https://user-images.githubusercontent.com/1009936/189522794-cae13379-6b99-4976-b429-5e5414549945.png" height="500">

<img src="https://user-images.githubusercontent.com/1009936/189522795-12beae5d-dea5-463a-ad00-860282a3d040.png" height="500">


## Installation

Requirements: [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) including a parser for your language

For [vim-plug](https://github.com/junegunn/vim-plug):
```
Plug 'meithon/idemcolor.nvim'
```
For [packer](https://github.com/wbthomason/packer.nvim):
```
use 'meithon/idemcolor.nvim'
```
For [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{ 'meithon/idemcolor.nvim' }
```

### Option 1: Standalone setup (recommended for nvim-treesitter 1.0+)

```lua
require('idemcolor').setup()
```

### Option 2: Via nvim-treesitter module (legacy, for nvim-treesitter < 1.0)

```lua
require'nvim-treesitter.configs'.setup {
  idemcolor = { enable = true }
}
```

## Options

These are the configuration options (with defaults):

```lua
local m = require'idemcolor'

-- Standalone setup
m.setup({
  enable = true,
  colors = m.colors.medium,
  queries = m.queries,
})

-- Or via nvim-treesitter (legacy)
require'nvim-treesitter.configs'.setup {
  idemcolor = {
    enable = true,
    colors = m.colors.medium,
    queries = m.queries,
  }
}

m.colors = {
    dark = { "#619e9d", "#9E6162", "#81A35C", "#7E5CA3", "#9E9261", "#616D9E", "#97687B", "#689784", "#999C63", "#66639C" },
    bright = {"#f5c0c0", "#f5d3c0", "#f5eac0", "#dff5c0", "#c0f5c8", "#c0f5f1", "#c0dbf5", "#ccc0f5", "#f2c0f5", "#d8e4bc" },
    medium = { "#c99d9d", "#c9a99d", "#c9b79d", "#c9c39d", "#bdc99d", "#a9c99d", "#9dc9b6", "#9dc2c9", "#9da9c9", "#b29dc9" }
}

m.queries = {
  default = '(identifier) @idemcolor',
  javascript = [[
          (identifier) @idemcolor
          (property_identifier) @idemcolor
          (shorthand_property_identifier_pattern) @idemcolor
          (shorthand_property_identifier) @idemcolor
        ]]
}
m.queries.typescript = m.queries.javascript
```

The `m.queries` table above can be used to define language-specific highlighting rules via custom Treesitter queries. Alternatively, idemcolor can also source queries from standalone files located in your local runtime `queries/` directory. Simply create a new directory in your nvim config folder for your language of choice, e.g. `$HOME/.config/nvim/queries/python`, and write your query in a file called `idemcolor.scm`.

## Custom Highlight Groups

For more control, you can define the highlight groups `idemcolor1`, `idemcolor2`, ..., `idemcolor10`, this is especially useful for theme designers.

Example:
```lua
vim.api.nvim_set_hl(0, 'idemcolor1', { fg = '#c99d9d', bg = '#003844', underline = true })
vim.api.nvim_set_hl(0, 'idemcolor2', { fg = '#c9a99d', bg = '#003844', underline = true })
-- ...
vim.api.nvim_set_hl(0, 'idemcolor10', { fg = '#c9b79d', bg = '#003844', underline = true })
```
