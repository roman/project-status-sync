_flakeInputs:
{
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "haskell-development-skill";
  version = "0.1.0";

  src = ./.;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/claude/skills/haskell-development-skill
    cp SKILL.md $out/share/claude/skills/haskell-development-skill/
    cp -r references $out/share/claude/skills/haskell-development-skill/

    runHook postInstall
  '';

  meta = {
    description = "Haskell RIO-style development conventions for Claude Code";
    platforms = lib.platforms.all;
  };
}
