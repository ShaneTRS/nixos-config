{
  self ? null,
  nixosConfig ? throw "nixosConfig is only available in modules!",
  pkgs ? null,
  tree ? null,
  secrets ? self.inputs.secrets,
  nixpkgs ? self.inputs.nixpkgs,
  ...
} @ args: final: prev: let
  inherit (builtins) attrNames filter foldl' isAttrs listToAttrs mapAttrs;
  inherit (builtins) elem elemAt fromJSON match readDir readFile sort substring;
  inherit (builtins) attrValues deepSeq isFunction isPath isString pathExists toJSON warn;
  inherit (nixpkgs.lib) any collect concatMapAttrs findFirst getExe mkIf mkOverride nixosSystem optionalAttrs;

  tundra = rec {
    inherit (fsScripts) decryptSecret decryptTemplate mergeFormat;
    fsScripts = {
      # nixpkgs, nixosConfig, pkgs
      decryptSecret = source: let
        inherit (pkgs) jq sops writeShellScript;
      in
        writeShellScript "decrypt-secret" ''
          { read -r secret; read -r mode; } < <(${getExe jq} -r '
            (.meta.name | split("/") | map("[" + tojson + "]") | join("")),
            (.mode | try tonumber catch "440")
          ' "$2")
          tmp="$1.tmp"
          decrypt() { ${getExe sops} --extract "$secret" --output "$tmp" -d ${source}/$1.yaml 2>/dev/null; }
          decrypt ${nixosConfig.tundra.user} || decrypt global;
          chmod "''$mode" "$tmp"
          mv -f "$tmp" "$1"
        '';

      # nixpkgs, nixosConfig, pkgs
      decryptTemplate = source: template: let
        inherit (pkgs) jq sops writeShellScript;
      in
        writeShellScript "decrypt-template" ''
          read -r mode < <(${getExe jq} -r '.mode | try tonumber catch "440"' "$2")
          decrypt() { ${getExe sops} --output-type json -d ${source}/$1.yaml 2>/dev/null; }
          { decrypt ${nixosConfig.tundra.user}; decrypt global; } |
          ${getExe jq} -rs '
            reduce .[] as $f ({}; . * ($f.all // {})) as $all |
            reduce .[] as $f ({}; . * ($f.${nixosConfig.tundra.id} // {})) as $id |
            reduce .[] as $f ({}; . * $f) | $all * $id * . |
            reduce (paths(scalars) as $p | {
              key: $p | join("."),
              value: getpath($p) | tostring
            } ) as $pair ($text; gsub("%%" + $pair.key; $pair.value))
          ' --rawfile text "${template}" > "$1.tmp"
          chmod "$mode" "$1.tmp"
          mv -f "$1.tmp" "$1"
        '';

      # todo: add support for merging secrets
      # nixpkgs, pkgs
      mergeFormat = type: content: let
        inherit (pkgs) jq perl dasel gnused writeShellScript writeText;
        applyStats = x: ''chmod "$mode" "${x}"; chown "$uid:$gid" "${x}"'';
        getStats = x: ''mode="$(stat -c %a "${x}")" uid="$(stat -c %u "${x}")" gid="$(stat -c %g "${x}")"'';
        contentIsPath = isPath content || isString content && substring 0 1 content == "/";
        contentFile =
          if contentIsPath
          then content
          else writeText "merge-${type}-content" content;
        contentJSON =
          if contentIsPath
          then content
          else writeText "merge-${type}-content" (toJSON content);
      in
        if elem type ["json" "yaml" "hcl" "csv" "toml" "xml" "ini"]
        then
          writeShellScript "merge-${type}" ''
            if [ -f "$1" ]; then
              ${getStats "$1"}
              { ${getExe jq} -s 'if .[0] | type == "array"
                then reduce .[] as $o ([]; . + $o)
                else reduce .[] as $o ({}; . * ($o // {}))
              end' <(${getExe dasel} -i ${type} -o json < "$1") ${contentJSON} ||
                cat ${contentJSON}
              } | ${getExe dasel} -i json -o ${type} > "$1.tmp"
              ${applyStats "$1.tmp"}
            else
              ${getExe dasel} -i json -o ${type} < ${contentJSON} > "$1.tmp"
            fi
            mv -f "$1.tmp" "$1"
          ''
        else if type == "ini-mime"
        then
          writeShellScript "merge-ini-mime" ''
            D="%%DELIM%%"
            if [ -f "$1" ]; then
              ${getStats "$1"}
              { ${getExe jq} -s 'reduce (.[] | to_entries[]) as $cat ({};
                reduce ($cat.value | to_entries[]) as $mime (.;
                  .[$cat.key][$mime.key] += ($mime.value | split("'"$D"'")
                ))) | map_values(map_values(reduce .[] as $v ([];
                  if (index($v)|not) then . + [$v] else . end
                ) | join("'"$D"'")))' <(${getExe gnused} "s:;:$D:g" "$1" | ${getExe dasel} -i ini -o json) <(${getExe gnused} "s:;:$D:g" ${contentJSON}) ||
                ${getExe gnused} "s:;:$D:g" ${contentJSON}
              } | ${getExe dasel} -i json -o ini |
              ${getExe gnused} "s:$D:;:g" > "$1.tmp"
              ${applyStats "$1.tmp"}
            else
              ${getExe gnused} "s:;:$D:g" ${contentJSON} | ${getExe dasel} -i json -o ini |
              ${getExe gnused} "s:$D:;:g" > "$1.tmp"
            fi
            mv -f "$1.tmp" "$1"
          ''
        else if type == "text"
        then
          writeShellScript "merge-text" ''
            if [ -f "$1" ]; then
              ${getExe perl} -0777 -e 'exit !(index(<>, <>) >= 0)' "$1" ${contentFile} && exit
              ${getStats "$1"}
              cat "$1" ${contentFile} > "$1.tmp"
              ${applyStats "$1.tmp"}
            else
              cat ${contentFile} > "$1.tmp"
            fi
            mv -f "$1.tmp" "$1"
          ''
        else throw "unknown type: ${type}!";
    };

    deepDirOf = dir: let
      recurse = dir:
        if dir != "/"
        then recurse (dirOf dir) ++ [dir]
        else [];
    in
      recurse (dirOf dir);

    deepReadDir = dir:
      mapAttrs (name: type:
        if type == "directory"
        then deepReadDir (dir + "/${name}")
        else dir + "/${name}")
      (readDir dir);

    exprToFakeDrv = name: expr:
      if expr.type or null == "derivation"
      then expr
      else {
        inherit name expr;
        drvPath = deepSeq expr "/nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-${name}.drv";
        type = "derivation";
      };

    # self, nixosConfig, nixpkgs
    getConfig' = extra: file: let
      inherit (nixosConfig.tundra) user id;
      exists = x:
        if pathExists x
        then x
        else null;
    in
      findFirst (x: x != null) (warn "no config was found for ${file}!" null) (extra
        ++ [
          (exists (self + "/user/configs/${user}/${id}/${file}"))
          (exists (self + "/user/configs/${user}/all/${file}"))
          (exists (self + "/user/configs/global/${id}/${file}"))
          (exists (self + "/user/configs/global/all/${file}"))
        ]);
    # self, nixosConfig, nixpkgs
    getConfig = file: let
      inherit (nixosConfig.tundra) id secret;
    in
      getConfig' [
        (secret."${id}/${file}".target or null)
        (secret."all/${file}".target or null)
        (secret.${file}.target or null)
      ]
      file;

    # nixpkgs
    getSystems = set:
      concatMapAttrs (k: v:
        optionalAttrs (any (x: let
          this = x ({
              config = {};
              options = {};
              nixosConfig = {};
            }
            // args);
          tundra = this.tundra or this.config.tundra or {};
        in
          tundra ? id || tundra ? source || tundra ? user)
        (collect isFunction v)) {${k} = tundraSystem k;})
      set;

    getOverlays' = list: args: map (x: x args) (filter isFunction list);
    getOverlays = getOverlays' (attrValues tree.overlays); # tree

    mkChecks = outputs: set:
      concatMapAttrs (k: {
        name ? k,
        single ? false,
        final ? x: x,
        prev ? x: x,
        value ? outputs.${name} or outputs.${k},
      }:
        if single
        then {${name} = mapAttrs (k: final) (prev value);}
        else concatMapAttrs (k2: v2: {"${name}-${k2}" = final v2;}) (prev value))
      set;
    mkDrvChecks = outputs: set: mapAttrs exprToFakeDrv (mkChecks outputs set);

    mkIfConfig = file: fn: let attempt = getConfig file; in mkIf (attempt != null) (fn attempt);

    mkStrongDefault = mkOverride 900;

    mkTree = dir: let
      filterNames = attrs: filter (x: match "_.*" x == null) (attrNames attrs);
      convertFiles = tree:
        listToAttrs (map (name: let
          file = tree.${name};
          regex = match "(.+)(\\.nix|\\.json|\\.toml)" name;
          ext = elemAt regex 1;
        in
          if regex != null
          then {
            name = elemAt regex 0;
            value =
              if ext == ".nix"
              then import file
              else if ext == ".json"
              then fromJSON (readFile file) // {__path = file;}
              else fromTOML (readFile file) // {__path = file;};
          }
          else {
            inherit name;
            value =
              if isAttrs file
              then convertFiles file
              else file;
          }) (filterNames tree));
    in
      convertFiles (deepReadDir dir);

    resolveList = list: map (x: x.content or x) (filter (x: x.condition or true) list);
    sortPriorities = list: sort (a: b: (a.priority or 100) < (b.priority or 100)) list;

    toYAML = (pkgs.formats.yaml {}).generate "toYAML"; # pkgs

    transformAttrs = rules: attrs: mapAttrs (k: v: foldl' (acc: this: this k acc) v rules) attrs;

    # self, tree
    tundraSystem = name: let
      systemArgs =
        args
        // {
          inherit (systemArgs.pkgs) lib;
          pkgs = pkgs.appendOverlays (getOverlays systemArgs);
          nixosConfig = system.config;
        };

      system = nixosSystem {
        specialArgs = removeAttrs systemArgs ["pkgs" "lib"];
        inherit (systemArgs) pkgs lib;
        modules =
          collect isFunction tree.systems.${name}
          ++ [
            self.outputs.nixosModules.default
            secrets.nixosModules.default
            {
              tundra.id = name;
              environment.etc."nix/inputs/pkgs".source = nixpkgs;
              nix = {
                package = pkgs.nixVersions.latest;
                registry.pkgs.to = {
                  type = "git";
                  url = "file:" + self;
                };
                settings = {
                  experimental-features = ["nix-command" "flakes"];
                  nix-path = "nixpkgs=/etc/nix/inputs/pkgs";
                };
              };
            }
          ];
      };
    in
      system;
  };
in {
  lib =
    if prev ? lib
    then prev.lib.extend (final: prev: {inherit tundra;})
    else {inherit tundra;};
}
