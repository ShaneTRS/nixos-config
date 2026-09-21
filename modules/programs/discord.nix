{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  inherit (lib.tundra) mergeFormat;
  cfg = config.shanetrs.programs.discord;
in {
  options.shanetrs.programs.discord = {
    enable = mkEnableOption "Discord configuration and integration";
    branch = mkOption {
      type = types.enum ["stable" "canary" "ptb"];
      default = "canary";
    };
    mods = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      openasar = mkOption {
        type = types.bool;
        default = true;
      };
      plugins = mkOption {
        type = types.attrs;
        default = {
          AlwaysTrust.enabled = true;
          CallTimer = {
            allCallTimers = true;
            enabled = true;
            format = "human";
            showRoleColor = true;
            showSeconds = true;
            showWithoutHover = true;
          };
          ClearURLs.enabled = true;
          CustomUserColors.enabled = true;
          DisableCallIdle.enabled = true;
          Experiments.enabled = true;
          ExpressionCloner.enabled = true;
          FakeNitro = {
            enabled = true;
            transformCompoundSentence = false;
            transformEmojis = false;
            transformStickers = false;
          };
          FixSpotifyEmbeds = {
            enabled = true;
            volume = 50;
          };
          ForceOwnerCrown.enabled = true;
          GuildPickerDumper.enabled = true;
          HomeTyping.enabled = true;
          IrcColors = {
            enabled = true;
            lightness = 70;
            memberListColors = false;
          };
          MessageLinkEmbeds.enabled = true;
          MessageLogger.enabled = true;
          MessageLoggerEnhanced = {
            enabled = true;
            saveImages = true;
            cacheMessagesFromServers = true;
            messageLimit = 3000;
          };
          NoF1.enabled = true;
          PermissionsViewer.enabled = true;
          PlatformIndicators = {
            enabled = true;
            list = false;
            messages = false;
          };
          ShowHiddenChannels.enabled = true;
          SpotifyCrack.enabled = true;
          SpotifyShareCommands.enabled = true;
          ThemeAttributes.enabled = true;
          Translate.enabled = true;
          TypingIndicator = {
            enabled = true;
            indicatorMode = 3;
          };
          ViewRaw.enabled = true;
          VolumeBooster = {
            enabled = true;
            multiplier = 3;
          };
          WhoReacted.enabled = true;
          WhosWatching.enabled = true;
        };
      };
      provider = mkOption {
        type = types.enum ["Equicord" "Moonlight" "Vencord"];
        default = "Equicord";
      };
      quickCss = mkOption {
        type = types.lines;
        default = ''
          .theme-dark .messagelogger-edited { visibility: hidden; position: absolute; }
          svg.vc-trans-icon { width: 0; }
          .botTag_c19a55 { display: none; }
        '';
      };
    };
    package = mkOption {
      type = types.package;
      default = let
        branches = with pkgs; {
          stable = discord;
          canary = discord-canary;
          ptb = discord-ptb;
        };
        m = cfg.mods;
      in
        branches.${cfg.branch}.override {
          withOpenASAR = m.enable && m.openasar;
          withEquicord = m.enable && m.provider == "Equicord";
          withMoonlight = m.enable && m.provider == "Moonlight";
          withVencord = m.enable && m.provider == "Vencord";
        };
    };
  };

  config = mkIf cfg.enable {
    tundra = {
      xdg.config = {
        "${cfg.mods.provider}/settings/settings.json" = {
          type = "execute";
          source = mergeFormat.json.default {
            inherit (cfg.mods) plugins;
          };
        };
        "${cfg.mods.provider}/settings/quickCss.css" = {
          type = "execute";
          source = mergeFormat.text.concatLines cfg.mods.quickCss;
        };
      };
      packages = [cfg.package];
    };
  };
}
