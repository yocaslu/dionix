# Convertido de dot_config/lsd/colors.yaml (yocaslu/dotfiles)
colors: {
  user = "${colors.base0E}";
  group = "${colors.base07}";
  permission = {
    read = "${colors.base0B}";
    write = "${colors.base0A}";
    exec = "${colors.base08}";
    exec-sticky = "${colors.base0E}";
    no-access = "${colors.base04}";
    octal = "${colors.base0C}";
    acl = "${colors.base0C}";
    context = "${colors.base0C}";
  };
  date = {
    hour-old = "${colors.base0C}";
    day-old = "${colors.base0C}";
    older = "${colors.base0C}";
  };
  size = {
    none = "${colors.base04}";
    small = "${colors.base0B}";
    medium = "${colors.base0A}";
    large = "${colors.base09}";
  };
  inode = {
    valid = "${colors.base0E}";
    invalid = "${colors.base04}";
  };
  links = {
    valid = "${colors.base0E}";
    invalid = "${colors.base04}";
  };
  tree-edge = "${colors.base04}";
  git-status = {
    default = "${colors.base05}";
    unmodified = "${colors.base04}";
    ignored = "${colors.base04}";
    new-in-index = "${colors.base0B}";
    new-in-workdir = "${colors.base0B}";
    typechange = "${colors.base0A}";
    deleted = "${colors.base08}";
    renamed = "${colors.base0B}";
    modified = "${colors.base0A}";
    conflicted = "${colors.base08}";
  };
}
