# OmniBuf for Vim & Neovim (`omnibuf-vim`)

[![Wire Spec: v0.1](https://img.shields.io/badge/spec-v0.1-111111?style=flat&labelColor=111111&color=FF4F18)](https://omnibuf.com/spec)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)
[![Website](https://img.shields.io/badge/website-omnibuf.com-111111?style=flat&labelColor=111111&color=D4FF33)](https://omnibuf.com)

Inspect and edit `.obuf` binary files directly in Vim and Neovim. Opening any `*.obuf` file decodes it through the [`omnibuf` CLI](https://github.com/omnibuf/omnibuf-cli) and displays editable, syntax-highlighted JSON by default. Saving (`:w`) re-encodes the JSON back to binary `.obuf` wire bytes via `omnibuf encode` atomically, and refreshes any open hex split.

---

## Requirements

- Vim 8+ or Neovim
- [`omnibuf` CLI](https://github.com/omnibuf/omnibuf-cli) on your `PATH` (or configured via `g:omnibuf_cli`):
  ```bash
  brew install omnibuf/tap/omnibuf
  ```
- `xxd` (bundled with Vim), `hexdump`, or `od` for the hex view

---

## Installation

### lazy.nvim (Neovim)

```lua
{ "omnibuf/omnibuf-vim" }
```

### vim-plug

```vim
Plug 'omnibuf/omnibuf-vim'
```

### packer.nvim

```lua
use "omnibuf/omnibuf-vim"
```

### Vim 8+ / Neovim Native Packages

```bash
# Vim
git clone https://github.com/omnibuf/omnibuf-vim.git \
  ~/.vim/pack/plugins/start/omnibuf-vim

# Neovim
git clone https://github.com/omnibuf/omnibuf-vim.git \
  ~/.local/share/nvim/site/pack/plugins/start/omnibuf-vim
```

Generate help tags inside Vim with `:helptags ALL`.

---

## Usage

Open an existing or new `.obuf` file normally:

```bash
vim peer.obuf
```

- Existing files decode via `omnibuf decode` into an editable JSON buffer (`filetype=json`, `buftype=acwrite`).
- Nonexistent `*.obuf` files open with an editable `{}` JSON template that encodes on `:w`.
- Saving (`:w`) pipes the JSON buffer through `omnibuf encode` to a temporary file and atomically replaces the target `.obuf` file. Invalid JSON reports the CLI error and leaves the file on disk untouched.
- Companion `:OmnibufSplit` hex windows refresh automatically when you save.
- Hex views and decode-error buffers remain read-only (`nomodifiable`).

### Commands

| Command | Action |
| :--- | :--- |
| `:OmnibufJson` | Show decoded editable JSON in the current buffer |
| `:OmnibufHex` | Show the read-only canonical hex dump of the `.obuf` file (`filetype=xxd`) |
| `:OmnibufToggle` | Toggle the current buffer between JSON and hex views |
| `:OmnibufSplit` | Open or close a side-by-side companion split with the opposite view |
| `:OmnibufRefresh` | Re-read and re-decode the `.obuf` file from disk |
| `:OmnibufSchema [path] [type]` | Set a buffer-local `FileDescriptorSet` (`-s`) and optional message type (`-t`) |

---

## Configuration

```vim
" Path to the omnibuf CLI executable (default: 'omnibuf')
let g:omnibuf_cli = 'omnibuf'

" Default view when opening *.obuf files: 'json' (default), 'hex', or 'split'
let g:omnibuf_default_view = 'json'

" Optional default FileDescriptorSet and message type
let g:omnibuf_schema = ''
let g:omnibuf_type = ''

" Include Field #0 inline field names when encoding in schema-less mode (default: 1)
let g:omnibuf_field0 = 1

" Sort map keys and schema fields deterministically when encoding (default: 0)
let g:omnibuf_deterministic = 0

" Custom hex dump command (auto-detects xxd, hexdump -C, or od when empty)
let g:omnibuf_hex_cmd = ''

" Split command used by :OmnibufSplit (default: 'botright vnew')
let g:omnibuf_split_cmd = 'botright vnew'
```

See `:help omnibuf` for full documentation.

---

## Testing

```bash
./test/run_tests.sh
```

## License

Released under the [Apache 2.0 License](./LICENSE).
