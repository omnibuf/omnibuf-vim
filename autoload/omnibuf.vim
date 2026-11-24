" autoload/omnibuf.vim - Core decoding, encoding, and hex-view logic for .obuf files

function! s:get_cli() abort
  return get(g:, 'omnibuf_cli', 'omnibuf')
endfunction

function! s:get_schema() abort
  return get(b:, 'omnibuf_schema', get(g:, 'omnibuf_schema', ''))
endfunction

function! s:get_type() abort
  return get(b:, 'omnibuf_type', get(g:, 'omnibuf_type', ''))
endfunction

function! s:resolve_file() abort
  if exists('b:omnibuf_file') && !empty(b:omnibuf_file)
    return b:omnibuf_file
  endif
  let l:path = expand('%:p')
  if !empty(l:path)
    return l:path
  endif
  return ''
endfunction

function! s:build_decode_cmd(filepath) abort
  let l:cli = s:get_cli()
  if !executable(l:cli)
    return {'ok': 0, 'error': 'omnibuf CLI not found: ' . l:cli . ' (install via: brew install omnibuf/tap/omnibuf)'}
  endif

  let l:parts = [shellescape(l:cli), 'decode']
  let l:schema = s:get_schema()
  let l:type = s:get_type()
  if !empty(l:schema)
    call add(l:parts, '-s')
    call add(l:parts, shellescape(l:schema))
  endif
  if !empty(l:type)
    call add(l:parts, '-t')
    call add(l:parts, shellescape(l:type))
  endif
  call add(l:parts, '-i')
  call add(l:parts, shellescape(a:filepath))

  return {'ok': 1, 'cmd': join(l:parts, ' ')}
endfunction

function! s:build_encode_cmd(outpath) abort
  let l:cli = s:get_cli()
  if !executable(l:cli)
    return {'ok': 0, 'error': 'omnibuf CLI not found: ' . l:cli . ' (install via: brew install omnibuf/tap/omnibuf)'}
  endif

  let l:parts = [shellescape(l:cli), 'encode']
  let l:schema = s:get_schema()
  let l:type = s:get_type()
  if !empty(l:schema)
    call add(l:parts, '-s')
    call add(l:parts, shellescape(l:schema))
  else
    if !get(g:, 'omnibuf_field0', 1)
      call add(l:parts, '--no-field0')
    endif
  endif
  if !empty(l:type)
    call add(l:parts, '-t')
    call add(l:parts, shellescape(l:type))
  endif
  if get(g:, 'omnibuf_deterministic', 0)
    call add(l:parts, '--deterministic')
  endif
  call add(l:parts, '-o')
  call add(l:parts, shellescape(a:outpath))

  return {'ok': 1, 'cmd': join(l:parts, ' ')}
endfunction

function! s:build_hex_cmd(filepath) abort
  let l:custom = get(g:, 'omnibuf_hex_cmd', '')
  if !empty(l:custom)
    return {'ok': 1, 'cmd': l:custom . ' ' . shellescape(a:filepath), 'capped': 0, 'limit': 0, 'size': 0}
  endif
  let l:limit = str2nr(string(get(g:, 'omnibuf_max_hex_bytes', 262144)))
  let l:size = getfsize(a:filepath)
  let l:capped = l:limit > 0 && l:size > l:limit
  if executable('xxd')
    let l:flag = l:limit > 0 ? ' -l ' . l:limit : ''
    return {'ok': 1, 'cmd': 'xxd' . l:flag . ' ' . shellescape(a:filepath), 'capped': l:capped, 'limit': l:limit, 'size': l:size}
  endif
  if executable('hexdump')
    let l:flag = l:limit > 0 ? ' -n ' . l:limit : ''
    return {'ok': 1, 'cmd': 'hexdump -C' . l:flag . ' ' . shellescape(a:filepath), 'capped': l:capped, 'limit': l:limit, 'size': l:size}
  endif
  if executable('od')
    let l:flag = l:limit > 0 ? ' -N ' . l:limit : ''
    return {'ok': 1, 'cmd': 'od -Ax -tx1z -v' . l:flag . ' ' . shellescape(a:filepath), 'capped': l:capped, 'limit': l:limit, 'size': l:size}
  endif
  return {'ok': 0, 'error': 'No hex viewer found (install xxd, hexdump, or od, or set g:omnibuf_hex_cmd)'}
