{
  self,
  config,
  lib,
  nixosConfig,
  pkgs,
  ...
}: let
  inherit (builtins) attrValues concatMap elem filter groupBy isFunction length listToAttrs mapAttrs match replaceStrings sort split substring toJSON warn;
  inherit (lib) concatLines escapeShellArgs flatten getExe mapAttrsToList mkIf mkOption mkOptionType mkOverride optionalString types unique;
  inherit (lib.tundra) decryptSecret decryptTemplate deepDirOf;
  inherit (pkgs) buildEnv runCommandLocal writeText;

  mapConcatLines = fn: list: concatLines (map fn list);

  fsToChown = x: "${x.user}:${
    if x.group == null
    then "$(id -gn ${x.user})"
    else x.group
  }";
  fsToJSON = x:
    toJSON {
      inherit (x) enable group mode order source target text type user;
      meta = {inherit (x.meta) name secret;};
    };

  fsToActivate = x: let
    e = mapAttrs (_: v: escapeShellArgs [v]) x;
    defer = optionalString (x.order < 0) "tundraDefer ";
    depth = toString (length (split "/" x.target));
  in
    if x.type == "execute"
    then ''
      ${e.source} ${e.target} ${writeText "${x.meta.name}-json" (fsToJSON x)}
      ${defer}chown -RPh ${fsToChown x} ${e.target}
      ${optionalString (x.mode != "symlink") "chmod -RPh ${toString x.mode} ${e.target}"}
      tundraDeactivate '${depth}) [ -e ${e.target} ] && rm -r ${e.target}'
    ''
    else if x.type == "directory" && x.source == ""
    then ''
      [ -d ${e.target} ] || mkdir ${e.target}
      ${defer}chown ${fsToChown x} ${e.target}
      ${optionalString (x.mode != "symlink") "chmod ${toString x.mode} ${e.target}"}
      tundraDeactivate '${depth}) [ -d ${e.target} ] && rmdir ${e.target}'
    ''
    else if x.mode != "symlink"
    then ''
      cp -frT ${e.source} ${e.target}.tmp
      ${defer}chown -RPh ${fsToChown x} ${e.target}.tmp
      chmod -RPh ${toString x.mode} ${e.target}.tmp
      [ ! -e ${e.target} ] || mv -fT ${e.target} ${e.target}.old
      mv -T ${e.target}.tmp ${e.target}
      [ ! -e ${e.target}.old ] || rm -fr ${e.target}.old
      tundraDeactivate '${depth}) [ -e ${e.target} ] && rm -fr ${e.target}'
    ''
    else if x.type == "recursive"
    then ''
      [ -d ${e.source} ] && while IFS= read -r -d ''' file; do
        parents=() p="$(dirname ${e.target}"$file")"
        while [ "$p" != "/" ]; do parents+=("$p") p="$(dirname "$p")"; done
        for ((i=''${#parents[@]}-1; i>=0; i--)); do
          parent="''${parents[$i]}"
          if mkdir "$parent" 2>/dev/null; then
            ${defer}tundraInheritStats "$parent"
            IFS=/ read -ra idepth <<< "$parent"
            tundraDeactivate '%s) [ -d %q ] && rmdir %q' "''${#idepth[@]}" "$parent" "$parent"
          fi
        done
        ln -sfn ${e.source}"$file" ${e.target}"$file".tmp
        mv -fT ${e.target}"$file".tmp ${e.target}"$file"
        IFS=/ read -ra fdepth <<< "$file"
        tundraDeactivate '%s) [ -L ${e.target}%q ] && rm ${e.target}%q' "$(( ${depth} + ''${#fdepth[@]} ))" "$file" "$file"
      done < <(${findutils "find"} ${e.source} -mindepth 1 -type f -printf '/%P\0')
    ''
    else if x.type == "regular"
    then ''
      ln -sfn ${e.source} ${e.target}.tmp
      mv -fT ${e.target}.tmp ${e.target}
      tundraDeactivate '${depth}) [ -L ${e.target} ] && rm ${e.target}'
    ''
    else warn "toFsActivate for '${x.type}-${toString x.mode}' is not implemented!" "# wip: ${x.type}-${toString x.mode} ${e.target}";
  findutils = bin: "${pkgs.findutils}/bin/${bin}";

  fsSubsets = rec {
    enabled = sort (a: b: a.order < b.order) (filter (x: x.enable) (attrValues cfg.filesystem));
    fsGroups = groupBy (x: "_${toString (x.order < 0)}-${toString x.meta.secret}") enabled;

    earlySecrets = fsGroups._1-1 or [];
    earlyOther = fsGroups._1- or [];
    secrets = fsGroups._-1 or [];
    other = fsGroups._- or [];
  };

  cfg = config.tundra;
in {
  options.tundra = let
    typeOption = type: attrs: mkOption ({inherit type;} // attrs);
    strOption = typeOption types.str;
    linesOption = typeOption types.lines;

    fsType = default:
      types.submodule ({
        name,
        config,
        ...
      }: let
        applyArgs = x:
          if isFunction x
          then x (config // config.meta)
          else x;
      in {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
          meta = {
            name = mkOption {
              type = types.str;
              default = name;
            };
            secret = mkOption {
              type = types.bool;
              default = default.meta.secret or false;
            };
            activate = mkOption {
              type = types.anything;
              apply = applyArgs;
              default = default.meta.activate or fsToActivate;
            };
          };
          order = mkOption {
            type = types.int;
            default = default.order or 0;
          };
          type = mkOption {
            type = types.enum ["regular" "recursive" "execute" "directory"];
            default = default.type or "regular";
          };

          mode = mkOption {
            type = mkOptionType {
              name = "file mode";
              check = x: match "symlink|[0-7]{1,4}" (toString x) != null;
            };
            default = default.mode or "symlink";
          };
          user = mkOption {
            type = mkOptionType {
              name = "user";
              check = x: nixosConfig.users.users ? ${x};
            };
            default = default.user or "root";
          };
          group = mkOption {
            type = types.nullOr (mkOptionType {
              name = "group";
              check = x: nixosConfig.users.groups ? ${x};
            });
            default = default.group or null;
          };

          textSource = mkOption {
            type = types.anything;
            default = default.textSource or (x: writeText "${replaceStrings ["/"] ["-"] x.name}-text" x.text);
          };
          source = mkOption {
            type = types.anything;
            apply = x: toString (applyArgs x);
          };
          target = mkOption {
            type = types.anything;
            apply = x: toString (/. + (applyArgs x));
            default = default.target or (x: x.name);
          };
          text = mkOption {
            type = types.nullOr types.lines;
            default = default.text or null;
          };
        };
        config = {
          source =
            if config.type == "directory"
            then mkOverride 120 default.source or null
            else if config.text != null
            then mkOverride 80 config.textSource
            else mkIf (default ? source) (mkOverride 120 default.source);
        };
      });

    fsOption = default:
      mkOption {
        type = types.attrsOf (fsType default);
        default = {};
      };
  in {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    activation = {
      tundraEarly = linesOption {default = "";};
      tundraEarlySecrets = linesOption {default = "";};
      tundra = linesOption {default = "";};
      tundraSecrets = linesOption {default = "";};
    };
    environment = {
      package = mkOption {type = types.package;};
      variables = mkOption {type = types.attrsOf types.str;};
    };
    packages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
    updater = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      interval = mkOption {
        type = types.enum ["daily" "weekly" "monthly"];
        default = "weekly";
      };
      unattended = mkOption {
        type = types.bool;
        default = false;
      };
    };

    filesystem = fsOption {};
    home = fsOption {
      inherit (cfg) user;
      target = x: "${cfg.paths.home}/${x.name}";
    };
    secret = fsOption {
      type = "execute";
      mode = 440;
      group = "users";
      source = decryptSecret self.inputs.secrets;
      target = x: "${cfg.paths.secret.dir}/${x.name}";
      textSource = x: decryptTemplate self.inputs.secrets (writeText "${x.meta.name}-text" x.text);
      meta.secret = true;
    };
    xdg =
      mapAttrs (_: v: (fsOption {
        inherit (cfg) user;
        target = x: "${v}/${x.name}";
      }))
      cfg.paths.xdg;

    id = strOption {readOnly = true;};
    user = strOption {default = "user";};
    paths = {
      home = strOption {default = config.users.users.${cfg.user}.home;};
      secret = {
        dir = strOption {default = "/run/secret";};
        key = strOption {default = "/etc/ssh/ssh_host_ed25519_key";};
      };
      source = strOption {default = "${cfg.paths.xdg.config}/nixos";};
      xdg = mapAttrs (_: v: strOption {default = "${cfg.paths.home}/${v}";}) {
        config = ".config";
        cache = ".cache";
        data = ".local/share";
        state = ".local/state";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd = {
      services = let
        mkTundraService = x: {
          script = ''
            export DSU_KEYFILES DSU_PATH="${config.nix.package}/bin" XDG_RUNTIME_DIR="/run/user/$(id -u ${config.tundra.user})"
            source <(${pkgs.shanetrs.defer-su}/bin/defer-su.init nix-env /nix/var/nix/profiles/system/bin/switch-to-configuration)
            ${pkgs.su}/bin/su ${config.tundra.user} /bin/sh -c '${getExe pkgs.shanetrs.tundra} ${x}'
          '';
          serviceConfig = {
            PrivateTmp = "yes";
            Type = "oneshot";
          };
        };
      in {
        tundra-notifier = mkTundraService "notify";
        tundra-updater = mkTundraService "update";
      };
      timers.tundra-updater = {
        inherit (cfg.updater) enable;
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar =
            {
              "daily" = "*-*-* 04:40:00";
              "weekly" = "Thu *-*-* 04:40:00";
              "monthly" = "Thu *-*-1..7 04:40:00";
            }.${
              cfg.updater.interval
            };
          Unit =
            if cfg.updater.unattended
            then "tundra-updater.service"
            else "tundra-notifier.service";
        };
      };
    };

    environment = {
      systemPackages = [cfg.environment.package];
      extraInit = ''
        source ${cfg.environment.package}/etc/profile.d/*.sh
      '';
    };
    system = {
      activationScripts = {
        tundraEarly = {
          deps = ["specialfs"];
          text = cfg.activation.tundraEarly;
        };
        users.deps = ["tundraEarly"];
        tundra = {
          deps = ["users" "groups" "specialfs" "tundraEarly"];
          text = cfg.activation.tundra;
        };
      };
      systemBuilderCommands = "ln -sf ${self} $out/source";
    };
    tundra = let
      inherit (cfg.activation) tundraEarlySecrets tundraSecrets;
      inherit (fsSubsets) enabled earlySecrets earlyOther secrets other;
      setupCleanup = let
        rev = substring 11 32 self.outPath;
      in ''
        mkdir -p /var/lib/tundra
        tundraLastSystem="$(readlink /var/lib/tundra/current-system || true)"
        [ -e "$tundraLastSystem" ] && [ "$tundraLastSystem" != /var/lib/tundra/system-${rev} ] &&
          mv -fT /var/lib/tundra/current-system /var/lib/tundra/last-system
        [ ! -e /var/lib/tundra/current-system ] && ln -sT /var/lib/tundra/system-${rev} /var/lib/tundra/current-system
        touch /var/lib/tundra/{last,current}-system
      '';
      setupTundra = ''
        tundraDeferred=()
        tundraDeactivate() {
          local command="$(printf "$@")"
          grep -Fxq "$command" /var/lib/tundra/current-system ||
            echo "$command" >> /var/lib/tundra/current-system
        }
        tundraDefer() { tundraDeferred+=("$(printf '%q ' "$@")"); }
        tundraInheritStats() {
          local owner mode
          read -r owner mode <<< $(stat -c '%U:%G %a' "$(dirname "$1")")
          chown "$owner" "$1"
          chmod "$mode" "$1"
        }
      '';
      setupSops = ''
        SOPS_AGE_KEY="$(${getExe pkgs.ssh-to-age} -i "${cfg.paths.secret.key}" -private-key)"
        if [ -n "$SOPS_AGE_KEY" ]; then export SOPS_AGE_KEY
      '';
      cleanupSops = "fi; unset SOPS_AGE_KEY";
      runDeferred = ''
        for i in "''${tundraDeferred[@]}"; do eval "$i"; done
        tundraDeferred=()
      '';
      runCleanup = ''
        source <(comm -23 <(sort /var/lib/tundra/last-system) \
          <(sort /var/lib/tundra/current-system) | sort -nr | cut -d\  -f2-) || true
      '';
      wrapTraps = ''
        tundraTrapDebug="$(trap -P DEBUG)"
        tundraTrapDebugCmd="$(trap -p DEBUG)"
        tundraTrapErr="$(trap -P ERR)"
        tundraTrapErrCmd="$(trap -p ERR)"
        trap "''${tundraTrapDebug:-:}; [[ \$_localstatus -gt 0 ]] && ERR_COMMAND=\$BASH_COMMAND" DEBUG
        trap "''${tundraTrapErr:-:}; echo -e \"\033[31;1m'\$ERR_COMMAND' exited with code \$_localstatus\033[0m\" >&2" ERR
      '';
      unwrapTraps = ''
        eval "''${tundraTrapDebugCmd:-trap - DEBUG}"
        eval "''${tundraTrapErrCmd:-trap - ERR}"
      '';
      inheritExempt = map (x: x.target) enabled;
      mkInheritDir = doDefer: doTrack: x: let
        e = escapeShellArgs [x];
        depth = toString (length (split "/" x));
        defer = optionalString doDefer "tundraDefer ";
        track = optionalString doTrack " && ${defer}tundraInheritStats ${e}";
      in ''
        [ -d ${e} ] || { mkdir ${e}${track} &&
          tundraDeactivate '${depth}) [ -d ${e} ] && rmdir ${e}'; }
      '';
      mkInheritParents = defer: list:
        concatLines (map (x: mkInheritDir defer (!elem x inheritExempt) x)
          (unique (concatMap (x: (deepDirOf x.target)) list)));
    in {
      activation = {
        tundraEarly = ''
          echo 'setting up tundra filesystem...'
          ${wrapTraps}
          ${setupCleanup}
          ${setupTundra}
          ${mkInheritParents true (earlySecrets ++ earlyOther)}
          ${tundraEarlySecrets}
          echo 'populating early tundra files...'
          ${mapConcatLines (x: x.meta.activate) earlyOther}
          ${unwrapTraps}
        '';
        tundraEarlySecrets = mkIf (earlySecrets != []) ''
          echo 'populating early tundra secrets...'
          ${setupSops}
          ${mapConcatLines (x: x.meta.activate) earlySecrets}
          ${cleanupSops}
        '';
        tundra = ''
          ${wrapTraps}
          ${mkInheritParents false (secrets ++ other)}
          ${tundraSecrets}
          echo 'populating tundra files...'
          ${mapConcatLines (x: x.meta.activate) other}
          ${runDeferred}
          ${runCleanup}
          ${unwrapTraps}
        '';
        tundraSecrets = mkIf (secrets != []) ''
          echo 'populating tundra secrets...'
          ${setupSops}
          ${mapConcatLines (x: x.meta.activate) secrets}
          ${cleanupSops}
        '';
      };
      filesystem = listToAttrs (
        map (x: {
          name = x.target;
          value = x;
        }) (flatten ((map attrValues [cfg.home cfg.secret])
            ++ attrValues (mapAttrs (_: attrValues) cfg.xdg)))
      );
      environment = {
        package = buildEnv {
          name = "tundra-environment";
          paths = cfg.packages;
          pathsToLink = ["/bin" "/lib" "/libexec" "/sbin" "/share" "/etc/profile.d"];
          extraOutputsToInstall = ["man" "info" "doc"];
          postBuild = ''
            find $out/bin -maxdepth 1 -name ".*-wrapped" -type l -delete
            find $out/bin -maxdepth 1 -name ".*-wrapped_*" -type l -delete
          '';
        };
        variables = {
          TUNDRA_ID = cfg.id;
          TUNDRA_SOURCE = cfg.paths.source;
        };
      };
      packages = with pkgs; [
        shanetrs.tundra
        (runCommandLocal "tundra-environment-variables" {} ''
          mkdir -p $out/etc/profile.d
          cat <<-EOF > $out/etc/profile.d/tundra-variables.sh
          ${concatLines (mapAttrsToList (k: v: "export ${k}=${escapeShellArgs [v]}") cfg.environment.variables)}
          EOF
        '')
      ];
    };
  };
}
