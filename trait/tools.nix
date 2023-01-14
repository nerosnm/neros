{ config
, lib
, pkgs
, ...
}:

with lib;
let
  cfg = config.cacti.tools;
in
{
  options = {
    cacti.tools = {
      enable = mkEnableOption "tools";
    };
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = with pkgs; [
        bat
        binutils
        btop
        coreutils
        curl
        dig
        direnv
        dnsutils
        exa
        fd
        fzf
        inetutils
        jq
        lsof
        neovim
        nix-index
        nmap
        ripgrep
        sd
        tealdeer
        unzip
        wget
        whois
        xclip
        xsel
        zip
      ];
    };

    programs.zsh = {
      enable = true;
      # Enable starship
      promptInit = ''
        eval "$(${pkgs.starship}/bin/starship init zsh)"
      '';
    };
    users.defaultUserShell = pkgs.zsh;
  };
}
