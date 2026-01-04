let
  inherit (builtins) attrNames filter isAttrs isFunction listToAttrs mapAttrs;
  inherit (builtins) isString match replaceStrings;
  inherit (builtins) pathExists readDir readFile fromJSON toJSON;
  inherit (builtins) head length tail trace;
in rec {
  pure = rec {
    findFirst = pred: def: list:
      if length list == 0
      then def
      else let
        first = head list;
      in
        if pred first
        then first
        else findFirst pred def (tail list);

    fileTree = dir: let
      createTree = {
        dir,
        item ? {
          k = ".";
          v = "directory";
        },
      }:
        if item ? v && item.v == "directory"
        then let
          __path = "${dir}/${item.k}";
        in {
          dir = __path;
          item =
            mapAttrs (k: v:
              createTree {
                item = {inherit k v;};
                dir = __path;
              }) (readDir __path)
            // {inherit __path;};
        }
        else dir;
      filteredTreeNames = tree: let
        keys = attrNames tree;
        visible = x: match "_[^_].*" x == null;
      in
        filter visible keys;

      convertTree = tree:
        if isAttrs tree
        then
          listToAttrs (map (key: {
            name = replaceStrings [".nix" ".json" ".toml"] ["" "" ""] key;
            value = let
              __path = "${tree.${key}}/${key}";
              ext = match ".*\\.(nix|json|toml)" key;
            in
              if ext == ["nix"]
              then import __path
              else if ext == ["json"]
              then fromJSON (readFile __path) // {inherit __path;}
              else if ext == ["toml"]
              then fromTOML (readFile __path) // {inherit __path;}
              else if isString tree.${key} && match "__.*" key == null
              then __path
              else tree.${key};
          }) (filteredTreeNames tree))
        else tree;

      simplifyTree = tree:
        if tree ? item
        then mapAttrs (k: v: convertTree (simplifyTree v)) tree.item
        else tree;
    in
      convertTree (simplifyTree (createTree {inherit dir;}));

    importItem = nix:
      if isFunction nix
      then nix
      else nix.default;

    resolveList = list: map (i: i.content or i) (filter (i: i.condition or true) list);
  };
  tundra = {
    self,
    pkgs,
    machine,
    secrets ? self.nixosConfigurations.${machine.serial}.config.sops.secrets,
    ...
  }: {
    configs = file:
      with machine;
        if secrets ? ${file}
        then secrets.${file}.path
        else
          pure.findFirst pathExists (trace "no config was found for ${file}!" null) [
            "${self}/user/configs/${user}/${profile}/${file}"
            "${self}/user/configs/${user}/all/${file}"
            "${self}/user/configs/global/${profile}/${file}"
            "${self}/user/configs/global/all/${file}"
          ];
    toYAML = attrs: "${pkgs.runCommand "toYAML" {
        buildInputs = [pkgs.yj];
        attrs = toJSON attrs;
        passAsFile = ["attrs"];
      } ''
        mkdir -p $out
        yj -jy < "$attrsPath" > $out/attrs.yaml
      ''}/attrs.yaml";
  };
}
