# Key-Compromise and Recovery Playbook for PFTL Release Signing

**Scope:** what to do when a release-signing key for postfiatd binaries,
firmware, or manifests is suspected or confirmed compromised. Every step
below traces to a primary source listed in `SOURCES.md`. This playbook is
a plan, not a claim that any postfiatd key has been compromised — no such
compromise is known.

**Standing facts the playbook is built on**

- A signature never stops rollback. Only a monotonic counter plus a
  version check does. In all four real rollback cases below, the
  signature verified correctly; what failed was an unsigned input, a
  missing revocation step, or a wrong key class.
- Patching is not revocation. They are two separate assertions, and the
  playbook must check the revocation state on the verifier, not the patch
  level on the distributor.
- Expiry is not revocation. A certificate expiring does not block old
  binaries; only a revocation entry does.

## 1. The four rollback cases (why this playbook exists)

| Case | What happened | Lesson |
|---|---|---|
| BootHole, CVE-2020-10713 (Eclypsium, 29 Jul 2020; NSA advisory 30 Jul 2020; CVSS 8.2) | Buffer overflow in GRUB2's parsing of `grub.cfg` — a text file Secure Boot does **not** sign. Attacker with admin/root access modifies `grub.cfg`, gains arbitrary code execution in the UEFI environment, bypasses Secure Boot, installs a bootkit. | Fix required **both** new signed bootloaders **and** revoking trust in old shims via DBX. Patching alone left vulnerable signed GRUB2 loadable. |
| Baton Drop / BlackLotus, CVE-2022-21894 (published 11 Jan 2022; BlackLotus confirmed Mar 2023 by ESET); BlackX disclosed 22 Oct 2026 by Kaspersky | Logic bug in Windows Boot Manager lets an attacker with admin rights enroll attacker Machine Owner Keys and load arbitrary EFI binaries, disabling BitLocker/HVCI/Defender. Microsoft patched the code in Jan 2022/2023 but did **not** auto-revoke the old signed boot manager — the "Windows Production PCA 2011" certificate had to be added to DBX manually (KB5025885). BlackX (early 2026, diplomatic targets in Tajikistan/Uzbekistan/Turkmenistan, attributed to APT41 with medium confidence) ran on **fully patched** machines that skipped DBX revocation. The certificate expired 19 Oct 2026 and that did **not** block the old binaries — only a DBX entry does. | Patching without revocation leaves the window open indefinitely. |
| CVE-2024-7344, Howyar `reloader.efi` / `cloak.dat` (ESET disclosure 16 Jan 2025; Microsoft DBX revocation 14 Jan 2025; CVSS 8.2) | Microsoft-signed UEFI app (Microsoft Corporation UEFI CA 2011) used a custom PE loader instead of `LoadImage`/`StartImage`, so it executed an unsigned UEFI binary from a crafted `cloak.dat` file. Affected 7 recovery products. Required admin/root + EFI System Partition write, then reboot. ESET observed **no** exploitation in telemetry at disclosure. | The signature verified correctly; the failure was an unsigned input the verifier trusted. Fix = vendor patch + Microsoft DBX revocation, not an OS patch. |
| Android OEM platform-key leak (Dec 2022) | OEM platform signing keys leaked; attackers could sign malicious apps as system apps. | A key that should never have been able to sign that class of artifact did. Key scoping (which keys may sign which artifact class) is a control, not a nicety. |

## 2. The six-step runbook

### Step 1 — Freeze signing with the affected key (minutes)

Stop the signer. Do not sign anything else with the compromised key,
including a revocation statement, if the revocation can be issued from a
separate, uncompromised key. Record the time of the freeze and the last
known-good signed release (version + monotonic counter + manifest hash).

### Step 2 — Publish a revocation record (same hour)

Publish a signed revocation record listing the compromised key's public-key
fingerprints (SHA-256 of the DER public key), the reason, and the
timestamp. The record must be fetchable by verifiers independently of the
release channel — a verifier that only learns of a revocation from the
same channel the attacker controls has learned nothing. This pack's drill
(`scripts/compromise_drill.sh`, step 2) publishes
`revocation-set-A.json` in exactly this shape.

### Step 3 — Rotate to a new key set (same day)

Generate a fresh key set (both components of the hybrid: Ed25519 and
ML-DSA-65) on the signer, ideally in the HSM/secure element, and never
reuse the old key material for any purpose. Re-sign the current release
with the new keys and bump the monotonic counter — the counter bump is
what makes the old signed release uninstallable, not the new signature
alone.

### Step 4 — Verify the old release is rejected (same day)

Run the verifier against the old release with the revocation record
present: expected outcome is REJECT (revoked key), even though the old
signatures are cryptographically valid. Run the verifier against the new
release: expected outcome is ACCEPT. Run the old signatures against the
new public keys: expected outcome is failure — rotation must be real,
not cosmetic. This pack's drill (`scripts/compromise_drill.sh`, steps
4–5) performs all three checks and asserts them.

