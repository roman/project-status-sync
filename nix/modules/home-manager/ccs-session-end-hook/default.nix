inputs:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  claudeCfg = config.programs.claude-code;
  cfg = config.programs.claude-code.plugins.conversation-sync;
  system = pkgs.stdenv.hostPlatform.system;

  hookCommand =
    if cfg.signalDir != null then
      "CCS_SIGNAL_DIR=${cfg.signalDir} ${cfg.package}/bin/ccs-session-end-hook"
    else
      "${cfg.package}/bin/ccs-session-end-hook";
in
{
  options.programs.claude-code.plugins.conversation-sync = {
    enable = lib.mkEnableOption "CCS session-end hook for Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.self.packages.${system}.ccs-session-end-hook;
      defaultText = lib.literalExpression "pkgs.ccs-session-end-hook";
      description = "The ccs-session-end-hook package to use.";
    };

    signalDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override CCS_SIGNAL_DIR (defaults to XDG state dir).";
    };
  };

  config = lib.mkIf (claudeCfg.enable && cfg.enable) {
    warnings = [
      ''
        programs.claude-code.plugins.conversation-sync is deprecated.
        Use programs.project-status-sync instead, which provides both the
        SessionEnd hook and a periodic aggregation timer.
      ''
    ];

    programs.claude-code.settings.hooks.SessionEnd = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = hookCommand;
          }
        ];
      }
    ];
  };
}
