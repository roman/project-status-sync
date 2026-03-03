_flakeInputs:
{ pkgs, ... }:

let
  writeSessionIdScript = pkgs.writeShellScript "ccs-write-session-id" ''
    ${pkgs.jq}/bin/jq -r '.session_id // empty' > .current-session-id
  '';
in
{
  files.".claude/settings.json".json = {
    hooks = {
      UserPromptSubmit = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = builtins.toString writeSessionIdScript;
            }
          ];
        }
      ];
    };
  };
}
