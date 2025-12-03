import subprocess
from typing import List


class GPGError(Exception):
    pass


def encrypt_bytes(data: bytes, recipients: List[str]) -> bytes:
    """
    Encrypt bytes with GPG to specified recipients.
    """
    if not recipients:
        raise GPGError("No GPG recipients specified.")

    cmd = ["gpg", "--batch", "--yes", "--encrypt"]
    for r in recipients:
        cmd.extend(["--recipient", r])

    proc = subprocess.run(cmd, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise GPGError(f"GPG encryption failed: {proc.stderr.decode()}")
    return proc.stdout


def decrypt_bytes(data: bytes) -> bytes:
    """
    Decrypt bytes using GPG.
    """
    cmd = ["gpg", "--batch", "--yes", "--decrypt"]
    proc = subprocess.run(cmd, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    if proc.returncode != 0:
        raise GPGError("GPG decryption failed. Wrong key or passphrase?")
    return proc.stdout
