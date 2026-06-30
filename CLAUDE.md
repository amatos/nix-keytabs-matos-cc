# keytabs-matos.cc — project directives

## What this is

keytabs-matos.cc holds age-encrypted **binary** Kerberos keytabs for the `MATOS.CC`
realm, used by the [nixie](https://github.com/amatos/nixie) NixOS + nix-darwin
configuration. It is a plain git repo, not a flake (`flake = false` in nixie's
`flake.nix`), referenced there as the `keytabs-matos-cc` input.

This repo was split out of `nix-secrets`, which holds only non-binary secrets (SSH
keys, tokens, passwords, etc). It exists specifically because git diffs binary files
poorly and keytabs don't share `nix-secrets`'s plaintext-editing workflow — **keep it
that way**: only binary secrets belong here. A new plaintext secret, even one related
to Kerberos (e.g. a password), belongs in `nix-secrets` instead.

All files are encrypted with [ragenix](https://github.com/yaxitech/ragenix) and
decryptable by the recipients declared in `secrets.nix`.

---

## Layout

```text
secrets.nix                          # ragenix recipients (who can decrypt what)
age-yubikey-identity-9ca1fbf9.txt    # YubiKey identity stub, not the key
keytab-*.age                         # age-encrypted Kerberos keytabs
```

## Recipients

Defined in `secrets.nix`: `alberth` (YubiKey, slot 1), plus a host age key per nixie
host that needs to decrypt its keytab at activation time (`codex`, `gammu`,
`porkchop`, ...). Host keys live at `/etc/age/host-key` on each host, generated on
first activation by nixie's `modules/common/age-host-key.nix`.

The YubiKey's touch policy is **cached** (one touch valid for 15 seconds); PIN is not
required.

---

## Creating a new keytab secret

**Prerequisites:** YubiKey inserted; `ragenix` available (it's in the nixie devShell:
`nix develop /path/to/nixie`).

1. **Declare it in `secrets.nix`** — map the new filename to the recipient keys that
   should decrypt it (typically `users` plus the one host that needs it):

   ```nix
   "keytab-newhost.age".publicKeys = [ users newhost ];
   ```

2. **Create (or edit) the encrypted file:**

   ```bash
   cd /path/to/keytabs-matos-cc
   ragenix -e keytab-newhost.age
   ```

   This opens `$EDITOR`. Paste or type the keytab content, save, close. ragenix
   encrypts to every recipient listed in `secrets.nix` and writes
   `keytab-newhost.age`. Touch the YubiKey when prompted (LED blinks).

3. **Wire it into nixie:**

   - Host keytab deployed to `/etc/krb5.keytab` — in the host's `default.nix`:

     ```nix
     nixie.krb5.keytabFile = "${keytabs-matos-cc}/keytab-newhost.age";
     ```

     (see `modules/common/krb5-client.nix` for the option that consumes this)

   - Service-principal keytab (e.g. LDAP SASL/GSSAPI) — set the relevant
     `services.kerberosLdap.*` option directly, e.g.:

     ```nix
     saslKeytabFile = "${keytabs-matos-cc}/keytab-ldap-newhost.age";
     ```

   If this is the first keytab nixie consumes for a *new* host file, make sure that
   file declares `keytabs-matos-cc` in its function arguments (it's already in
   `sharedSpecialArgs`, so no `flake.nix` change is needed unless the input itself is
   missing). See nixie's `CLAUDE.md` ("Wiring an external secrets repo into nixie")
   for the full pattern.

4. **Commit both repos:**

   ```bash
   # keytabs-matos.cc
   git add keytab-newhost.age secrets.nix
   git commit -m "feat: add keytab-newhost"
   git push

   # nixie — commit the module changes that reference the new keytab
   ```

---

## Rekeying secrets (after adding a new host)

1. On the new host, after first activation, get its public key:

   ```bash
   age-keygen -y /etc/age/host-key
   ```

2. Add it to `secrets.nix`:

   ```nix
   let
     newhostname = "age1...";   # paste public key here
   in ...
   ```

3. Rekey all secrets:

   ```bash
   cd /path/to/keytabs-matos-cc
   ragenix --rekey
   ```

   Touch the YubiKey when prompted (once per secret file).

4. Commit:

   ```bash
   git add -A
   git commit -m "chore: rekey secrets for newhostname"
   git push
   ```

---

## Decrypting a secret manually

```bash
age --decrypt \
  -i age-yubikey-identity-9ca1fbf9.txt \
  keytab-codex.age
```

Touch the YubiKey when prompted.

---

## Conventions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `chore:`, etc.), matching nixie's style, even though this repo has
  no commitlint enforcement of its own.
- Never commit decrypted plaintext.
- Keep `README.md`'s Recipients and Secrets tables in sync with `secrets.nix` and the
  files actually present whenever either changes.

## Before making changes

1. Confirm the secret is actually binary — plaintext secrets, even Kerberos-related
   ones (passwords, etc.), belong in `nix-secrets`, not here.
2. Check `secrets.nix` before adding a new recipient — the host key you need may
   already be listed for another keytab.
3. After adding or rekeying a keytab, update the corresponding nixie module in the
   same change set so the two repos don't drift.
