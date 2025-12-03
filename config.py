import os
from pathlib import Path

# Default directory for secrets storage (~/.my2fa)
APP_DIR = Path(os.path.expanduser("~/.my2fa"))
SECRETS_FILE = APP_DIR / "secrets.json.gpg"
