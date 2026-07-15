#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
silverc="${SILVERC:-silverc}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

python3 - "$tmp_dir" <<'PY'
import json
import pathlib
import sys

target = pathlib.Path(sys.argv[1])

def integer(value):
    return {"kind": "int", "data": value}

def byte_array(length):
    return {
        "kind": "array",
        "data": [
            {"kind": "byte", "data": (index % 250) + 1}
            for index in range(length)
        ],
    }

fixtures = {
    "lp-amm.json": [
        integer(1), integer(1000), integer(100), integer(0), integer(0),
        byte_array(32), byte_array(36), integer(1), integer(1),
        byte_array(32), byte_array(1), byte_array(1),
    ],
    "escrow-buy.json": [
        byte_array(32), byte_array(32), integer(1000), integer(100),
        byte_array(32), byte_array(36), integer(1), integer(1),
        byte_array(32), byte_array(1), byte_array(1),
    ],
    "escrow-sell.json": [
        byte_array(32), byte_array(36), integer(1000), byte_array(32),
        byte_array(36), integer(1), integer(1), byte_array(32),
        byte_array(1), byte_array(1),
    ],
}

for name, value in fixtures.items():
    (target / name).write_text(json.dumps(value), encoding="utf-8")
PY

"$silverc" "$root_dir/LP_AMM.sil" \
    --constructor-args "$tmp_dir/lp-amm.json" \
    -o "$tmp_dir/lp-amm-artifact.json"

"$silverc" "$root_dir/Escrow_buy_token.sil" \
    --constructor-args "$tmp_dir/escrow-buy.json" \
    -o "$tmp_dir/escrow-buy-artifact.json"

"$silverc" "$root_dir/Escrow_sell_token.sil" \
    --constructor-args "$tmp_dir/escrow-sell.json" \
    -o "$tmp_dir/escrow-sell-artifact.json"

test -s "$tmp_dir/lp-amm-artifact.json"
test -s "$tmp_dir/escrow-buy-artifact.json"
test -s "$tmp_dir/escrow-sell-artifact.json"
