#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Generate a valid .obuf fixture using the omnibuf CLI
echo '{"asn": 64512, "router_id": "edge-fra-01", "active": true, "location": {"city": "Frankfurt", "rack": 42}}' \
  | omnibuf > "$TMP_DIR/peer.obuf"

# Generate an invalid .obuf fixture
printf '\xff\xff\xff' > "$TMP_DIR/corrupt.obuf"

run_vim_test() {
  local name="$1"
  local script="$2"
  local script_file="$TMP_DIR/${name}.vim"
  printf '%s\n' "$script" > "$script_file"
  vim --clean -Nu NONE -es \
    --cmd "set rtp+=${ROOT_DIR}" \
    -c "runtime plugin/omnibuf.vim" \
    -c "runtime ftdetect/omnibuf.vim" \
    -S "$script_file" \
    -c "qa!"
  echo "PASS: $name"
}

# 1. Opening .obuf shows editable decoded JSON by default
run_vim_test "default_json" "
edit ${TMP_DIR}/peer.obuf
let text = join(getline(1, '\$'), '\n')
if &filetype !=# 'json'
  throw 'Expected filetype json, got: ' . &filetype
endif
if &modifiable != 1 || &readonly != 0 || &buftype !=# 'acwrite'
  throw 'Expected JSON buffer to be modifiable with buftype=acwrite'
endif
if stridx(text, '\"router_id\": \"edge-fra-01\"') < 0
  throw 'Expected decoded JSON to contain router_id, got: ' . text
endif
if stridx(text, '\"Frankfurt\"') < 0
  throw 'Expected decoded JSON to contain Frankfurt, got: ' . text
endif
"

# 2. :OmnibufHex and :OmnibufToggle switch between JSON and hex
run_vim_test "toggle_hex_json" "
edit ${TMP_DIR}/peer.obuf
OmnibufHex
if &filetype !=# 'xxd'
  throw 'Expected filetype xxd after :OmnibufHex, got: ' . &filetype
endif
if &modifiable != 0 || &readonly != 1
  throw 'Expected hex buffer to be readonly and nomodifiable'
endif
let hex_text = join(getline(1, '\$'), '\n')
if stridx(hex_text, '00000000:') < 0 && stridx(hex_text, '00000000') < 0
  throw 'Expected hex offset in hex output, got: ' . hex_text
endif
if stridx(hex_text, 'router_id') < 0
  throw 'Expected ASCII preview in hex output, got: ' . hex_text
endif
OmnibufToggle
if &filetype !=# 'json'
  throw 'Expected filetype json after :OmnibufToggle, got: ' . &filetype
endif
"

# 3. :OmnibufSplit opens and closes companion hex split
run_vim_test "split_toggle" "
edit ${TMP_DIR}/peer.obuf
if winnr('\$') != 1
  throw 'Expected 1 window initially'
endif
OmnibufSplit
if winnr('\$') != 2
  throw 'Expected 2 windows after :OmnibufSplit, got: ' . winnr('\$')
endif
let ft1 = getwinvar(1, '&filetype')
let ft2 = getwinvar(2, '&filetype')
if !((ft1 ==# 'json' && ft2 ==# 'xxd') || (ft1 ==# 'xxd' && ft2 ==# 'json'))
  throw 'Expected one json and one xxd window, got: ' . ft1 . ' and ' . ft2
endif
OmnibufSplit
if winnr('\$') != 1
  throw 'Expected 1 window after closing split, got: ' . winnr('\$')
endif
"

# 4. Editing JSON and :w re-encodes to .obuf and refreshes companion hex split
cp "$TMP_DIR/peer.obuf" "$TMP_DIR/editable.obuf"
run_vim_test "edit_and_write_json" "
edit ${TMP_DIR}/editable.obuf
OmnibufSplit
%s/Frankfurt/Berlin/g
write
if &modified != 0
  throw 'Expected buffer to be marked nomodified after successful write'
endif
"
decoded_after="$(omnibuf decode -i "$TMP_DIR/editable.obuf")"
if [[ "$decoded_after" != *'"city": "Berlin"'* ]]; then
  echo "FAIL: expected Berlin in re-encoded .obuf, got: $decoded_after"
  exit 1
fi
echo "PASS: edit_and_write_json_verified"

# 5. Writing invalid JSON fails safely without corrupting the existing .obuf file
cp "$TMP_DIR/peer.obuf" "$TMP_DIR/protected.obuf"
before_sha="$(shasum -a 256 "$TMP_DIR/protected.obuf" | awk '{print $1}')"
run_vim_test "invalid_json_preserves_file" "
edit ${TMP_DIR}/protected.obuf
call setline(1, '{not valid json')
write
if &modified != 1
  throw 'Expected buffer to remain modified when encode fails'
endif
"
after_sha="$(shasum -a 256 "$TMP_DIR/protected.obuf" | awk '{print $1}')"
if [[ "$before_sha" != "$after_sha" ]]; then
  echo "FAIL: invalid JSON write modified the existing .obuf file"
  exit 1
fi
echo "PASS: invalid_json_preserves_file_verified"

# 6. Creating a brand new .obuf file from JSON via BufNewFile + :w
run_vim_test "new_obuf_file" "
edit ${TMP_DIR}/brand_new.obuf
silent %delete _
call setline(1, ['{', '  \"service\": \"gateway\",', '  \"port\": 8080', '}'])
write
if &modified != 0
  throw 'Expected new .obuf buffer to be clean after write'
endif
"
new_decoded="$(omnibuf decode -i "$TMP_DIR/brand_new.obuf")"
if [[ "$new_decoded" != *'"service": "gateway"'* || "$new_decoded" != *'"port": 8080'* ]]; then
  echo "FAIL: unexpected decoded content for new .obuf: $new_decoded"
  exit 1
fi
echo "PASS: new_obuf_file_verified"

# 7. Corrupt .obuf shows error comment (readonly) and still allows :OmnibufHex
run_vim_test "corrupt_file_fallback" "
edit ${TMP_DIR}/corrupt.obuf
let text = join(getline(1, '\$'), '\n')
if stridx(text, 'Failed to decode') < 0
  throw 'Expected decode failure message, got: ' . text
endif
if &modifiable != 0
  throw 'Expected failed decode buffer to be nomodifiable'
endif
OmnibufHex
let hex_text = join(getline(1, '\$'), '\n')
if stridx(hex_text, 'ffff') < 0 && stridx(hex_text, 'ff ff') < 0
  throw 'Expected raw ff bytes in hex view, got: ' . hex_text
endif
"

# 8. Missing CLI shows clear install message and still allows :OmnibufHex
run_vim_test "missing_cli_fallback" "
let g:omnibuf_cli = 'nonexistent-omnibuf-binary-xyz'
edit ${TMP_DIR}/peer.obuf
let text = join(getline(1, '\$'), '\n')
if stridx(text, 'omnibuf CLI not found') < 0
  throw 'Expected missing CLI error message, got: ' . text
endif
OmnibufHex
let hex_text = join(getline(1, '\$'), '\n')
if stridx(hex_text, 'router_id') < 0
  throw 'Expected hex fallback to work without CLI, got: ' . hex_text
endif
"

echo "All omnibuf-vim tests passed!"
