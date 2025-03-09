{
  tree,
  machine,
  fn,
  ...
}: {
  imports = [(fn.importItem tree.user.homes.${machine.user})];
  shanetrs.enable = true;
}
