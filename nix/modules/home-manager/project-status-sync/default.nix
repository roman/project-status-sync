inputs:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.project-status-sync;
  system = pkgs.stdenv.hostPlatform.system;

  hookPkg = inputs.self.packages.${system}.ccs-session-end-hook;

  aggregateArgs = [
    "${cfg.package}/bin/ccs"
    "aggregate"
    "--signal-dir"
    cfg.signalDir
    "--quiet-minutes"
    (toString cfg.quietPeriodMinutes)
    "--output-dir"
    cfg.outputDir
    "--llm-command"
    cfg.llmCommand
  ]
  ++ lib.concatMap (a: [
    "--llm-arg"
    a
  ]) cfg.llmArgs
  ++ [
    "--max-signals"
    (toString cfg.maxSignals)
  ]
  ++ lib.concatMap (a: [
    "--org-mapping"
    a
  ]) (lib.mapAttrsToList (k: v: "${k}=${v}") cfg.orgMappings)
  ++ lib.concatMap (a: [
    "--project-override"
    a
  ]) (lib.mapAttrsToList (k: v: "${k}=${v}") cfg.projectOverrides);

  aggregateScript = pkgs.writeShellScript "project-status-sync" ''
    exec ${lib.escapeShellArgs aggregateArgs}
  '';

  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  options.programs.project-status-sync = {
    enable = lib.mkEnableOption "session capture hook + periodic ccs aggregation";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.self.packages.${system}.ccs;
      defaultText = lib.literalExpression "inputs.self.packages.\${system}.ccs";
      description = "The ccs package.";
    };

    signalDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/ccs/signals";
      description = "Signal directory shared between hook and aggregation service.";
    };

    outputDir = lib.mkOption {
      type = lib.types.str;
      description = "Output directory for EVENTS.jsonl, STATUS.md, handoffs, progress.log.";
      example = "/home/user/Notes/01 Projects";
    };

    quietPeriodMinutes = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Minutes to wait after last signal before processing.";
    };

    intervalMinutes = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Timer frequency in minutes.";
    };

    llmCommand = lib.mkOption {
      type = lib.types.str;
      default = "claude";
      description = "LLM binary name (e.g. \"claude\" or \"airchat\").";
    };

    llmArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "-p" ];
      description = "Arguments for the LLM command.";
      example = [
        "claude"
        "--"
        "-p"
      ];
    };

    orgMappings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Map git host/org prefix to human-readable name for output path derivation.";
      example = {
        "github.com/anthropics" = "Anthropic";
      };
    };

    projectOverrides = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Override output subpath for specific project keys.";
    };

    maxSignals = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Maximum signals to process per aggregation run.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.claude-code.enable;
        message = "programs.project-status-sync requires programs.claude-code.enable = true";
      }
    ];

    programs.claude-code.settings.hooks.SessionEnd = lib.mkAfter [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "CCS_SIGNAL_DIR=${cfg.signalDir} ${hookPkg}/bin/ccs-session-end-hook";
          }
        ];
      }
    ];

    systemd.user.services.project-status-sync = lib.mkIf isLinux {
      Unit.Description = "Project status sync — periodic ccs aggregation";
      Service = {
        Type = "oneshot";
        TimeoutStartSec = "30min";
        ExecStart = toString aggregateScript;
        Environment = [
          "PATH=${config.home.profileDirectory}/bin:/usr/bin:/bin"
          "HOME=${config.home.homeDirectory}"
        ];
      };
    };

    systemd.user.timers.project-status-sync = lib.mkIf isLinux {
      Timer = {
        OnBootSec = "${toString cfg.intervalMinutes}min";
        OnUnitActiveSec = "${toString cfg.intervalMinutes}min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    launchd.agents.project-status-sync = lib.mkIf isDarwin {
      enable = true;
      config = {
        Label = "com.ccs.project-status-sync";
        ProgramArguments = aggregateArgs;
        StartInterval = cfg.intervalMinutes * 60;
        EnvironmentVariables = {
          PATH = "${config.home.profileDirectory}/bin:/usr/bin:/bin";
          HOME = config.home.homeDirectory;
        };
        StandardOutPath = "/tmp/project-status-sync.log";
        StandardErrorPath = "/tmp/project-status-sync.err";
      };
    };
  };
}
