"""Writes Set To Next (opcode 31) requests for `fso-oracle run-primitive`, one JSON line each.

The GUID of the lot's object 2 comes from ORACLE_GUIDS ("caller,stack" in hex); see
`NSOClient/scripts/oracle-fixtures.sh`.

    ORACLE_GUIDS=534564d5,6271eff3 python3 -I NSOClient/SimAntics/OracleCases/make_set_to_next_cases.py OUTPUT
"""

import json
import os
import pathlib
import struct
import sys

TEMPS, STACK_OBJECT_ID = 8, 10


def operand(guid, flags, scope, local, data):
    return struct.pack("<IBBBB", guid, flags, scope, local, data).hex()


def cases(stack_guid):
    searches = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 20]
    for search in searches:
        for start in (-1, 0, 1, 2, 5, 11, 12, 99):
            for guid_label, guid in (("stack", stack_guid), ("none", 0x12345678)):
                if search != 4 and guid_label == "none":
                    continue
                for category in (0, 2, 5) if search == 6 else (0,):
                    yield f"set-to-next-{search}-{start}-{guid_label}-{category}", {
                        "operand": operand(guid, 0x80 | search, TEMPS, 0, 3),
                        "temps": [0, 0, 0, start], "args": [category, 0, 0, 0]}
    # Without the top flag bit, the stored target is ignored for the stack object ID.
    for start in (0, 2, 12):
        yield f"set-to-next-flagless-{start}", {"operand": operand(0, 0, TEMPS, 0, 3), "temps": [0, 0, 0, 9],
                                                **({"stackObject": start} if start else {})}
    yield "set-to-next-bad-temp", {"operand": operand(0, 0x80, TEMPS, 0, 25)}
    yield "set-to-next-into-stack-object", {"operand": operand(0, 0x80, STACK_OBJECT_ID, 0, 0), "stackObject": 2}


def main():
    if len(sys.argv) != 2 or "ORACLE_GUIDS" not in os.environ:
        print(__doc__, file=sys.stderr)
        return 2
    stack_guid = int(os.environ["ORACLE_GUIDS"].split(",")[1], 16)
    path = pathlib.Path(sys.argv[1])
    lines = [json.dumps({"id": case_id, "opcode": 31, **request}, separators=(",", ":")) for case_id, request in cases(stack_guid)]
    assert len(set(json.loads(line)["id"] for line in lines)) == len(lines), "case IDs must be unique"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(lines)} cases written to {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
