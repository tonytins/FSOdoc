"""Writes Refresh (opcode 7) requests for `fso-oracle run-primitive`, one JSON line each.

    python3 -I NSOClient/SimAntics/OracleCases/make_refresh_cases.py OUTPUT
"""

import json
import pathlib
import struct
import sys


def cases():
    for target in (-1, 0, 1, 2):
        for refresh_type in (-1, 0, 1, 2, 3):
            for stack_object in (False, True):
                yield f"refresh-{target}-{refresh_type}-{stack_object}", {
                    "operand": struct.pack("<hh", target, refresh_type).hex(),
                    **({"stackObject": 2} if stack_object else {})}


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = pathlib.Path(sys.argv[1])
    lines = [json.dumps({"id": case_id, "opcode": 7, **request}, separators=(",", ":")) for case_id, request in cases()]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(lines)} cases written to {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
