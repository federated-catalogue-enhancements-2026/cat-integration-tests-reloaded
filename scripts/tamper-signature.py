#!/usr/bin/env python3
"""
Deterministically corrupt the JWS signature of a compact JWT fixture, in place.

Used to (re)generate negative fixtures like fixtures/vc20/invalid/bad-signature.vc2.jwt:
sign the fixture normally with generate-jwt-fixture.py (so header and payload are
correct and reproducible), then tamper only the signature segment so the fixture
still fails Ed25519 verification against the published did:web key — while the
protected header (kid, typ, cty, iss) and payload stay exactly as signed.

Usage:
  python3 scripts/generate-jwt-fixture.py --key keys/jwt-signing.pem \\
      --payload fixtures/vc20/invalid/bad-signature.vc2.jsonld \\
      --typ vc+jwt --cty vc \\
      --out fixtures/vc20/invalid/bad-signature.vc2.jwt
  python3 scripts/tamper-signature.py fixtures/vc20/invalid/bad-signature.vc2.jwt
"""

import sys
from pathlib import Path

JWT_SEGMENT_COUNT = 3
SIGNATURE_SEGMENT_INDEX = 2

# Any two distinct characters from the base64url alphabet suffice; the fixture
# only needs *a* wrong signature, not any particular one.
TAMPER_CHAR_PRIMARY = "A"
TAMPER_CHAR_FALLBACK = "B"


def tamper_last_char(segment: str) -> str:
    """Flip the last character of a base64url segment to a different valid one."""
    replacement = TAMPER_CHAR_PRIMARY if segment[-1] != TAMPER_CHAR_PRIMARY else TAMPER_CHAR_FALLBACK
    return segment[:-1] + replacement


def main() -> None:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path-to-compact-jwt>", file=sys.stderr)
        sys.exit(1)

    jwt_path = Path(sys.argv[1])
    compact_jwt = jwt_path.read_text().strip()
    segments = compact_jwt.split(".")
    if len(segments) != JWT_SEGMENT_COUNT:
        print(f"Error: {jwt_path} is not a 3-segment compact JWT", file=sys.stderr)
        sys.exit(1)

    segments[SIGNATURE_SEGMENT_INDEX] = tamper_last_char(segments[SIGNATURE_SEGMENT_INDEX])
    jwt_path.write_text(".".join(segments))
    print(f"Tampered signature in place: {jwt_path}")


if __name__ == "__main__":
    main()
