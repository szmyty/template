"""
CLI Entry Point
"""
import click

@click.group()
@click.version_option(package_name="cli")
def cli():
    """CLI Tool - A description of your CLI's purpose goes here."""
    pass

# Example stub commands
@cli.command()
@click.option("--name", default="World", help="Name to greet.")
def greet(name):
    """Say hello to someone."""
    click.echo(f"Hello, {name}!")

@cli.command()
@click.argument("path", type=click.Path(exists=True))
def show(path):
    """Show contents of a file."""
    with open(path, "r", encoding="utf-8") as f:
        click.echo(f.read())
