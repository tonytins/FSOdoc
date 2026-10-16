"""Writes Test Object Type (opcode 32) requests for `fso-oracle run-primitive`, one JSON line each.

The GUIDs of the lot's objects 1 (the caller) and 2 come from ORACLE_GUIDS ("caller,stack" in
hex), which `NSOClient/scripts/oracle-fixtures.sh` reads from the oracle first.

    ORACLE_GUIDS=534564d5,6271eff3 python3 -I NSOClient/SimAntics/OracleCases/make_test_object_type_cases.py OUTPUT
"""

import json
import os
import pathlib
import struct
import sys

LITERAL, TEMPS, STACK_OBJECT_ID, MY_OBJECT = 7, 8, 10, 3


def operand(guid, scope, data):
    return struct.pack("<IhB", guid, data, scope).hex()


def cases(caller_guid, stack_guid):
    # Where the object ID comes from, and the request state that makes it work.
    sources = [
        ("literal-1", LITERAL, 1, {}),
        ("literal-2", LITERAL, 2, {"stackObject": 2}),
        ("literal-99", LITERAL, 99, {}),
        ("literal-0", LITERAL, 0, {}),
        ("literal-minus1", LITERAL, -1, {}),
        ("temp-1", TEMPS, 0, {"temps": [1]}),
        ("temp-2", TEMPS, 3, {"temps": [0, 0, 0, 2], "stackObject": 2}),
        ("stack-object", STACK_OBJECT_ID, 0, {"stackObject": 2}),
        ("no-stack-object", STACK_OBJECT_ID, 0, {}),
        ("my-object-id", MY_OBJECT, 11, {}),
        ("bad-temp", TEMPS, 20, {}),
        ("unknown-scope", 39, 0, {}),
    ]
    for name, scope, data, state in sources:
        for label, guid in (("caller", caller_guid), ("stack", stack_guid), ("zero", 0), ("all", 0xFFFFFFFF)):
            yield f"test-object-type-{name}-{label}", {"operand": operand(guid, scope, data), **state}


def main():
    if len(sys.argv) != 2 or "ORACLE_GUIDS" not in os.environ:
        print(__doc__, file=sys.stderr)
        return 2
    caller_guid, stack_guid = (int(value, 16) for value in os.environ["ORACLE_GUIDS"].split(","))
    path = pathlib.Path(sys.argv[1])
    lines = [json.dumps({"id": case_id, "opcode": 32, **request}, separators=(",", ":"))
             for case_id, request in cases(caller_guid, stack_guid)]
    assert len(set(json.loads(line)["id"] for line in lines)) == len(lines), "case IDs must be unique"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(lines)} cases written to {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
