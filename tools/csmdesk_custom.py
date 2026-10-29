"""CSMDESK custom client tooling.

CSMDESK replaces RustDesk's embedded custom-client public key with its own, so a
`signed` custom.txt can only be produced by the CSMDESK team. That is what keeps a
distributed client pinned to the CSMDESK server: users cannot repoint it.

Usage:
    python tools/csmdesk_custom.py keygen --out ../secrets
    python tools/csmdesk_custom.py pubkey --key ../secrets/csmdesk_signing.key
    python tools/csmdesk_custom.py sign --key ../secrets/csmdesk_signing.key \
        --config deploy/custom-client.json --out custom.txt

`custom.txt` sits next to csmdesk.exe and is read at startup by
`load_custom_client()` in src/common.rs.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path

from nacl.signing import SigningKey

KEY_NAME = "csmdesk_signing.key"


def b64(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def cmd_keygen(args: argparse.Namespace) -> None:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    key_path = out / KEY_NAME
    if key_path.exists() and not args.force:
        raise SystemExit(f"{key_path} already exists; use --force to overwrite")
    sk = SigningKey.generate()
    # Raw 32-byte seed, base64: keep this file secret and out of version control.
    key_path.write_text(b64(bytes(sk)) + "\n", encoding="ascii")
    pub_path = out / "csmdesk_signing.pub"
    pub_path.write_text(b64(bytes(sk.verify_key)) + "\n", encoding="ascii")
    print(f"secret key: {key_path}")
    print(f"public key: {pub_path}")
    print("compile this public key into src/common.rs (const KEY in read_custom_client)")


def _load_key(path: str) -> SigningKey:
    raw = base64.b64decode(Path(path).read_text(encoding="ascii").strip())
    if len(raw) != 32:
        raise SystemExit("expected a 32-byte ed25519 seed")
    return SigningKey(raw)


def cmd_pubkey(args: argparse.Namespace) -> None:
    print(b64(bytes(_load_key(args.key).verify_key)))


def cmd_sign(args: argparse.Namespace) -> None:
    payload = Path(args.config).read_bytes()
    # Validate early: a broken JSON file must not be signed silently.
    json.loads(payload)
    sk = _load_key(args.key)
    signed = sk.sign(payload).signature + payload
    Path(args.out).write_text(b64(signed), encoding="ascii")
    print(f"wrote {args.out} ({len(signed)} bytes signed)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("keygen")
    p.add_argument("--out", default="../secrets")
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=cmd_keygen)

    p = sub.add_parser("pubkey")
    p.add_argument("--key", required=True)
    p.set_defaults(func=cmd_pubkey)

    p = sub.add_parser("sign")
    p.add_argument("--key", required=True)
    p.add_argument("--config", required=True)
    p.add_argument("--out", default="custom.txt")
    p.set_defaults(func=cmd_sign)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
