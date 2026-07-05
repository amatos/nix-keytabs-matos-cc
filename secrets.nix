let
  alberth = "age1gp5d3tzdpufcrk7f6dkr92xtx2p847k79kxxdp9nn0yjk2qvw34sws84m7";
  yubikeyd43f4e92 = "age1yubikey1qdxkz5rs00du7y4284ehlkktq0h93wsqszwegjrx97scqs8ptq3f6kws7sq";
  yubikey2ab5ff2f = "age1yubikey1qtn8y2ad0vr9ddazfsxy4fmlt64kknhjsll2xvfgekck3n0dc0xjvf5rah6";
  yubikeybe7a2b66 = "age1yubikey1qgmkn4s840hwg4kfazjn6u4r2nq9utl60chscraq4sqg9jsf0wleu5eldvv";
  yubikey49705840 = "age1yubikey1qtkf5924nev2a5vqncdurp729tq6xmdf27y6x95fv7kk5zje5vqr6umpnj8";
  yubikey7cb1cad0 = "age1yubikey1q0pmgm34s0ckw8jj9auzlvm5mc6mpxxgc5syu0aw55cqu2hnm7krqrnq60a";
  codex = "age1786r092jkepdahryx7t9kru8txuvreh3f2pgtvrv3u5hmjxjjy3st9udnl";
  gammu = "age12vhj5z6zepnz7uyzks23p6rgwa7rudja7ectsrl89zf96nnmfcnq264972";
  porkchop = "age1yegmaunkewrxj3v6lt86nalta0xq5gq7dpcxrggqp8p7nlzdde4qsnq5jz";
  huginn = "age1je5xg9s90g8l0307xpphclxj3fugvkl59ne9yna46lne9fw0wfpq59lzux";

  users = [
    alberth
    yubikey2ab5ff2f
    yubikeyd43f4e92
    yubikeybe7a2b66
    yubikey49705840
    yubikey7cb1cad0
  ];
in
{
  "keytab-codex.age".publicKeys = [
    users
    codex
  ];

  "keytab-gammu.age".publicKeys = [
    users
    gammu
  ];
  "keytab-porkchop.age".publicKeys = [
    users
    porkchop
  ];
  "keytab-ldap-porkchop.age".publicKeys = [
    users
    porkchop
  ];
  "keytab-huginn.age".publicKeys = [
    users
    huginn
  ];
}
