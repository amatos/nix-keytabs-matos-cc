# keytabs-matos.cc

Age-encrypted Kerberos keytabs for the `MATOS.CC` realm, used by the [nixie](https://github.com/amatos/nixie)
NixOS + nix-darwin configuration. All files are encrypted with [ragenix](https://github.com/yaxitech/ragenix)
and decryptable by the keys listed in `secrets.nix`.

This repo was split out of `nix-secrets`, which now holds only non-keytab secrets (SSH keys, tokens, passwords, etc).

## Recipients

| Name | Type | Key |
| --- | --- | --- |
| `alberth` | Recovery key (offline, no hardware) | `age1gp5d3tzdpufcrk7f6dkr92xtx2p847k79kxxdp9nn0yjk2qvw34sws84m7` |
| `yubikeyd43f4e92` | YubiKey (slot 2) | `age1yubikey1qdxkz5rs00du7y4284ehlkktq0h93wsqszwegjrx97scqs8ptq3f6kws7sq` |
| `yubikey2ab5ff2f` | YubiKey (backup, slot 1) | `age1yubikey1qtn8y2ad0vr9ddazfsxy4fmlt64kknhjsll2xvfgekck3n0dc0xjvf5rah6` |
| `yubikeybe7a2b66` | YubiKey (backup, slot 1) | `age1yubikey1qgmkn4s840hwg4kfazjn6u4r2nq9utl60chscraq4sqg9jsf0wleu5eldvv` |
| `yubikey49705840` | YubiKey (backup, slot 1) | `age1yubikey1qtkf5924nev2a5vqncdurp729tq6xmdf27y6x95fv7kk5zje5vqr6umpnj8` |
| `yubikey7cb1cad0` | YubiKey (backup, slot 1) | `age1yubikey1q0pmgm34s0ckw8jj9auzlvm5mc6mpxxgc5syu0aw55cqu2hnm7krqrnq60a` |
| `codex` | Host key (`/etc/age/host-key`) | `age1786r092jkepdahryx7t9kru8txuvreh3f2pgtvrv3u5hmjxjjy3st9udnl` |
| `gammu` | Host key (`/etc/age/host-key`) | `age12vhj5z6zepnz7uyzks23p6rgwa7rudja7ectsrl89zf96nnmfcnq264972` |
| `porkchop` | Host key (`/etc/age/host-key`) | `age1yegmaunkewrxj3v6lt86nalta0xq5gq7dpcxrggqp8p7nlzdde4qsnq5jz` |
| `huginn` | Host key (`/etc/age/host-key`) | `age1je5xg9s90g8l0307xpphclxj3fugvkl59ne9yna46lne9fw0wfpq59lzux` |

Five YubiKey identity stubs are stored in
`age-yubikey-identity-{2ab5ff2f,49705840,7cb1cad0,be7a2b66,d43f4e92}.txt`,
one per physical key. Touch policy is **cached** (one touch valid for 15
seconds); a **PIN is required once per session** for these keys. `alberth`'s
recovery key has no hardware component and is kept offline.

## Secrets

| File | Purpose |
| --- | --- |
| `keytab-codex.age` | Host keytab for `codex`, deployed to `/etc/krb5.keytab` |
| `keytab-gammu.age` | Host keytab for `gammu`, deployed to `/etc/krb5.keytab` |
| `keytab-porkchop.age` | Host keytab for `porkchop`, deployed to `/etc/krb5.keytab` |
| `keytab-ldap-porkchop.age` | SASL/GSSAPI keytab for the `ldap/` service principal on `porkchop`, deployed for `services.kerberosLdap.ldap.saslKeytabFile` |
| `keytab-huginn.age` | Host keytab for `huginn`, deployed to `/etc/krb5.keytab` |

Each host's keytab is wired into nixie via `nixie.krb5.keytabFile` (see `modules/common/krb5-client.nix`), e.g.:

```nix
nixie.krb5.keytabFile = "${keytabs-matos-cc}/keytab-codex.age";
```

---

## Creating a new secret

**Prerequisites:** YubiKey inserted; `ragenix` available (it's in the nixie devShell: `nix develop /path/to/nixie`).

### 1. Declare the secret in `secrets.nix`

Add an entry mapping the new filename to the list of recipient keys that should be able to decrypt it:

```nix
"keytab-newhost.age".publicKeys = [ users newhost ];
```

### 2. Create (or edit) the encrypted file

```bash
cd /path/to/keytabs-matos-cc
ragenix -e keytab-newhost.age
```

This opens `$EDITOR`. Paste or type the keytab content, save, and close. ragenix encrypts the content
to all recipients listed in `secrets.nix` and writes `keytab-newhost.age`.

Touch the YubiKey when prompted (the LED will blink).

### 3. Wire the secret into nixie

In the host's `default.nix`, set:

```nix
nixie.krb5.keytabFile = "${keytabs-matos-cc}/keytab-newhost.age";
```

### 4. Commit both repos

```bash
# keytabs-matos.cc
git add keytab-newhost.age secrets.nix
git commit -m "feat: add keytab-newhost"
git push

# nixie — commit the module changes that reference the new keytab
```

---

## Rekeying secrets (after adding a new host)

When a new host is added to nixie, generate its host key (`nixos-rebuild switch` will create
`/etc/age/host-key` on first activation), then add its public key to `secrets.nix` and rekey all
secrets so the new host can decrypt them:

### 1. Get the new host's public key

On the new host after first activation:

```bash
age-keygen -y /etc/age/host-key
```

### 2. Add it to `secrets.nix`

```nix
let
  newhostname = "age1...";   # paste public key here
in ...
```

### 3. Rekey all secrets

```bash
cd /path/to/keytabs-matos-cc
ragenix --rekey
```

Touch the YubiKey when prompted (once per secret file).

### 4. Commit

```bash
git add -A
git commit -m "chore: rekey secrets for newhostname"
git push
```

---

## Decrypting a secret manually

```bash
age --decrypt \
  -i age-yubikey-identity-d43f4e92.txt \
  keytab-codex.age
```

Touch the YubiKey when prompted.

---

## Development shell

A devShell is provided for this repo's own tooling (`nixfmt`, plus the pre-commit hooks below):

```bash
cd /path/to/keytabs-matos-cc
nix develop
```

This installs `nixfmt`/`markdownlint-cli2`/`commitlint` pre-commit hooks into `.git/hooks`,
matching nixie's own hook set (`flake.nix`, `.commitlintrc.yaml`, `.markdownlint-cli2.yaml`).
`ragenix` is not included here — it's still only in nixie's devShell
(`nix develop /path/to/nixie`), per "Creating a new secret" above.
