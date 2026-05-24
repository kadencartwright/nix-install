{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Kaden Cartwright";
        email = "kaden@example.com";
      };
      init.defaultBranch = "main";
      pull.ff = "only";
      push.autoSetupRemote = true;
    };
  };
}