endfunction

function! s:run_decode(filepath) abort
  let l:spec = s:build_decode_cmd(a:filepath)
  if !l:spec.ok
    return {'ok': 0, 'lines': ['// ' . l:spec.error, '// Run :OmnibufHex to inspect raw binary bytes.']}
  endif

  let l:lines = systemlist(l:spec.cmd)
  if v:shell_error != 0
    let l:err_lines = ['// Failed to decode ' . fnamemodify(a:filepath, ':t') . ' (exit ' . v:shell_error . ')']
    for l:line in l:lines
      call add(l:err_lines, '// ' . l:line)
    endfor
    call add(l:err_lines, '// Run :OmnibufHex to inspect raw binary bytes.')
    return {'ok': 0, 'lines': l:err_lines}
  endif

  if empty(l:lines)
    return {'ok': 1, 'lines': ['{}']}
  endif
  return {'ok': 1, 'lines': l:lines}
endfunction

function! s:run_hex(filepath) abort
  let l:spec = s:build_hex_cmd(a:filepath)
  if !l:spec.ok
    return {'ok': 0, 'lines': [l:spec.error]}
  endif

  let l:lines = systemlist(l:spec.cmd)
  if v:shell_error != 0
    let l:err_lines = ['Failed to dump hex for ' . fnamemodify(a:filepath, ':t') . ' (exit ' . v:shell_error . ')']
    call extend(l:err_lines, l:lines)
    return {'ok': 0, 'lines': l:err_lines}
  endif

  if empty(l:lines)
    return {'ok': 1, 'lines': ['(empty file: 0 bytes)']}
  endif
  if get(l:spec, 'capped', 0)
    call add(l:lines, '... truncated at ' . l:spec.limit . ' of ' . l:spec.size . ' bytes (set g:omnibuf_max_hex_bytes to adjust)')
  endif
  return {'ok': 1, 'lines': l:lines}
endfunction

function! s:replace_buffer(lines, ft, mode, writable) abort
  let l:view = winsaveview()
  setlocal modifiable noreadonly
  silent %delete _
  call setline(1, a:lines)
  setlocal nomodified noswapfile
  if a:writable
    setlocal modifiable noreadonly buftype=acwrite
  else
    setlocal nomodifiable readonly buftype=nowrite
  endif
  let b:omnibuf_mode = a:mode
  let b:omnibuf_writable = a:writable ? 1 : 0
  execute 'setlocal filetype=' . a:ft
  call winrestview(l:view)
endfunction

function! s:render_mode(filepath, mode, force_readonly) abort
  if !filereadable(a:filepath)
    call s:replace_buffer(['// File not readable: ' . a:filepath], 'json', a:mode, 0)
    return
  endif

  let b:omnibuf_file = a:filepath
  if a:mode ==# 'hex'
    let l:res = s:run_hex(a:filepath)
    call s:replace_buffer(l:res.lines, 'xxd', 'hex', 0)
  else
    let l:res = s:run_decode(a:filepath)
    let l:writable = !a:force_readonly && l:res.ok
    call s:replace_buffer(l:res.lines, 'json', 'json', l:writable)
  endif
endfunction

function! s:refresh_companion_splits(filepath) abort
  let l:cur_winid = win_getid()
  let l:winids = []
  for l:w in range(1, winnr('$'))
    call add(l:winids, win_getid(l:w))
  endfor
  try
    for l:wid in l:winids
      if l:wid == l:cur_winid
        continue
      endif
      let l:bn = winbufnr(l:wid)
      if getbufvar(l:bn, 'omnibuf_file', '') ==# a:filepath
            \ && getbufvar(l:bn, 'omnibuf_mode', '') ==# 'hex'
        if win_gotoid(l:wid)
          call s:render_mode(a:filepath, 'hex', 1)
        endif
      endif
    endfor
  finally
    call win_gotoid(l:cur_winid)
  endtry
