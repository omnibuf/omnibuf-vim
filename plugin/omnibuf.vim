" omnibuf.vim - View and edit OmniBuf (.obuf) binary files as JSON and hex in Vim/Neovim
" Maintainer: Kevin McDonald
" License: Apache-2.0

if exists('g:loaded_omnibuf')
  finish
endif
let g:loaded_omnibuf = 1

let g:omnibuf_cli = get(g:, 'omnibuf_cli', 'omnibuf')
let g:omnibuf_default_view = get(g:, 'omnibuf_default_view', 'json')
let g:omnibuf_schema = get(g:, 'omnibuf_schema', '')
let g:omnibuf_type = get(g:, 'omnibuf_type', '')
let g:omnibuf_field0 = get(g:, 'omnibuf_field0', 1)
let g:omnibuf_deterministic = get(g:, 'omnibuf_deterministic', 0)
let g:omnibuf_hex_cmd = get(g:, 'omnibuf_hex_cmd', '')
let g:omnibuf_split_cmd = get(g:, 'omnibuf_split_cmd', 'botright vnew')

command! OmnibufJson call omnibuf#show_json()
command! OmnibufHex call omnibuf#show_hex()
command! OmnibufToggle call omnibuf#toggle()
command! OmnibufSplit call omnibuf#toggle_split()
command! OmnibufRefresh call omnibuf#refresh()
command! -nargs=* -complete=file OmnibufSchema call omnibuf#set_schema(<f-args>)
