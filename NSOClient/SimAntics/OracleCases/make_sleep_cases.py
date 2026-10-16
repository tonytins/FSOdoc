"""Writes Sleep (opcode 0) requests for `fso-oracle run-primitive`, one JSON line each.

The output is deterministic, so it isn't committed; `NSOClient/scripts/oracle-fixtures.sh`
writes it beside the 2017 answers.

    python3 -I NSOClient/SimAntics/OracleCases/make_sleep_cases.py OUTPUT
"""

import json
import pathlib
import struct
import sys


def operand(argument):
    return struct.pack("<h", argument).hex()


def cases():
    for idle_start in (0, 7, 10, 15):  # before, at, and after the current tick (10), or none
        for value in (-32768, -2, -1, 0, 1, 2, 5, 32767):
            for interrupt in (False, True):
                for slot in (0, 3):
                    args = [0, 0, 0, 0]
                    args[slot] = value
                    yield f"sleep-{idle_start}-{value}-{interrupt}-{slot}", {
                        "operand": operand(slot), "args": args, "currentTick": 10,
                        "idleStart": idle_start, "interrupt": interrupt}
    for slot, args in ((-1, [0, 0, 0, 0]), (4, [0, 0, 0, 0]), (5, [0, 0, 0, 0, 0, 3]), (0, [])):
        yield f"sleep-slot-{slot}-{len(args)}", {"operand": operand(slot), "args": args, "currentTick": 10,
                                               "idleStart": 0, "interrupt": False}
    for current, idle_start, value in ((1, 0, 0), (5, 3, 1), (4_000_000_000, 3_999_999_990, 20)):
        yield f"sleep-tick-{current}-{idle_start}-{value}", {
            "operand": operand(0), "args": [value, 0, 0, 0], "currentTick": current,
            "idleStart": idle_start, "interrupt": False}


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = pathlib.Path(sys.argv[1])
    lines = [json.dumps({"id": case_id, "opcode": 0, **request}, separators=(",", ":")) for case_id, request in cases()]
    assert len(set(json.loads(line)["id"] for line in lines)) == len(lines), "case IDs must be unique"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(lines)} cases written to {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