### Step 5 — Notify users with an action, not just an advisory

Tell users what to upgrade to, what to stop trusting, and how to check
(serials/fingerprints — NVIDIA published serials; HashiCorp published
fingerprints). Users who only "patch the OS" stay exposed if revocation
is a separate step (BlackX). The notification must name the revoked
fingerprints so an operator can check them locally.

### Step 6 — Post-mortem and key-hygiene fixes (within a week)

Determine how the key was exposed (build machine, CI secret, HSM
misconfiguration, insider). Fix the exposure class, not just the
instance: separate signing keys per artifact class (release vs firmware
vs manifest — the Android platform-key lesson), short key lifetimes
with scheduled rotation, and a verify-after-sign step on the signer
(see §3). Record the incident in the release notes of the next version.

## 3. Signer hardening (why the 2026 CVE layer matters)

No 2026 cryptanalytic break of ML-DSA or SLH-DSA was found in the
research for this pack. Every 2026 CVE that matters for implementers is
an implementation, compiler, or parsing bug — the lattice assumption has
not broken; the implementations keep breaking:

- **CVE-2026-22705** (RustCrypto, NVD 10 Jan 2026, CVSS 6.4): timing
  side channel in ML-DSA `Decompose` — variable-time hardware division
  on secret-derived values; fixed by constant-time Barrett reduction.
  Lesson: any division/modulo on secret data in an ML-DSA port is
  suspect; audit for it.
- **GHSA-r7wm-4vf2-h44w / RUSTSEC-2026-0426** (orion, 30 Oct 2026):
  LLVM introduces timing-vulnerable optimisations into ML-KEM/ML-DSA
  `conditional_sub_u32()` on targets without cmov/select — the compiler
  *reintroduces* a secret-dependent branch into code written
  constant-time. Lesson: constant-time is a property of the *binary*,
  not the source — re-audit after every toolchain bump, especially for
  firmware cross-compilers.
- **CVE-2026-46344 / CVE-2026-44518** (liboqs XMSS, fixed 0.16.0):
  out-of-bounds read in XMSS/XMSS^MT verification when a public key's
  OID references a different parameter set with larger `sig_bytes` than
  the supplied signature buffer; unauthenticated remote crash. Lesson:
  pin the expected OID/parameter set before calling verify; never trust
  the key's self-described OID.
- **Zhao et al., ePrint 2026/056 ("Rejection Matters", IACR News 14 Jan
  2026):** non-profiling public-template attack using leakage from both
  rejected and accepted signing trials; on ARM Cortex-M4 power traces,
  the challenge `c` is fully recovered with 96 traces and the key in
  ~300 traces (10x fewer than prior art), and it works in hedged mode —
  "hedging offers no SCA protection in this scenario". Lesson: rejection
  sampling is itself a side channel; masking/shuffling/constant-time
  rejection handling is required on any signer an adversary can
  power-trace.

Signer requirements that follow:

1. **Verify-after-sign** on the signer: every signature is verified
   with the public key before it leaves the signer; a fault that flips
   a signature bit is caught at the source, not by a user.
2. **Fault detection**: the 2024–2026 literature shows hedged mode
   alone does not cover fault/side-channel attacks; the signer needs
   fault detection and a constant-time-audited shipped binary.
3. **Pin the toolchain floor**: OpenSSL >= 3.5.6 (CVE-2026-2673 fixed;
   3.5.9 is the current LTS patch used by this pack), Go >= 1.27 for
   stdlib ML-DSA, liboqs >= 0.16.0 if used. Avoid OpenSSL 3.6 (EOL
   1 Nov 2026) and PQClean (archived read-only).

## 4. The 2026 publishing-path lesson

Microsoft's `agent-framework` 1.26.1/1.26.2 on PyPI shipped a credential
stealer via a compromised publishing path (GHSA-764m-3ppc-5m73,
17–18 Nov 2026); quarantining 1.26.1 did not stop 1.26.2 — removing a
version is not revoking the publishing identity. A release-signing
playbook that only revokes versions, and never revokes the publishing
identity (key, token, account), repeats the same error. Step 2 above
revokes the key; the publishing account/token must be rotated in the
same incident.

## 5. What this playbook does not cover

- **Key generation ceremony** (HSM provisioning, quorum, air-gap):
  out of scope for this pack; the drill uses ephemeral test keys.
- **Transparency-log monitoring** (Sigstore Rekor): Rekor is a
  detection and timestamping mechanism — it proves a signature was
  created while a certificate was valid, and makes unexpected signing
  events visible. It does not prove an artifact is safe, and it is not
  a substitute for rollback counters. Sigstore's PQC plan (blog,
  2 Oct 2026) is a separate ML-DSA stack with its own ML-DSA-signed
  TUF root, production public instance targeted mid-2027, opt-in at
  first; classical instance supported until turndown tentatively
  2029–2030. No hybrid certificates, no dual signatures — a project
  wanting dual signatures today must do it itself, which is what this
  pack demonstrates.
