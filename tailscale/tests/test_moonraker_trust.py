"""Regression test for the Moonraker trusted-range include (files/cfg/moonraker/tailscale-trusted.cfg).

Proves the additive-trust claim without a device: Moonraker reads the base moonraker.conf and every
included file into ONE configparser in order (confighelper.py), and the bespok3d include is read
LAST, so a re-declared option wins while every other option in the section is preserved. This test
mimics that read order with a stock [authorization] base and the plugin's REAL shipped .cfg, then
asserts the merged result trusts the tailnet range, keeps every stock trusted range, and leaves
cors_domains intact. It would fail if a future edit dropped a stock range from the shipped file or if
the include stopped covering 100.64.0.0/10.

Run: python3 tests/test_moonraker_trust.py
"""
import configparser
from pathlib import Path

# The U1 stock [authorization] block (RFC private/CGNAT ranges and the stock CORS list, no real LAN
# addresses or secrets), standing in for the base moonraker.conf the include merges on top of.
STOCK_BASE = """\
[authorization]
trusted_clients:
    172.18.0.0/16
    10.0.0.0/8
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.0.0.0/8
    FE80::/10
    ::1/128
cors_domains:
    *.lan
    *.local
    *://localhost
    *://localhost:*
    *://my.mainsail.xyz
    *://app.fluidd.xyz
"""

STOCK_TRUSTED = {
    "172.18.0.0/16", "10.0.0.0/8", "127.0.0.0/8", "169.254.0.0/16",
    "172.16.0.0/12", "192.0.0.0/8", "FE80::/10", "::1/128",
}
STOCK_CORS = {
    "*.lan", "*.local", "*://localhost", "*://localhost:*",
    "*://my.mainsail.xyz", "*://app.fluidd.xyz",
}
TAILNET_RANGE = "100.64.0.0/10"


def as_set(multiline_value: str) -> set[str]:
    return {line.strip() for line in multiline_value.splitlines() if line.strip()}


def main() -> None:
    include_file = Path(__file__).resolve().parent.parent / "files/cfg/moonraker/tailscale-trusted.cfg"
    merged = configparser.ConfigParser(interpolation=None)
    # Same read order as Moonraker: base first, the bespok3d include last (last-wins per option).
    merged.read_string(STOCK_BASE)
    merged.read_string(include_file.read_text())

    trusted = as_set(merged["authorization"]["trusted_clients"])
    cors = as_set(merged["authorization"]["cors_domains"])

    assert TAILNET_RANGE in trusted, f"tailnet range {TAILNET_RANGE} not trusted after merge"
    missing_trusted = STOCK_TRUSTED - trusted
    assert not missing_trusted, f"include dropped stock trusted ranges: {sorted(missing_trusted)}"
    missing_cors = STOCK_CORS - cors
    assert not missing_cors, f"include lost stock cors_domains: {sorted(missing_cors)}"

    print("moonraker trusted-range include test passed.")


if __name__ == "__main__":
    main()
