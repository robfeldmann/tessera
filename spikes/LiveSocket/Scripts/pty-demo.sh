#!/usr/bin/env bash
# End-to-end transcript: run the app in a real pty (`script`), drive it over the socket from
# this shell, and compare the `text` reply with what the pty actually received.
#
# usage: Scripts/pty-demo.sh            (from spikes/LiveSocket, after `swift build`)
#
# `script` needs a tty-or-pipe stdin (a fifo makes it fail with EOPNOTSUPP), so a `tail -f`
# on a scratch file is the pipe that keeps its stdin open; appending bytes to that file types
# real keystrokes into the pty.
set -u

SOCK=/tmp/livesocket-demo.sock
TYPESCRIPT=/tmp/livesocket-demo.typescript
KEYS=/tmp/livesocket-demo.keys
BIN="$(swift build --show-bin-path)/livesocket"
SCRIPT_PID=

cleanup() {
  pkill -f "tail -f $KEYS" 2>/dev/null
  [ -n "$SCRIPT_PID" ] && kill "$SCRIPT_PID" 2>/dev/null
  rm -f "$SOCK" "$KEYS" "$TYPESCRIPT" /tmp/livesocket-demo.before-quit
}
trap cleanup EXIT

step() { printf '\n$ %s\n' "$*"; }
ctl() { "$BIN" ctl --socket "$SOCK" "$1"; }
screen() { jq -r '.text | split("\n") | (.[3:8][], .[9])'; }

launch() {
  rm -f "$SOCK" "$TYPESCRIPT" "$KEYS"
  : >"$KEYS"
  tail -f "$KEYS" 2>/dev/null |
    script -q /dev/null sh -c "stty cols 80 rows 24; exec '$BIN' run --socket '$SOCK'" \
      >"$TYPESCRIPT" 2>/dev/null &
  SCRIPT_PID=$!
  for _ in $(seq 1 100); do
    [ -S "$SOCK" ] && return 0
    sleep 0.1
  done
  echo "socket never appeared" >&2
  return 1
}

alive() { kill -0 "$SCRIPT_PID" 2>/dev/null && echo "script still running" || echo "script exited"; }

launch || exit 1

step "ls -l $SOCK"
ls -l "$SOCK"

step "printf '{\"op\":\"text\"}\\n' | nc -U $SOCK | jq -r .text"
printf '{"op":"text"}\n' | nc -U "$SOCK" | jq -r .text

step "printf '{\"op\":\"key\",\"key\":\"Tab\"}\\n' | nc -U $SOCK"
printf '{"op":"key","key":"Tab"}\n' | nc -U "$SOCK"

step "printf '{\"op\":\"text\"}' | nc -U $SOCK | jq -r .text     # no trailing newline"
printf '{"op":"text"}' | nc -U "$SOCK" | jq -r .text

step "printf '\\t' >> keys   # a REAL Tab typed into the pty"
printf '\t' >>"$KEYS"
sleep 0.4
ctl '{"op":"text"}' | screen

step "livesocket ctl ... Shift+Tab, then ArrowRight twice"
ctl '{"op":"key","key":"Shift+Tab"}'
ctl '{"op":"key","key":"ArrowRight"}' >/dev/null
ctl '{"op":"key","key":"ArrowRight"}'
ctl '{"op":"text"}' | screen

step "livesocket ctl ... '{\"op\":\"key\",\"key\":\"Hyper\"}'   # unknown key"
ctl '{"op":"key","key":"Hyper"}'
echo "exit=$?"

step "livesocket ctl ... '{\"op\":\"tree\"}' | jq -c '.nodes[] | {id,frame}' (rows of the list)"
ctl '{"op":"tree"}' | jq -c '.nodes[] | select(.type|endswith("Text")) | {id,frame}' | tail -6

step "latency: 100 sequential 'text' round trips through the ctl client (one process each)"
time (for _ in $(seq 1 100); do ctl '{"op":"text"}' >/dev/null; done)

step "a client that disconnects before reading its reply must not hurt the app (SIGPIPE)"
python3 - "$SOCK" <<'PY'
import socket, sys
for _ in range(20):
    s = socket.socket(socket.AF_UNIX)
    s.connect(sys.argv[1])
    s.sendall(b'{"op":"tree"}\n')
    s.close()
PY
ctl '{"op":"text"}' | jq -c '{ok, frame}'

step "parity: bytes the pty received, replayed through a fresh Ghostty VT, vs the text reply"
sleep 0.4
cp "$TYPESCRIPT" /tmp/livesocket-demo.before-quit
ctl '{"op":"text"}' | jq -r '.rows[]' >/tmp/livesocket-demo.reply.txt
"$BIN" vt-replay --size 80x24 /tmp/livesocket-demo.before-quit >/tmp/livesocket-demo.replay.txt
if diff /tmp/livesocket-demo.reply.txt /tmp/livesocket-demo.replay.txt; then
  echo "IDENTICAL: socket text == pty-rendered text ($(wc -l </tmp/livesocket-demo.reply.txt | tr -d ' ') rows)"
else
  echo "DIFFERENT (see diff above)"
fi
rm -f /tmp/livesocket-demo.reply.txt /tmp/livesocket-demo.replay.txt

step "livesocket ctl ... '{\"op\":\"quit\"}'; ls -l $SOCK"
ctl '{"op":"quit"}'
echo "exit=$?"
ls -l "$SOCK" 2>&1
sleep 0.5
alive

step "livesocket ctl ... '{\"op\":\"text\"}'   # socket is gone"
ctl '{"op":"text"}'
echo "exit=$?"

step "second run: quit with a REAL q keystroke"
pkill -f "tail -f $KEYS" 2>/dev/null
launch || exit 1
printf 'q' >>"$KEYS"
sleep 0.8
ls -l "$SOCK" 2>&1
alive

step "kill -9 leaves a stale socket; ctl says so (exit 3) and the next launch replaces it"
pkill -f "tail -f $KEYS" 2>/dev/null
launch || exit 1
pkill -9 -f "livesocket run --socket $SOCK"
sleep 0.5
ls -l "$SOCK" 2>&1
ctl '{"op":"text"}'
echo "exit=$?"
kill "$SCRIPT_PID" 2>/dev/null
pkill -f "tail -f $KEYS" 2>/dev/null
launch || exit 1
ctl '{"op":"text"}' | jq -c '{ok, frame}'
ctl '{"op":"quit"}'
