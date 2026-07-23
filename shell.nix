{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
mkShell {
  buildInputs = [
    sops
    rage
    age
    age-plugin-yubikey
    ssh-to-age
    git
  ];
}
