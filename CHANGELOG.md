# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

---

## 26.07.06

### Added

- `.sops.yaml` — recipients scaffold ([sops](https://github.com/getsops/sops)/
  [sops-nix](https://github.com/Mic92/sops-nix), replacing `secrets.nix`/
  [ragenix](https://github.com/yaxitech/ragenix)), mirroring `nix-secrets`'s shared identities
  (no host-specific `*_ssh` anchors yet — none needed until a host requires a keytab from this
  repo again). Smoke-tested via a successful `sops -e -i` round-trip.
- `CLAUDE.md`/`README.md` rewritten for the sops workflow, including sections this repo never
  had under ragenix: updating an existing keytab's content, and adding/removing a recipient
  (`sops updatekeys`).
- `sops`/`ssh-to-age` added to `shell.nix`, so the documented manual-decrypt workflow works
  standalone, not just via `nix develop /path/to/nixie`.

### Removed

- `keytab-codex.age`, `keytab-gammu.age`, `keytab-huginn.age`, `keytab-muninn.age`,
  `keytab-porkchop.age`, `keytab-ldap-muninn.age`, `keytab-ldap-porkchop.age` — every host
  keytab migrated to the sops-encrypted equivalent in `nix-secrets`
  (`nix-secrets/keytab-<host>.age`); this repo currently declares no secrets.
  `keytab-ldap-porkchop.age` specifically had zero consumers left (porkchop's LDAP role was
  already decommissioned) and was deleted outright rather than migrated.
- `age-yubikey-identity-d43f4e92.txt` — retired YubiKey identity stub, dropped from the new
  `.sops.yaml` scaffold before it was ever used as a live recipient here.

See `nixie`'s `SOPS_MIGRATION.md` for the full 8-phase migration record.

---

## 26.07.05

### Added

- `secrets.nix` — added the `muninn` recipient key and
  `keytab-muninn.age`/`keytab-ldap-muninn.age` entries, prerequisite for
  moving Kerberos+LDAP from porkchop to muninn (nixie's ARCHITECTURE.md
  §10 Stage 2). Reused muninn's existing `nix-secrets` pubkey, since both
  repos key off the same `/etc/age/host-key` identity per host.
- `keytab-muninn.age` (host keytab, `host/muninn.matos.cc`) and
  `keytab-ldap-muninn.age` (SASL/GSSAPI keytab, `ldap/muninn.ts.matos.cc`)
  for muninn's Kerberos+LDAP role, encrypted against the recipients
  declared above.

### Fixed

- `keytab-ldap-muninn.age`, `keytab-ldap-porkchop.age` — regenerated with
  an added `ldap/<host>.tail2269e5.ts.net@MATOS.CC` alias principal
  alongside the existing `ldap/<host>.ts.matos.cc` one. Fixes a
  pre-existing bug in the realm's GSSAPI/SASL LDAP bind, discovered while
  validating nixie's porkchop→muninn migration (ARCHITECTURE.md §10 Stage
  2): Cyrus SASL's GSSAPI client plugin builds its target service
  principal from the peer's *reverse-DNS* name, not the connect hostname,
  and Tailscale's PTR records always answer with the tailnet's native
  name rather than the `ts.matos.cc` alias — so no client could ever
  obtain a ticket for the principal that was actually configured. See
  nixie's matching commit for the full explanation and the companion
  `olcSaslHost`/`saslAuthzRegexp` fixes.

---

## 26.07.04

### Added

- `shell.nix` — classic `nix-shell` environment (`rage`, `age`,
  `age-plugin-yubikey`, `git`) for working with age/YubiKey identities
  directly in this repo; documented in README "Development shell".
- `.github/workflows/ci.yml` — new CI, `verify-signed-commits` job fails the
  build if any commit in a push/PR has no GPG signature (`git log
  --pretty=%G?`).

### Changed

- `flake.nix`, `CLAUDE.md`, `README.md` — updated self-references from
  `keytabs-matos-cc` to `nix-keytabs-matos-cc`, matching the same rename
  on GitHub.
- `flake.nix` — dropped the unused `self` function arg flagged by nixd.
- `CLAUDE.md` "Conventions" — now requires GPG-signed commits, matching
  nixie's requirement (previously only release tags were documented as
  signed), and documents the new CI enforcement; example `git commit`
  commands updated to `git commit -S`.

---

## 26.07.03

### Added

- `.envrc` (`use flake`) — direnv now loads the devShell automatically on
  `cd`; documented in README "Development shell".

---

## 26.07.02

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

- `secrets.nix` — rotated the `codex` host recipient key; `keytab-codex.age`
  re-encrypted (`ragenix -e`) accordingly
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