endfunction

function! omnibuf#read(filepath) abort
  if !filereadable(a:filepath)
    call omnibuf#new_file(a:filepath)
    return
  endif
  let l:default_view = get(g:, 'omnibuf_default_view', 'json')
  if l:default_view ==# 'hex'
    call s:render_mode(a:filepath, 'hex', 0)
  else
    call s:render_mode(a:filepath, 'json', 0)
    if l:default_view ==# 'split'
      call omnibuf#toggle_split()
    endif
  endif
endfunction

function! omnibuf#new_file(filepath) abort
  let b:omnibuf_file = a:filepath
  call s:replace_buffer(['{', '  ', '}'], 'json', 'json', 1)
endfunction

function! omnibuf#read_append(filepath) abort
  let l:res = s:run_decode(a:filepath)
  call append(line('.'), l:res.lines)
endfunction

function! omnibuf#write(filepath) abort
  call omnibuf#write_range(a:filepath, 1, line('$'))
endfunction

function! omnibuf#write_range(filepath, line1, line2) abort
  if get(b:, 'omnibuf_mode', 'json') !=# 'json' || !get(b:, 'omnibuf_writable', 0)
    echohl ErrorMsg
    echom 'omnibuf: cannot write from ' . get(b:, 'omnibuf_mode', 'readonly') . ' view (switch to JSON view to edit and save)'
    echohl None
    return
  endif

  let l:current = s:resolve_file()
  let l:target = empty(a:filepath) ? l:current : a:filepath
  if empty(l:target)
    echohl ErrorMsg | echom 'omnibuf: no output file path specified' | echohl None
    return
  endif

  let l:dir = fnamemodify(l:target, ':h')
  if !isdirectory(l:dir)
    call mkdir(l:dir, 'p')
  endif

  let l:stamp = substitute(reltimestr(reltime()), '[^0-9]', '', 'g')
  let l:tmpfile = l:dir . '/.' . fnamemodify(l:target, ':t') . '.omnibuf.' . getpid() . '.' . l:stamp
  let l:spec = s:build_encode_cmd(l:tmpfile)
  if !l:spec.ok
    echohl ErrorMsg | echom 'omnibuf: ' . l:spec.error | echohl None
    return
  endif

  try
    let l:json_text = join(getline(a:line1, a:line2), "\n") . "\n"
    let l:output = system(l:spec.cmd, l:json_text)
    if v:shell_error != 0
      let l:msg = substitute(l:output, '\n\+$', '', '')
      echohl ErrorMsg
      echom 'omnibuf: encode failed: ' . l:msg
      echohl None
      return
    endif

    if rename(l:tmpfile, l:target) != 0
      call writefile(readfile(l:tmpfile, 'b'), l:target, 'b')
    endif
  finally
    if filereadable(l:tmpfile)
      call delete(l:tmpfile)
    endif
  endtry

  let l:is_full_buffer = (a:line1 == 1 && a:line2 == line('$'))
  let l:is_same_file = empty(l:current) || fnamemodify(l:target, ':p') ==# fnamemodify(l:current, ':p')
  if l:is_full_buffer && l:is_same_file
    let b:omnibuf_file = l:target
    setlocal nomodified
  endif
  let l:size = getfsize(l:target)
  echom '"' . fnamemodify(l:target, ':t') . '" [omnibuf] ' . l:size . 'B written'
  call s:refresh_companion_splits(l:target)
endfunction

function! omnibuf#show_json() abort
  let l:filepath = s:resolve_file()
  if empty(l:filepath)
    echohl WarningMsg | echom 'omnibuf: current buffer is not associated with an .obuf file' | echohl None
    return
  endif
  call s:render_mode(l:filepath, 'json', 0)
endfunction

