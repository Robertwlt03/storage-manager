#!/usr/bin/env python3
"""Creates a self-signed code-signing identity in a keychain of its own, once per Mac, so every
rebuild keeps the same identity and macOS keeps Full Disk Access.

Start:  make identity
Needs:  nothing; macOS asks for your password once, to trust the certificate for code signing.
The keychain's random password goes to local.mk, which git ignores; it protects only this
development certificate, and nothing leaves this Mac.
"""

import re
import secrets
import tempfile
from pathlib import Path

from build import run
from checks import console, project
from checks.project import PROJECT

# MARK: Settings

IDENTITY_NAME = "Speicher-Explorer Dev"
KEYCHAIN = Path.home() / "Library" / "Keychains" / "speicher-explorer-signing.keychain-db"
SETTINGS_FILE = PROJECT / "local.mk"
SIGNING_SETTING = re.compile(r"^(SIGN_IDENTITY|SIGNING_KEYCHAIN|SIGNING_KEYCHAIN_PASSWORD) *=")
SAVED_PASSWORD = re.compile(r"^SIGNING_KEYCHAIN_PASSWORD *= *(.*)$", re.MULTILINE)
VALID_DAYS = 3650  # ten years
KEY_BITS = 2048
CERTIFICATE_SETTINGS = f"""[req]
distinguished_name = name
x509_extensions = usage
prompt = no
[name]
CN = {IDENTITY_NAME}
[usage]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
"""


# MARK: Steps


def unlock_existing_keychain() -> None:
    saved = SAVED_PASSWORD.search(SETTINGS_FILE.read_text())
    run(["security", "unlock-keychain", "-p", saved.group(1).strip() if saved else "", KEYCHAIN])


def create_keychain(password: str) -> None:
    run(["security", "create-keychain", "-p", password, KEYCHAIN])
    run(["security", "set-keychain-settings", KEYCHAIN])  # without options: it never locks itself


def create_identity(password: str, work_folder: Path) -> Path:
    """Key and certificate together as one identity, the form the keychain imports."""
    settings = work_folder / "certificate.conf"
    settings.write_text(CERTIFICATE_SETTINGS)
    key, certificate, identity = (work_folder / name for name in
                                  ("key.pem", "certificate.pem", "identity.p12"))
    run(["/usr/bin/openssl", "req", "-x509", "-newkey", f"rsa:{KEY_BITS}", "-nodes",
         "-days", str(VALID_DAYS), "-config", settings, "-keyout", key, "-out", certificate])
    run(["/usr/bin/openssl", "pkcs12", "-export", "-name", IDENTITY_NAME, "-inkey", key,
         "-in", certificate, "-out", identity, "-passout", f"pass:{password}"])
    return identity


def import_identity(identity: Path, password: str) -> None:
    # codesign may use the key without asking: the access list (-T) and the partition list.
    run(["security", "import", identity, "-k", KEYCHAIN, "-P", password,
         "-T", "/usr/bin/codesign"])
    run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s",
         "-k", password, KEYCHAIN])


def write_settings(password: str) -> None:
    """Keeps whatever else local.mk holds and replaces only the signing lines."""
    kept = [
        line for line in (SETTINGS_FILE.read_text() if SETTINGS_FILE.exists() else "").splitlines()
        if not SIGNING_SETTING.match(line)
    ]
    signing = [
        f"SIGN_IDENTITY = {IDENTITY_NAME}",
        f"SIGNING_KEYCHAIN = {KEYCHAIN}",
        f"SIGNING_KEYCHAIN_PASSWORD = {password}",
    ]
    SETTINGS_FILE.write_text("\n".join(kept + signing) + "\n")
    console.passed("Settings written", SETTINGS_FILE.name)


def trust_for_code_signing(work_folder: Path) -> None:
    """Newer macOS keeps Full Disk Access across rebuilds only for a certificate it trusts for
    code signing; without that trust it ties the grant to each build's exact contents."""
    certificate = work_folder / "trusted.pem"
    certificate.write_text(run(["security", "find-certificate", "-c", IDENTITY_NAME, "-p",
                                KEYCHAIN]))
    # A question to macOS, not a step that may fail: is the certificate trusted already?
    verification = ["security", "verify-cert", "-c", str(certificate), "-p", "codeSign"]
    if not project.run(verification).succeeded:
        console.step("macOS now asks once for your password",
                     f"to trust {IDENTITY_NAME} for code signing")
        run(["security", "add-trusted-cert", "-r", "trustRoot", "-p", "codeSign",
             "-k", KEYCHAIN, certificate])
    console.passed("Trusted for code signing", IDENTITY_NAME)


# MARK: Run


def main() -> None:
    console.heading("Speicher-Explorer · signing identity", IDENTITY_NAME)
    # The key files live in a folder that is removed at the end, so they never stay on disk.
    with tempfile.TemporaryDirectory() as folder:
        work_folder = Path(folder)
        if KEYCHAIN.exists():
            console.step("The signing keychain already exists", str(KEYCHAIN))
            unlock_existing_keychain()
            trust_for_code_signing(work_folder)
            return
        password = secrets.token_hex(24)  # made for passwords, from the system's random source
        create_keychain(password)
        import_identity(create_identity(password, work_folder), password)
        write_settings(password)
        console.passed("Identity created", "in its own keychain")
        trust_for_code_signing(work_folder)
    console.frame("Signing identity ready", [
        "local.mk signs with it",
        "Grant Full Disk Access to the app once after the next make run",
    ], console.SUCCESS)


if __name__ == "__main__":
    main()
