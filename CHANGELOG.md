# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Security

- **URGENT — credential exposure.** The commit that added the backup
  YubiKeys (below) also briefly committed and pushed five plaintext
  `keytab-*` files (no `.age` extension) to `origin/main`. Of these,
  `keytab-codex`, `keytab-gammu`, `keytab-huginn`, and `keytab-porkchop`
  turned out to be harmless `krb5.conf`/`kdc.conf` text snippets (no key
  material) accidentally swept in by `git add -A`. **`keytab-ldap-porkchop`
  was a real, binary Kerberos keytab** for the `ldap/porkchop.ts.matos.cc`
  service principal (kvno=3) — a genuine credential exposure.
- All five plaintext files were removed by amending the offending commit
  (they were introduced and never existed anywhere else in history) and
  force-pushing the cleaned history to `origin/main`.
- **Follow-up still required:** the `ldap/porkchop.ts.matos.cc` service
  principal's key must be regenerated on the KDC (`porkchop`) — e.g. via
  `kadmin.local` `cpw`/`randkey` — and the resulting keytab re-extracted,
  re-encrypted with `ragenix -e keytab-ldap-porkchop.age`, committed, and
  deployed. Until that happens, treat the old key as compromised.
- `.gitignore` added: ignores bare `keytab-*` files (everything except
  `keytab-*.age`), `*.keytab`, `*.dec`, `krb5.conf`, and `kdc.conf` to
  prevent this class of accident going forward.

### Added

- `age-yubikey-identity-b4d67c6f.txt` — YubiKey identity for `b4d67c6f`
- `flake.nix`/`flake.lock` — pre-commit tooling only (`nixpkgs`,
  `pre-commit-hooks`), no system builds; same `nixfmt`/`markdownlint-cli2`/
  `commitlint` hook set as nixie, installed via `nix develop`
- `.commitlintrc.yaml` — copied from nixie so the new `commitlint` hook has
  rules to enforce
- `.gitignore` — added `/.direnv`, `/result`, `/.pre-commit-config.yaml`,
  `/.claude`, matching nixie's, now that this repo has its own Nix dev
  tooling to generate them
- `LICENSE.md` — BSD 2-Clause License
- Five backup YubiKey identities added as recipients (`secrets.nix`
  `users`): `age-yubikey-identity-2ab5ff2f.txt`,
  `age-yubikey-identity-49705840.txt`,
  `age-yubikey-identity-7cb1cad0.txt`,
  `age-yubikey-identity-be7a2b66.txt` (new physical keys), and
  `age-yubikey-identity-d43f4e92.txt` (a re-keyed identity for the
  original YubiKey, serial 13125942, moved from slot 1 to slot 2)
- `secrets.nix` — added a plain, non-YubiKey `alberth` recovery key as
  an additional recipient alongside the five YubiKey identities above

### Changed

- `secrets.nix` — rotated the key for `codex
- `flake.nix` — dropped `x86_64-darwin` from `supportedSystems`; that
  platform/architecture combination is being deprecated
- `secrets.nix` — rotated the primary `alberth` recipient away from
  the original YubiKey (`age-yubikey-identity-9ca1fbf9.txt`) to the
  new recipient set above; all keytabs re-encrypted (`ragenix --rekey`)
  accordingly
- All five current YubiKey identities require a PIN once per session
  (`PIN policy: Once`), unlike the retired identity (`PIN policy:
  Never`) — `README.md` and `CLAUDE.md` updated to reflect this
- `README.md`/`CLAUDE.md` — Recipients tables and identity-stub
  references synced with the new recipient set in `secrets.nix`
- `CLAUDE.md` — Conventions note updated: commit messages are now
  actually enforced by the new commitlint hook, not just followed by
  convention

### Removed

- `age-yubikey-identity-9ca1fbf9.txt` — retired YubiKey identity stub;
  the same physical key continues on as
  `age-yubikey-identity-d43f4e92.txt` (new slot, new PIN policy)

## 26.07.01

### Added

- Repo created by splitting the Kerberos keytabs out of `nix-secrets`,
  which now holds only non-binary secrets
- `keytab-codex.age`, `keytab-gammu.age`, `keytab-porkchop.age` — host
  keytabs deployed to `/etc/krb5.keytab` via `nixie.krb5.keytabFile`
- `keytab-ldap-porkchop.age` — SASL/GSSAPI keytab for the `ldap/`
  service principal on `porkchop`, deployed via
  `services.kerberosLdap.ldap.saslKeytabFile`
- `secrets.nix` — ragenix recipient definitions for `alberth` plus the
  `codex`, `gammu`, and `porkchop` host age keys
- `age-yubikey-identity-9ca1fbf9.txt` — YubiKey identity stub
- `README.md` — recipients/secrets tables and the create, wire, rekey,
  and manual-decrypt workflows for this repo
- `CLAUDE.md` — project directives covering the same workflow, plus the
  rule that plaintext secrets belong in `nix-secrets` instead
- `keytab-huginn.age` — host keytab for `huginn`, deployed to
  `/etc/krb5.keytab`
- `secrets.nix` — added `huginn` host age key as a recipient

### Changed

- `README.md` — Recipients table was missing `huginn`, Secrets table was
  missing `keytab-huginn.age`; both added to match `secrets.nix`
