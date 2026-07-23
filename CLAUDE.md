# keytabs-matos.cc — project directives

## Agent conventions

Any message prefixed with `question:` is a purely theoretical/discussion
request. Treat it as a request for information, reasoning, or discussion
only — **never** as an instruction to perform an action (no file edits,
commits, deployments, or other side effects), regardless of how the rest
of the phrasing reads.

## What this is

keytabs-matos.cc holds sops-encrypted **binary** Kerberos keytabs for the `MATOS.CC`
realm, used by the [nixie](https://github.com/amatos/nixie) NixOS + nix-darwin
configuration. It is a plain git repo, not a flake (`flake = false` in nixie's
`flake.nix`), referenced there as the `nix-keytabs-matos-cc` input.

This repo was split out of `nix-secrets`, which holds only non-binary secrets (SSH
keys, tokens, passwords, etc). It exists specifically because git diffs binary files
poorly and keytabs don't share `nix-secrets`'s plaintext-editing workflow — **keep it
that way**: only binary secrets belong here. A new plaintext secret, even one related
to Kerberos (e.g. a password), belongs in `nix-secrets` instead.

All files are encrypted with [sops](https://github.com/getsops/sops) (via
[sops-nix](https://github.com/Mic92/sops-nix) on the consuming/nixie side), using
[age](https://github.com/FiloSottile/age) as the underlying crypto backend, and
decryptable by the recipients declared in `.sops.yaml`.

> **Note:** as of the sops-nix migration, every host's own keytab now lives in
> `nix-secrets` instead (`nix-secrets/keytab-<host>.age`) — see that repo's own
> `README.md`. This repo currently declares no secrets; it exists as the destination
> for the *next* binary Kerberos secret, not as a currently-populated store. The
> workflow below still applies whenever that happens.

---

## Layout

```text
.sops.yaml                # recipients (who can decrypt what) — path_regex rules
age-yubikey-identity-*.txt # YubiKey identity stubs, not the keys
keytab-*.age                # sops-encrypted binary Kerberos keytabs
```

## Recipients

Defined in `.sops.yaml`'s `keys:` list as YAML anchors, referenced from each rule's
`key_groups`:

- `alberth` — an offline recovery key, no hardware.
- Six YubiKey identities (`yubikey_d43f4e92`, `yubikey_2ab5ff2f`, `yubikey_be7a2b66`,
  `yubikey_49705840`, `yubikey_7cb1cad0`, `yubikey_b4d67c6f`) — touch + PIN required each
  session. Unlike `nix-secrets`, this repo does not currently carry a non-interactive
  (PIN/touch-Never) YubiKey identity; add one following `nix-secrets`'s
  `yubikey_0634d1c4` pattern if scripted/agent decryption is ever needed here.
- One `*<host>_ssh` anchor per nixie host that needs to decrypt a keytab at activation
  time — that host's real SSH host key (`/etc/ssh/ssh_host_ed25519_key.pub`) converted
  to age's X25519 form via `ssh-to-age`. This **must** be the converted `age1...`
  string, not the raw `ssh-ed25519 AAAA...` public key — see `nix-secrets/.sops.yaml`'s
  header comment for the full reasoning (identical mechanism, just a separate
  `.sops.yaml` in this repo). There is no separate host identity file or generation
  step — the SSH host key doubles as the decryption identity directly via
  `sops.age.sshKeyPaths` (sops-nix's default whenever `services.openssh.enable` is
  true, which every nixie host already sets).

The six YubiKey identity stubs are stored in
`age-yubikey-identity-{2ab5ff2f,49705840,7cb1cad0,b4d67c6f,be7a2b66,d43f4e92}.txt`, one
per physical key (stub/pointer files for `age-plugin-yubikey`, not the private keys
themselves). `alberth`'s recovery key has no hardware component and is kept offline.

---

## Creating a new keytab secret

**Prerequisites:** YubiKey inserted; `sops`/`age`/`ssh-to-age` available (they're in
nixie's devShell: `nix develop /path/to/nixie`).

1. **Confirm (or add) a `.sops.yaml` rule** covering the new filename — a
   `path_regex` scoped to `users` plus the one host that needs it:

   ```yaml
   - path_regex: ^keytab-newhost\.age$
     key_groups:
       - age:
           - *alberth
           - *yubikey_d43f4e92
           # ... the rest of the YubiKey anchors
           - *newhost_ssh
   ```

2. **Create the encrypted file** (binary content — the `--input-type binary
   --output-type binary` flags are required; sops's normal YAML-document mode
   doesn't apply to keytabs):

   ```bash
   cd /path/to/nix-keytabs-matos-cc
   sops --input-type binary --output-type binary keytab-newhost.age
   ```

   This opens `$EDITOR` on the raw decrypted bytes — for real keytab material,
   pipe the file in instead of hand-editing:

   ```bash
   cp /path/to/generated/keytab keytab-newhost.age
   sops -e -i --input-type binary --output-type binary keytab-newhost.age
   ```

   `sops -e -i` (in place), not a shell redirect (`sops -e ... > keytab-newhost.age`)
   — `sops` matches `.sops.yaml`'s `path_regex` against the *input* path, so a
   redirect target isn't seen by the matcher and can silently pick the wrong
   recipient rule. Touch the YubiKey when prompted (LED blinks).

3. **Wire it into nixie:**

   - Host keytab deployed to `/etc/krb5.keytab` — in the host's `default.nix`:

     ```nix
     nixie.krb5.keytabFile = "${nix-keytabs-matos-cc}/keytab-newhost.age";
     ```

     (see `modules/common/krb5-client.nix`, which wires this into
     `sops.secrets.hostKeytab` with `format = "binary"`)

   - Service-principal keytab (e.g. LDAP SASL/GSSAPI) — set the relevant
     `services.kerberosLdap.*` option directly, e.g.:

     ```nix
     saslKeytabFile = "${nix-keytabs-matos-cc}/keytab-ldap-newhost.age";
     ```

     (`nix-kerberos-ldap`'s `ldap.nix` wires this into
     `sops.secrets.ldapSaslKeytab` the same way)

   If this is the first keytab nixie consumes for a *new* host file, make sure that
   file declares `nix-keytabs-matos-cc` in its function arguments (it's already in
   `sharedSpecialArgs`, so no `flake.nix` change is needed unless the input itself is
   missing). See nixie's `CLAUDE.md` ("Wiring an external secrets repo into nixie")
   for the full pattern.

4. **Commit both repos:**

   ```bash
   # keytabs-matos.cc
   git add keytab-newhost.age .sops.yaml
   git commit -S -m "feat: add keytab-newhost"
   git push

   # nixie — commit the module changes that reference the new keytab
   ```

---

## Updating an existing keytab's content

No recipient change needed — re-encrypt the new binary content in place over the
existing file:

```bash
cd /path/to/nix-keytabs-matos-cc
cp /path/to/regenerated/keytab keytab-codex.age
sops -e -i --input-type binary --output-type binary keytab-codex.age
```

`sops` re-encrypts to the same recipients already declared in `.sops.yaml` for that
file. Commit as usual.

## Adding a recipient to an existing keytab

1. Add the new key to `.sops.yaml`'s `keys:` list (a new `&<host>_ssh` anchor for a
   new host — see "Recipients" above), then reference that anchor from the relevant
   rule's `key_groups`.
2. Re-encrypt the file's data key for the new recipient set — no need to
   decrypt/re-encrypt the binary content itself:

   ```bash
   sops updatekeys keytab-codex.age
   ```

   Touch the YubiKey when prompted (once per file).
3. Commit and push.

## Removing a recipient

1. Delete the key from `.sops.yaml`'s `key_groups` (and its `keys:` anchor, if
   nothing else references it).
2. `sops updatekeys <file>` for each affected file.
3. Commit and push.

**This does not rotate the keytab.** A removed recipient who already decrypted the
file could have retained a copy — for Kerberos keytabs specifically, treat a
security-motivated removal as a signal to regenerate the principal's key
(`kadmin.local -q "cpw -randkey <principal>"` + re-`ktadd`), not just an access-list
edit, since a leaked keytab grants ongoing authentication as that principal.

---

## Decrypting a secret manually

```bash
sops --decrypt --input-type binary --output-type binary \
  keytab-codex.age > /tmp/keytab-codex
```

Uses whichever age identity file(s) `sops` finds via `SOPS_AGE_KEY_FILE`/`age`'s
default identity discovery, or pass one explicitly:

```bash
export SOPS_AGE_KEY_FILE=age-yubikey-identity-d43f4e92.txt
sops --decrypt --input-type binary --output-type binary \
  keytab-codex.age > /tmp/keytab-codex
```

Touch the YubiKey when prompted. Verify binary content landed correctly with a hex
dump (`xxd /tmp/keytab-codex | head`) rather than assuming — a garbled/wrong-length
keytab has bitten this fleet before (see nixie's `SOPS_MIGRATION.md`).

---

## Conventions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `chore:`, etc.), matching nixie's style, enforced by the same
  commitlint/markdownlint-cli2/nixfmt pre-commit hooks as nixie (`flake.nix`,
  `.commitlintrc.yaml`) — run `nix develop` once to install them.
- All commits must be GPG-signed (`git commit -S`), matching nixie's requirement.
  Enforced in CI by the `verify-signed-commits` job in `.github/workflows/ci.yml`.
- Never commit decrypted plaintext.
- Keep `README.md`'s Recipients and Secrets tables in sync with `.sops.yaml` and the
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
2. Check `.sops.yaml` before adding a new rule/anchor — the host `*_ssh` key you
   need may already be listed for another keytab.
3. After adding, updating, or re-keying a keytab, update the corresponding nixie
   module in the same change set so the two repos don't drift.
