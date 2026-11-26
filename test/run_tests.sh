#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OMNIBUF_CLI="${OMNIBUF_CLI:-omnibuf}"
VIM_CLI_ESCAPED="${OMNIBUF_CLI//\'/\'\'}"

# Generate a valid .obuf fixture using the omnibuf CLI
echo '{"asn": 64512, "router_id": "edge-fra-01", "active": true, "location": {"city": "Frankfurt", "rack": 42}}' \
  | "$OMNIBUF_CLI" > "$TMP_DIR/peer.obuf"

# Generate an invalid .obuf fixture
printf '\xff\xff\xff' > "$TMP_DIR/corrupt.obuf"

run_vim_test() {
  local name="$1"
  local script="$2"
  local script_file="$TMP_DIR/${name}.vim"
  printf '%s\n' "$script" > "$script_file"
  vim --clean -Nu NONE -es \
    --cmd "set rtp+=${ROOT_DIR}" \
    -c "let g:omnibuf_cli = '${VIM_CLI_ESCAPED}'" \
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
decoded_after="$("$OMNIBUF_CLI" decode -i "$TMP_DIR/editable.obuf")"
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
new_decoded="$("$OMNIBUF_CLI" decode -i "$TMP_DIR/brand_new.obuf")"
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

# 9. Editions 2026 :OmnibufSchema (-s / -t) decode, edit, and write round-trip
PROTOC_BIN="${PROTOC:-}"
if [[ -z "$PROTOC_BIN" ]]; then
  if command -v protoc >/dev/null 2>&1; then
    PROTOC_BIN="protoc"
  elif [[ -x /opt/homebrew/bin/protoc ]]; then
    PROTOC_BIN="/opt/homebrew/bin/protoc"
  fi
fi

if [[ -n "$PROTOC_BIN" ]]; then
  cat > "$TMP_DIR/editions2026.proto" << 'EOF'
edition = "2026";
package vimtest.ed26;

import "google/protobuf/descriptor.proto";

extend google.protobuf.FieldOptions {
  string vim_hint = 50041;
}

export enum OpenStatus {
  OPEN_STATUS_UNSPECIFIED = 0;
  OPEN_STATUS_READY = 1;
}

export message Child {
  int32 id = 1;
  string note = 2 [(vim_hint) = "utf8"];
}

export message Record {
  int32 explicit_int = 1;
  bool explicit_bool = 2;
  OpenStatus status = 3;
  Child delimited_child = 4 [features.message_encoding = DELIMITED];
  oneof choice {
    int32 choice_int = 5;
    bool choice_flag = 6;
  }
}
EOF
  "$PROTOC_BIN" -I"$TMP_DIR" --include_imports --descriptor_set_out="$TMP_DIR/editions2026.pb" "$TMP_DIR/editions2026.proto"

  echo '{"explicit_int": 0, "explicit_bool": false, "status": 777, "delimited_child": {"id": 7, "note": "fra"}, "choice_flag": false}' \
    | "$OMNIBUF_CLI" encode --deterministic -s "$TMP_DIR/editions2026.pb" -t vimtest.ed26.Record -o "$TMP_DIR/editions2026.obuf"

  run_vim_test "editions_2026_schema_edit_write" "
edit ${TMP_DIR}/editions2026.obuf
execute 'OmnibufSchema ${TMP_DIR}/editions2026.pb vimtest.ed26.Record'
let text = join(getline(1, '\$'), '\n')
if &filetype !=# 'json' || &modifiable != 1
  throw 'Expected writable json buffer after :OmnibufSchema'
endif
if stridx(text, '\"explicit_int\": 0') < 0
  throw 'Expected explicit_int: 0 in decoded Editions 2026 JSON, got: ' . text
endif
if stridx(text, '\"explicit_bool\": false') < 0
  throw 'Expected explicit_bool: false in decoded Editions 2026 JSON, got: ' . text
endif
if stridx(text, '\"status\": 777') < 0
  throw 'Expected unknown open enum status: 777, got: ' . text
endif
if stridx(text, '\"note\": \"fra\"') < 0
  throw 'Expected delimited_child.note fra, got: ' . text
endif
if stridx(text, '\"choice_flag\": false') < 0
  throw 'Expected active zero oneof choice_flag: false, got: ' . text
endif
%s/\"fra\"/\"zurich\"/g
write
if &modified != 0
  throw 'Expected buffer to be nomodified after writing Editions 2026 .obuf'
endif
"

  ed26_after="$("$OMNIBUF_CLI" decode -s "$TMP_DIR/editions2026.pb" -t vimtest.ed26.Record -i "$TMP_DIR/editions2026.obuf")"
  if [[ "$ed26_after" != *'"note": "zurich"'* \
     || "$ed26_after" != *'"explicit_int": 0'* \
     || "$ed26_after" != *'"explicit_bool": false'* \
     || "$ed26_after" != *'"status": 777'* \
     || "$ed26_after" != *'"choice_flag": false'* ]]; then
    echo "FAIL: Editions 2026 round-trip lost fields after Vim write: $ed26_after"
    exit 1
  fi
  echo "PASS: editions_2026_schema_edit_write_verified"
else
  echo "SKIP: protoc not found; skipping Editions 2026 schema test"
fi

echo "All omnibuf-vim tests passed!"
