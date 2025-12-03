import json
import os
from dataclasses import dataclass, field
from typing import List, Optional

from .config import APP_DIR, SECRETS_FILE
from .gpg_backend import encrypt_bytes, decrypt_bytes


@dataclass
class Account:
    name: str
    issuer: Optional[str]
    secret_base32: str
    digits: int = 6
    period: int = 30
    algo: str = "SHA1"


@dataclass
class SecretsModel:
    version: int = 1
    gpg_recipients: List[str] = field(default_factory=list)
    accounts: List[Account] = field(default_factory=list)


class SecretsStore:
    def __init__(self):
        APP_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)

    def load(self) -> SecretsModel:
        """
        Load and decrypt the secrets file.
        If file does not exist, return an empty model.
        """
        if not SECRETS_FILE.exists():
            return SecretsModel()

        encrypted_bytes = SECRETS_FILE.read_bytes()
        decrypted = decrypt_bytes(encrypted_bytes)
        raw = json.loads(decrypted.decode("utf-8"))

        accounts = [Account(**a) for a in raw.get("accounts", [])]
        return SecretsModel(
            version=raw.get("version", 1),
            gpg_recipients=raw.get("gpg_recipients", []),
            accounts=accounts
        )

    def save(self, model: SecretsModel):
        """
        Encrypt and save secrets.
        """
        data = {
            "version": model.version,
            "gpg_recipients": model.gpg_recipients,
            "accounts": [vars(a) for a in model.accounts]
        }
        json_bytes = json.dumps(data, indent=2).encode("utf-8")
        encrypted = encrypt_bytes(json_bytes, model.gpg_recipients)
        SECRETS_FILE.write_bytes(encrypted)
