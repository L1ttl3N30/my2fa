import time
import hmac
import hashlib
import base64
from typing import Optional


def generate_totp(secret_base32: str, time_step: int = 30, digits: int = 6,
                  algo: str = "SHA1", for_time: Optional[int] = None) -> str:
    """
    Generate a TOTP code according to RFC 6238.
    """
    if algo.upper() == "SHA1":
        digestmod = hashlib.sha1
    elif algo.upper() == "SHA256":
        digestmod = hashlib.sha256
    elif algo.upper() == "SHA512":
        digestmod = hashlib.sha512
    else:
        raise ValueError("Unsupported algorithm")

    # Decode the Base32 secret
    key = base64.b32decode(secret_base32.upper(), casefold=True)

    # Determine the time counter
    if for_time is None:
        for_time = int(time.time())

    counter = int(for_time // time_step)

    # Create counter in big-endian 8-byte format
    counter_bytes = counter.to_bytes(8, "big")

    # HMAC calculation
    hmac_hash = hmac.new(key, counter_bytes, digestmod).digest()

    # Dynamic truncation
    offset = hmac_hash[-1] & 0x0F
    code_int = (
        ((hmac_hash[offset] & 0x7f) << 24) |
        ((hmac_hash[offset+1] & 0xff) << 16) |
        ((hmac_hash[offset+2] & 0xff) << 8) |
        (hmac_hash[offset+3] & 0xff)
    )

    # Compute final code
    code = code_int % (10 ** digits)
    return str(code).zfill(digits)
