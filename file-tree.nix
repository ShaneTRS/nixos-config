dir: let
  inherit (builtins) attrNames filter isAttrs listToAttrs mapAttrs;
  inherit (builtins) isString match replaceStrings;
  inherit (builtins) readDir readFile fromJSON;

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
  convertTree (simplifyTree (createTree {inherit dir;}))