function! omnibuf#show_hex() abort
  let l:filepath = s:resolve_file()
  if empty(l:filepath)
    echohl WarningMsg | echom 'omnibuf: current buffer is not associated with an .obuf file' | echohl None
    return
  endif
  if &modified && get(b:, 'omnibuf_mode', '') ==# 'json'
    echohl WarningMsg
    echom 'omnibuf: save (:w) or discard (:OmnibufRefresh!) JSON edits before switching to hex view, or use :OmnibufSplit'
    echohl None
    return
  endif
  call s:render_mode(l:filepath, 'hex', 0)
endfunction

function! omnibuf#toggle() abort
  let l:mode = get(b:, 'omnibuf_mode', 'json')
  if l:mode ==# 'hex'
    call omnibuf#show_json()
  else
    call omnibuf#show_hex()
  endif
endfunction

function! omnibuf#refresh(...) abort
  let l:force = a:0 > 0 ? a:1 : 0
  let l:filepath = s:resolve_file()
  if empty(l:filepath)
    echohl WarningMsg | echom 'omnibuf: current buffer is not associated with an .obuf file' | echohl None
    return
  endif
  if !l:force && &modified && get(b:, 'omnibuf_mode', '') ==# 'json'
    echohl WarningMsg
    echom 'omnibuf: unsaved JSON edits in buffer; save (:w) or run :OmnibufRefresh! to discard'
    echohl None
    return
  endif
  let l:mode = get(b:, 'omnibuf_mode', 'json')
  call s:render_mode(l:filepath, l:mode, 0)
endfunction

function! omnibuf#toggle_split() abort
  let l:filepath = s:resolve_file()
  if empty(l:filepath)
    echohl WarningMsg | echom 'omnibuf: current buffer is not associated with an .obuf file' | echohl None
    return
  endif

  let l:cur_mode = get(b:, 'omnibuf_mode', 'json')
  let l:other_mode = l:cur_mode ==# 'hex' ? 'json' : 'hex'

  " If a companion window for this file and opposite mode is already open in this tab, close it
  let l:cur_winid = win_getid()
  for l:w in range(1, winnr('$'))
    let l:wid = win_getid(l:w)
    if l:wid == l:cur_winid
      continue
    endif
    let l:bn = winbufnr(l:wid)
    if getbufvar(l:bn, 'omnibuf_file', '') ==# l:filepath
          \ && getbufvar(l:bn, 'omnibuf_mode', '') ==# l:other_mode
      if win_gotoid(l:wid)
        close
      endif
      call win_gotoid(l:cur_winid)
      return
    endif
  endfor

  let l:schema = s:get_schema()
  let l:type = s:get_type()
  let l:split_cmd = get(g:, 'omnibuf_split_cmd', 'botright vnew')
  execute l:split_cmd
  setlocal bufhidden=wipe buftype=nofile noswapfile
  let b:omnibuf_file = l:filepath
  let b:omnibuf_schema = l:schema
  let b:omnibuf_type = l:type
  let l:label = fnamemodify(l:filepath, ':t') . ' [' . l:other_mode . ']'
  silent! execute 'file ' . fnameescape(l:label)
  call s:render_mode(l:filepath, l:other_mode, 1)
  call win_gotoid(l:cur_winid)
endfunction

function! omnibuf#set_schema(...) abort
  let l:args = copy(a:000)
  let l:force = 0
  if !empty(l:args) && type(l:args[0]) == type(0)
    let l:force = remove(l:args, 0)
  endif
  if !l:force && &modified && get(b:, 'omnibuf_mode', '') ==# 'json'
    echohl WarningMsg
    echom 'omnibuf: unsaved JSON edits in buffer; save (:w) or run :OmnibufSchema! to discard'
    echohl None
    return
  endif
  if empty(l:args)
    let b:omnibuf_schema = ''
    let b:omnibuf_type = ''
  elseif len(l:args) == 1
    let b:omnibuf_schema = expand(l:args[0])
    let b:omnibuf_type = ''
  else
    let b:omnibuf_schema = expand(l:args[0])
    let b:omnibuf_type = l:args[1]
  endif
  call omnibuf#refresh(1)
endfunction
