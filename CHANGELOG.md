# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

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
