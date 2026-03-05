_flakeInputs:
{
  writeShellApplication,
  jq,
}:

writeShellApplication {
  name = "ccs-session-end-hook";

  runtimeInputs = [ jq ];

  text = ''
    SIGNAL_DIR="''${CCS_SIGNAL_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/ccs/signals}"
    mkdir -p "$SIGNAL_DIR"

    INPUT=$(cat)

    SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id')
    TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path')
    CWD=$(printf '%s' "$INPUT" | jq -r '.cwd')

    if [ "$SESSION_ID" = "null" ] || [ "$TRANSCRIPT_PATH" = "null" ] || [ "$CWD" = "null" ]; then
      exit 0
    fi

    printf '%s' "$INPUT" | jq -c '{transcript_path, cwd}' \
      > "$SIGNAL_DIR/''${SESSION_ID}.available"
  '';
}
