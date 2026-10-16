"""Writes Random Number (opcode 8) requests for `fso-oracle run-primitive`, one JSON line each.

    python3 -I NSOClient/SimAntics/OracleCases/make_random_number_cases.py OUTPUT
"""

import json
import pathlib
import struct
import sys

LITERAL, TEMPS, LOCAL, TEMP_XL, MY_OBJECT = 7, 8, 25, 42, 3


def operand(destination_scope, destination_data, range_scope, range_data):
    return struct.pack("<hHhH", destination_data, destination_scope, range_data, range_scope).hex()


def cases():
    seeds = ["0f50d0c5eed00001", "1", "ffffffffffffffff", "123456789abcdef0"]
    for seed in seeds:
        for value in (0, 1, 2, 7, 100, 32767, -1, -32768):
            yield f"random-literal-{seed}-{value}", {
                "operand": operand(TEMPS, 0, LITERAL, value), "seed": seed}
            yield f"random-temp-{seed}-{value}", {
                "operand": operand(TEMPS, 1, TEMPS, 4), "seed": seed, "temps": [0, 0, 0, 0, value]}
    destinations = [("local", LOCAL, 1, {"locals": [0, 0]}), ("object-data", MY_OBJECT, 5, {}),
                    ("literal", LITERAL, 0, {}), ("tempxl", TEMP_XL, 0, {}), ("bad-local", LOCAL, 9, {}),
                    ("wide-scope", 0x0108, 0, {})]
    for name, scope, data, state in destinations:
        yield f"random-destination-{name}", {"operand": operand(scope, data, LITERAL, 50), **state}
    yield "random-wide-range-scope", {"operand": operand(TEMPS, 0, 0x0107, 50)}


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = pathlib.Path(sys.argv[1])
    lines = [json.dumps({"id": case_id, "opcode": 8, **request}, separators=(",", ":")) for case_id, request in cases()]
    assert len(set(json.loads(line)["id"] for line in lines)) == len(lines), "case IDs must be unique"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(lines)} cases written to {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
