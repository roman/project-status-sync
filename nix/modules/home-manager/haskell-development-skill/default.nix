inputs:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  claudeCfg = config.programs.claude-code;
  cfg = config.programs.claude-code.plugins.haskell-development-skill;
in
{
  options.programs.claude-code.plugins.haskell-development-skill = {
    enable = lib.mkEnableOption "haskell-development-skill plugin for Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.haskell-development-skill;
      defaultText = lib.literalExpression "pkgs.haskell-development-skill";
      description = "The haskell-development-skill package to use.";
    };
  };

  config = lib.mkIf (claudeCfg.enable && cfg.enable) {
    home.file.".claude/skills/haskell-development-skill" = {
      source = "${cfg.package}/share/claude/skills/haskell-development-skill";
      recursive = true;
    };

    assertions = [
      {
        assertion = cfg.enable -> (cfg.package != null);
        message = "haskell-development-skill package must be provided when enabled";
      }
    ];
  };
}
