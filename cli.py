import click
import time

from .storage import SecretsStore, Account
from .utils import validate_base32_secret
from .totp import generate_totp
from .config import SECRETS_FILE
from shutil import copyfile


@click.group()
def cli():
    """My Own GPG-Backed TOTP 2FA App"""


@cli.command()
@click.option("--gpg-recipient", multiple=True, required=True,
              help="GPG key ID to encrypt secrets")
def init(gpg_recipient):
    """
    Initialize secrets store.
    """
    store = SecretsStore()
    model = store.load()

    model.gpg_recipients = list(gpg_recipient)
    model.accounts = []
    store.save(model)

    click.echo(f"Initialized secrets storage at: {SECRETS_FILE}")


@cli.command()
@click.argument("name")
def add(name):
    """Add a new TOTP account."""
    store = SecretsStore()
    model = store.load()

    issuer = click.prompt("Issuer (optional)", default="", show_default=False)
    secret = click.prompt("TOTP Base32 Secret", hide_input=True)

    if not validate_base32_secret(secret):
        click.echo("Invalid Base32 secret. Aborting.")
        return

    digits = click.prompt("Digits (6 or 8)", default=6, type=int)
    period = click.prompt("Period (seconds)", default=30, type=int)
    algo = click.prompt("Algorithm (SHA1/SHA256/SHA512)", default="SHA1")

    acct = Account(
        name=name,
        issuer=issuer if issuer else None,
        secret_base32=secret.strip(),
        digits=digits,
        period=period,
        algo=algo
    )

    model.accounts.append(acct)
    store.save(model)
    click.echo(f"Added account: {name}")


@cli.command()
def list():
    """List accounts."""
    store = SecretsStore()
    model = store.load()

    if not model.accounts:
        click.echo("No accounts stored.")
        return

    click.echo(f"{'Name':20} {'Issuer':20} {'Digits':6} {'Period':6} {'Algo':6}")
    click.echo("-" * 70)

    for a in model.accounts:
        click.echo(f"{a.name:20} {str(a.issuer or ''):20} {a.digits:<6} {a.period:<6} {a.algo:<6}")


@cli.command()
@click.argument("name", required=False)
@click.option("--all", "show_all", is_flag=True, help="Show TOTP codes for all accounts")
def code(name, show_all):
    """Generate TOTP code(s)."""
    store = SecretsStore()
    model = store.load()

    now = int(time.time())

    if show_all:
        for a in model.accounts:
            code = generate_totp(a.secret_base32, a.period, a.digits, a.algo, now)
            valid = a.period - (now % a.period)
            click.echo(f"{a.name}: {code}  (valid {valid}s)")
        return

    if not name:
        click.echo("Specify account name or use --all")
        return

    for a in model.accounts:
        if a.name == name:
            code = generate_totp(a.secret_base32, a.period, a.digits, a.algo, now)
            valid = a.period - (now % a.period)
            click.echo(f"{a.name}: {code}  (valid {valid}s)")
            return

    click.echo("Account not found.")


@cli.command()
@click.argument("name")
def remove(name):
    """Remove an account."""
    store = SecretsStore()
    model = store.load()

    for a in model.accounts:
        if a.name == name:
            if not click.confirm(f"Delete account '{name}'?"):
                return
            model.accounts.remove(a)
            store.save(model)
            click.echo("Removed.")
            return

    click.echo("Account not found.")


@cli.command()
@click.option("--output", required=True)
def backup(output):
    """Backup encrypted secrets file as-is."""
    copyfile(SECRETS_FILE, output)
    click.echo(f"Backup created: {output}")
