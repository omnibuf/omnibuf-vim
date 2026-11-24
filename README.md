# omnibuf-vim

[![OmniBuf Spec: v1 DRAFT-1](https://img.shields.io/badge/OmniBuf%20Spec-v1%20DRAFT--1-FF4F18)](https://omnibuf.com/spec)

Vim 8+ and Neovim plugin for inspecting and editing `.obuf` binary files. Part of the [OmniBuf](https://omnibuf.com) [tooling suite](https://omnibuf.com/tooling).

## Install

Requires the [`omnibuf` CLI](https://github.com/omnibuf/omnibuf-cli) on your `PATH` (plus `xxd`, `hexdump`, or `od` for hex views):

```bash
brew install omnibuf/tap/omnibuf
```

Install the plugin with your package manager or native packages:

```lua
-- lazy.nvim
{ "omnibuf/omnibuf-vim" }
```

```vim
" vim-plug
Plug 'omnibuf/omnibuf-vim'
```

```bash
# Vim / Neovim native packages
git clone https://github.com/omnibuf/omnibuf-vim.git ~/.vim/pack/plugins/start/omnibuf-vim
git clone https://github.com/omnibuf/omnibuf-vim.git ~/.local/share/nvim/site/pack/plugins/start/omnibuf-vim
```

Run `:helptags ALL` inside Vim to index `:help omnibuf`. Run `./test/run_tests.sh` to execute the test suite.

## Usage & Commands

Open any `*.obuf` file (`vim peer.obuf`). Existing files decode into an editable JSON buffer (`buftype=acwrite`); new files start with `{}`. Writing (`:w`) pipes the buffer through `omnibuf encode` and replaces the target atomically. Encode errors keep the original file intact.

| Command | Action |
| :--- | :--- |
| `:OmnibufJson` | Show decoded editable JSON in the current buffer |
| `:OmnibufHex` | Show the read-only canonical hex dump (`filetype=xxd`) |
| `:OmnibufToggle` | Toggle the current buffer between JSON and hex views |
| `:OmnibufSplit` | Open or close a companion split with the opposite view |
| `:OmnibufRefresh` | Re-read and re-decode the `.obuf` file from disk |
| `:OmnibufSchema [path] [type]` | Set buffer-local `FileDescriptorSet` (`-s`) and optional message type (`-t`) |

## Settings

| Variable | Default | Description |
| :--- | :--- | :--- |
| `g:omnibuf_cli` | `'omnibuf'` | Path to the `omnibuf` CLI executable |
| `g:omnibuf_default_view` | `'json'` | Initial view (`'json'`, `'hex'`, or `'split'`) |
| `g:omnibuf_schema` / `g:omnibuf_type` | `''` | Default `FileDescriptorSet` path and message type |
| `g:omnibuf_field0` | `1` | Include Field #0 inline field names in schema-less mode |
| `g:omnibuf_deterministic` | `0` | Sort map keys and schema fields deterministically |
| `g:omnibuf_hex_cmd` | `''` | Custom hex dump command (auto-detects `xxd`, `hexdump -C`, or `od`) |
| `g:omnibuf_split_cmd` | `'botright vnew'` | Split command used by `:OmnibufSplit` |

## License

Apache-2.0
