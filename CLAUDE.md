# keytabs-matos.cc — project directives

## Agent conventions

Any message prefixed with `question:` is a purely theoretical/discussion
request. Treat it as a request for information, reasoning, or discussion
only — **never** as an instruction to perform an action (no file edits,
commits, deployments, or other side effects), regardless of how the rest
of the phrasing reads.

## What this is

keytabs-matos.cc holds age-encrypted **binary** Kerberos keytabs for the `MATOS.CC`
realm, used by the [nixie](https://github.com/amatos/nixie) NixOS + nix-darwin
configuration. It is a plain git repo, not a flake (`flake = false` in nixie's
`flake.nix`), referenced there as the `nix-keytabs-matos-cc` input.

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
age-yubikey-identity-*.txt           # YubiKey identity stubs, not the keys
keytab-*.age                         # age-encrypted Kerberos keytabs
```

## Recipients

Defined in `secrets.nix`: `alberth` (an offline recovery key, no hardware), five
backup YubiKey identities (`yubikeyd43f4e92`, `yubikey2ab5ff2f`, `yubikeybe7a2b66`,
`yubikey49705840`, `yubikey7cb1cad0`), plus a host age key per nixie host that
needs to decrypt its keytab at activation time (`codex`, `gammu`, `porkchop`, ...).
Host keys live at `/etc/age/host-key` on each host, generated on first activation
by nixie's `modules/common/age-host-key.nix`.

The YubiKeys' touch policy is **cached** (one touch valid for 15 seconds); a PIN
is required once per session for each YubiKey.

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
   cd /path/to/nix-keytabs-matos-cc
   ragenix -e keytab-newhost.age
   ```

   This opens `$EDITOR`. Paste or type the keytab content, save, close. ragenix
   encrypts to every recipient listed in `secrets.nix` and writes
   `keytab-newhost.age`. Touch the YubiKey when prompted (LED blinks).

3. **Wire it into nixie:**

   - Host keytab deployed to `/etc/krb5.keytab` — in the host's `default.nix`:

     ```nix
     nixie.krb5.keytabFile = "${nix-keytabs-matos-cc}/keytab-newhost.age";
     ```

     (see `modules/common/krb5-client.nix` for the option that consumes this)

   - Service-principal keytab (e.g. LDAP SASL/GSSAPI) — set the relevant
     `services.kerberosLdap.*` option directly, e.g.:

     ```nix
     saslKeytabFile = "${nix-keytabs-matos-cc}/keytab-ldap-newhost.age";
     ```

   If this is the first keytab nixie consumes for a *new* host file, make sure that
   file declares `nix-keytabs-matos-cc` in its function arguments (it's already in
   `sharedSpecialArgs`, so no `flake.nix` change is needed unless the input itself is
   missing). See nixie's `CLAUDE.md` ("Wiring an external secrets repo into nixie")
   for the full pattern.

4. **Commit both repos:**

   ```bash
   # keytabs-matos.cc
   git add keytab-newhost.age secrets.nix
   git commit -S -m "feat: add keytab-newhost"
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
   cd /path/to/nix-keytabs-matos-cc
   ragenix --rekey
   ```

   Touch the YubiKey when prompted (once per secret file).

4. Commit:

   ```bash
   git add -A
   git commit -S -m "chore: rekey secrets for newhostname"
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

## Conventions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `chore:`, etc.), matching nixie's style, enforced by the same
  commitlint/markdownlint-cli2/nixfmt pre-commit hooks as nixie (`flake.nix`,
  `.commitlintrc.yaml`) — run `nix develop` once to install them.
- All commits must be GPG-signed (`git commit -S`), matching nixie's requirement.
  Enforced in CI by the `verify-signed-commits` job in `.github/workflows/ci.yml`.
- Never commit decrypted plaintext.
- Keep `README.md`'s Recipients and Secrets tables in sync with `secrets.nix` and the
  files actually present whenever either changes.

## Releases

Releases use CalVer, matching nixie: `yy.mm.release` (e.g. `26.07.01`).

- The release counter resets to `01` at the start of each new month.
- Tags are GPG-signed: `git tag -s yy.mm.release -m "Release yy.mm.release"`.
- Before tagging, check the highest existing tag for the month:
  `git tag --list 'yy.mm.*' | sort`
- Combine all changes since the last release into a single `CHANGELOG.md`
  entry named after the tagged version.

## Before making changes

1. Confirm the secret is actually binary — plaintext secrets, even Kerberos-related
   ones (passwords, etc.), belong in `nix-secrets`, not here.
2. Check `secrets.nix` before adding a new recipient — the host key you need may
   already be listed for another keytab.
3. After adding or rekeying a keytab, update the corresponding nixie module in the
   same change set so the two repos don't drift.
