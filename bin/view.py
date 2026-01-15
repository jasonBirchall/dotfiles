#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "typer",
#     "requests",
#     "toml",
#     "rich",
# ]
# ///

import typer
import base64
import requests
from pathlib import Path
import toml
from rich import print

app = typer.Typer()
WAKA_API = "https://wakatime.com/api/v1/"
CONFIG_FILE = Path.home() / ".config" / "wakatime-view" / "wakatime-view.toml"


@app.command()
def today():
    ENDPOINT = "users/current/status_bar/today"
    api_key: str | None = None
    if is_config():
        api_key = get_api_key()
    else:
        api_key = typer.prompt("Enter your API key: ")
    if not api_key:
        typer.echo("No API key found. Exiting...")
        raise typer.Exit()

    base64_bytes = base64.b64encode(api_key.encode("ascii"))
    base64_api_key = base64_bytes.decode("ascii")
    authorization = f"Basic {base64_api_key}"
    headers = {"Authorization": authorization}
    req = requests.get(WAKA_API + ENDPOINT, headers=headers)

    if req.status_code == 200:
        response = req.json()
        print(f"{response['data']['grand_total']['text']}")
    else:
        print("Error", req)


@app.command()
def setup():
    key = typer.prompt("Enter your API key")
    if not Path(CONFIG_FILE.parent).is_dir():
        Path(CONFIG_FILE.parent).mkdir(parents=True)
    if not Path(CONFIG_FILE).is_file():
        config = {
            "wakatime": {
                "api_key": f"{key}",
            }
        }
        with open(CONFIG_FILE, "w") as f:
            toml.dump(config, f)
    else:
        typer.echo("Config file already exists. Exiting...")
        raise typer.Exit()
    typer.echo("Config file created. Please edit the file and add your API key.")


def is_config() -> bool:
    if Path(CONFIG_FILE).is_file():
        return True
    return False


def get_api_key() -> str | None:
    config = toml.load(CONFIG_FILE)
    if config["wakatime"]["api_key"]:
        return config["wakatime"]["api_key"]
    else:
        return None


if __name__ == "__main__":
    app()
