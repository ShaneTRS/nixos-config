{machine, ...}: {
  user.home.file.".cache/standalone".text = "hello ${machine.user}!";
}
