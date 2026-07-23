# keytabs-matos.cc

sops-encrypted Kerberos keytabs for the `MATOS.CC` realm, used by the [nixie](https://github.com/amatos/nixie)
NixOS + nix-darwin configuration. All files are encrypted with [sops](https://github.com/getsops/sops)
(via [sops-nix](https://github.com/Mic92/sops-nix) on the consuming/nixie side), using
[age](https://github.com/FiloSottile/age) as the underlying crypto backend, and decryptable by
the keys listed in `.sops.yaml`.

This repo was split out of `nix-secrets`, which holds only non-keytab secrets (SSH keys, tokens,
passwords, etc).

> **Note:** every host's own keytab now lives in `nix-secrets` instead
> (`nix-secrets/keytab-<host>.age`) — see that repo's own `README.md`. This repo currently
> declares no secrets; it's the destination for the *next* binary Kerberos secret. The workflow
> below still applies whenever that happens.

## Recipients

| Name | Type | Key |
| --- | --- | --- |
| `alberth` | Recovery key (offline, no hardware) | `age1gp5d3tzdpufcrk7f6dkr92xtx2p847k79kxxdp9nn0yjk2qvw34sws84m7` |
| `yubikey_2ab5ff2f` | YubiKey (touch + PIN) | `age1yubikey1qtn8y2ad0vr9ddazfsxy4fmlt64kknhjsll2xvfgekck3n0dc0xjvf5rah6` |
| `yubikey_be7a2b66` | YubiKey (touch + PIN) | `age1yubikey1qgmkn4s840hwg4kfazjn6u4r2nq9utl60chscraq4sqg9jsf0wleu5eldvv` |
| `yubikey_49705840` | YubiKey (touch + PIN) | `age1yubikey1qtkf5924nev2a5vqncdurp729tq6xmdf27y6x95fv7kk5zje5vqr6umpnj8` |
| `yubikey_7cb1cad0` | YubiKey (touch + PIN) | `age1yubikey1q0pmgm34s0ckw8jj9auzlvm5mc6mpxxgc5syu0aw55cqu2hnm7krqrnq60a` |
| `yubikey_b4d67c6f` | YubiKey (touch + PIN) | `age1yubikey1qt9a6xc0nzpe484kzeuw55hsm4shu3ug9j6m4ngtsexqrgptd6zfx596dqn` |

No non-interactive (PIN/touch-Never) YubiKey identity exists in this repo yet, unlike
`nix-secrets`'s `yubikey_0634d1c4` — add one following that pattern if scripted/agent decryption
is ever needed here. No `*_ssh` host anchors exist yet either, since no host currently needs a
keytab from this repo; see `.sops.yaml`'s header comment for how to add one. (A sixth identity,
`yubikey_d43f4e92`, was retired in `nix-secrets` and never carried over here — its stub file is
gone too.)

Five YubiKey identity stubs are stored in
`age-yubikey-identity-{2ab5ff2f,49705840,7cb1cad0,b4d67c6f,be7a2b66}.txt`, one per
physical key. Touch + PIN required once per session for each. `alberth`'s recovery key has no
hardware component and is kept offline.

## Secrets

None currently. When a keytab is added, wire it into nixie via `nixie.krb5.keytabFile` (see
`modules/common/krb5-client.nix`) or a service-specific option (e.g.
`services.kerberosLdap.ldap.saslKeytabFile`), e.g.:

```nix
nixie.krb5.keytabFile = "${nix-keytabs-matos-cc}/keytab-codex.age";
```

---

## Creating a new secret

**Prerequisites:** YubiKey inserted; `sops`/`age`/`ssh-to-age` available (they're in nixie's
devShell: `nix develop /path/to/nixie`).

### 1. Confirm (or add) a `.sops.yaml` rule

The fleet-wide catch-all `.*` rule covers anything without a narrower match. Add a
`path_regex`-scoped rule (see `.sops.yaml`'s header comment) if the new keytab needs a narrower
recipient set — typically the shared identities plus one host's `*_ssh` anchor.

### 2. Create the encrypted file

Binary content requires `--input-type binary --output-type binary`:

```bash
cd /path/to/nix-keytabs-matos-cc
cp /path/to/generated/keytab keytab-newhost.age
sops -e -i --input-type binary --output-type binary keytab-newhost.age
```

`sops -e -i` (in place), not a shell redirect (`sops -e ... > keytab-newhost.age`) — `sops`
matches `.sops.yaml`'s `path_regex` against the *input* path, so a redirect target isn't seen by
the matcher and can silently pick the wrong recipient rule.

Touch the YubiKey when prompted (the LED will blink).

### 3. Wire the secret into nixie

In the host's `default.nix`, set:

```nix
nixie.krb5.keytabFile = "${nix-keytabs-matos-cc}/keytab-newhost.age";
```

which `modules/common/krb5-client.nix` wires into `sops.secrets.hostKeytab` with
`format = "binary"`.

### 4. Commit both repos

```bash
# keytabs-matos.cc
git add keytab-newhost.age .sops.yaml
git commit -m "feat: add keytab-newhost"
git push

# nixie — commit the module changes that reference the new keytab
```

---

## Updating an existing keytab's content

No recipient change needed:

```bash
cd /path/to/nix-keytabs-matos-cc
cp /path/to/regenerated/keytab keytab-codex.age
sops -e -i --input-type binary --output-type binary keytab-codex.age
```

`sops` re-encrypts to the same recipients already declared for that file. Commit as usual.

## Adding a recipient to an existing keytab

1. Add the key to `.sops.yaml`'s `keys:` list (a new `&<host>_ssh` anchor for a new host — see
   "Recipients" above), then reference it from the relevant rule's `key_groups`.
2. Re-encrypt the file's data key for the new recipient set — no need to touch the binary
   content itself:

   ```bash
   sops updatekeys keytab-codex.age
   ```

   Touch the YubiKey when prompted (once per file).
3. Commit and push.

## Removing a recipient

1. Delete the key from `.sops.yaml`'s `key_groups` (and its `keys:` anchor, if nothing else
   references it).
2. `sops updatekeys <file>` for each affected file.
3. Commit and push.

**This does not rotate the keytab.** For a security-motivated removal, regenerate the
principal's key (`kadmin.local -q "cpw -randkey <principal>"` + re-`ktadd`) rather than treating
this as sufficient on its own — a leaked keytab grants ongoing authentication as that principal.

---

## Decrypting a secret manually

```bash
sops --decrypt --input-type binary --output-type binary \
  keytab-codex.age > /tmp/keytab-codex
```

or, to pin a specific identity:

```bash
export SOPS_AGE_KEY_FILE=age-yubikey-identity-2ab5ff2f.txt
sops --decrypt --input-type binary --output-type binary \
  keytab-codex.age > /tmp/keytab-codex
```

Touch the YubiKey when prompted. Verify the content landed correctly with a hex dump
(`xxd /tmp/keytab-codex | head`) rather than assuming — a garbled/wrong-length keytab has bitten
this fleet before (see nixie's `SOPS_MIGRATION.md`).

---

## Development shell

A devShell is provided for this repo's own tooling (`nixfmt`, plus the pre-commit hooks below):

```bash
# Enter the dev shell (automatically via direnv, or manually)
nix develop

# Or, if direnv is installed and .envrc is allowed:
cd nix-keytabs-matos-cc   # shell loads automatically
```

To activate direnv:

```bash
direnv allow
```

This installs `nixfmt`/`markdownlint-cli2`/`commitlint` pre-commit hooks into `.git/hooks`,
matching nixie's own hook set (`flake.nix`, `.commitlintrc.yaml`, `.markdownlint-cli2.yaml`).
`sops`/`age`/`ssh-to-age` are not included here — they're in nixie's devShell
(`nix develop /path/to/nixie`), per "Creating a new secret" above.

A separate `shell.nix` (classic `nix-shell`, not part of the flake outputs above) provides
`sops`, `age`, `age-plugin-yubikey`, `ssh-to-age`, and `git` for working with sops/age/YubiKey
identities directly in this repo without going through nixie's devShell:

```bash
nix-shell
```
