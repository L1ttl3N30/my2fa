import base64

def validate_base32_secret(s: str) -> bool:
    """
    Validate that a TOTP secret is proper Base32.
    Rejects strings with invalid characters.
    """
    try:
        base64.b32decode(s.upper(), casefold=True)
        return True
    except Exception:
        return False
