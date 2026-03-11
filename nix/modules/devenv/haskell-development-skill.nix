inputs:
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.claude.code.plugins.haskell-development;
  defaultPackage = inputs.self.packages.${pkgs.system}.haskell-development-skill;

  mkSkillFiles =
    pkg:
    let
      skillDir = "${pkg}/share/claude/skills/haskell-development-skill";
      referenceFiles = builtins.attrNames (builtins.readDir "${skillDir}/references");
    in
    lib.listToAttrs (
      [
        {
          name = ".claude/skills/haskell-development-skill/SKILL.md";
          value.text = builtins.readFile "${skillDir}/SKILL.md";
        }
      ]
      ++ map (name: {
        name = ".claude/skills/haskell-development-skill/references/${name}";
        value.text = builtins.readFile "${skillDir}/references/${name}";
      }) referenceFiles
    );
in
{
  options.claude.code.plugins.haskell-development = {
    enable = lib.mkEnableOption "Haskell development skill for Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "inputs.self.packages.\${pkgs.system}.haskell-development-skill";
      description = "The haskell-development-skill package";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      pkgs.haskellPackages.fourmolu
      pkgs.haskellPackages.hlint
    ];

    git-hooks.hooks = {
      fourmolu.enable = true;
      hlint.enable = true;
    };

    files = mkSkillFiles cfg.package;
  };
}
