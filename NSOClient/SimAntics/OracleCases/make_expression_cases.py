"""Writes Expression (opcode 2) requests for `fso-oracle run-primitive`, one JSON line each.

The output is deterministic, so it isn't committed; `NSOClient/scripts/oracle-fixtures.sh`
writes it beside the 2017 answers. Every value a case reads is set by the request, so the Swift tests can build the
same state on fresh entities. Direction (object data 1) and the lockout count (25) aren't
read, because 2017 computes them from state outside object data.

    python3 -I NSOClient/SimAntics/OracleCases/make_expression_cases.py OUTPUT
"""

import json
import pathlib
import struct
import sys

CALLER, STACK_OBJECT = 1, 2
ASSIGN, PUSH, POP = 5, 18, 19
TEMPS, TEMP_XL, LITERAL, MY_LIST, STACK_LIST, TUNING = 8, 42, 7, 46, 47, 26


def operand(operator, lhs_scope, lhs_data, rhs_scope, rhs_data):
    return struct.pack("<hhBBBB", lhs_data, rhs_data, 0, operator, lhs_scope, rhs_scope).hex()


def preset(stack_object):
    """State every read can rely on: distinct, recognizable values."""
    data = {str(i): 1000 + i for i in range(80) if i not in (1, 25)}
    # Every attribute index a case can reach (operand data, temps, and arguments as indexes), since
    # the 2017 lot's objects may already have values there and fresh Swift entities don't.
    reachable = list(range(21)) + [80, 600]
    objects = {str(CALLER): {"data": data, "attributes": {str(i): 300 + i for i in reachable}, "list": [4, 5, 6]}}
    if stack_object:
        objects[str(STACK_OBJECT)] = {"data": {k: v + 1000 for k, v in data.items()},
                                     "attributes": {str(i): 400 + i for i in reachable}, "list": [7, 8]}
    return {
        "temps": [(i * 7 + 3) % 20 for i in range(20)],
        "tempXL": [70000, -5],
        "locals": [5, 6, 7],
        "args": [9, 1, 2, 3],
        "globals": {str(i): 100 + i for i in range(38)},
        "objects": objects,
        "stackObject": STACK_OBJECT if stack_object else 0,
    }


def cases():
    values = [0, 1, -1, 3, -7, 17, 32767, -32768]
    for operator in range(18):  # every operator but push and pop, on temps
        for left in values:
            for right in values:
                yield f"temps-{operator}-{left}-{right}", {
                    "operand": operand(operator, TEMPS, 0, LITERAL, right), "temps": [left]}

    for operator in (3, 4, 5, 6, 7, 11, 12, 13, 17):  # 32-bit values in TempXL
        for left in (-2**31, 2**31 - 1, 70000, -70000, 0):
            for right in (-1, 0, 2, 1000):
                yield f"tempxl-{operator}-{left}-{right}", {
                    "operand": operand(operator, TEMP_XL, 0, LITERAL, right), "tempXL": [left]}
            yield f"tempxl-{operator}-{left}-xl", {
                "operand": operand(operator, TEMP_XL, 0, TEMP_XL, 1), "tempXL": [left, -3]}

    for operator in (8, 9, 10):  # flags, including shifts past 31 and 16-bit masks
        for bit in (-1, 0, 1, 2, 16, 17, 32, 33):
            yield f"flag-{operator}-{bit}-temp", {"operand": operand(operator, TEMPS, 0, LITERAL, bit), "temps": [5]}
            yield f"flag-{operator}-{bit}-xl", {"operand": operand(operator, TEMP_XL, 0, LITERAL, bit),
                                                "tempXL": [0x10001]}

    for scope in range(60):  # every scope byte, read and written
        for data in (0, 3, 19, 20, -1, 80, 600):
            for stack_object in (False, True):
                suffix = f"{scope}-{data}-{'stack' if stack_object else 'nostack'}"
                yield f"read-{suffix}", {**preset(stack_object), "operand": operand(ASSIGN, TEMPS, 0, scope, data)}
                yield f"write-{suffix}", {**preset(stack_object), "operand": operand(ASSIGN, scope, data, LITERAL, 42)}

    for caller in (CALLER, STACK_OBJECT):  # the objects' own, semi-global, and global tuning
        for table in (0, 1, 2, 3, 5, 63, 64, 65, 66, 70, 127, 128, 129, 130, 131, 140, 191, 192, 300, 511):
            for key in (0, 1, 2, 5, 10, 127):
                yield f"tuning-{caller}-{table}-{key}", {
                    "operand": operand(ASSIGN, TEMPS, 0, TUNING, (table << 7 | key) - (65536 if table >= 256 else 0)),
                    "caller": caller}

    for scope in (MY_LIST, STACK_LIST):  # lists
        for stack_object in (False, True):
            state = preset(stack_object)
            for position in (0, 1, 2, 7):
                yield f"push-{scope}-{position}-{stack_object}", {
                    **state, "operand": operand(PUSH, scope, position, LITERAL, 9)}
                yield f"pop-{scope}-{position}-{stack_object}", {
                    **state, "operand": operand(POP, TEMPS, 1, scope, position)}
            empty = {**state, "objects": {key: {**value, "list": []} for key, value in state["objects"].items()}}
            yield f"pop-empty-{scope}-{stack_object}", {**empty, "operand": operand(POP, TEMPS, 1, scope, 0)}

    for scope, stack in ((21, True), (53, True), (21, False)):  # object definition fields
        for field in list(range(-1, 99)) + [600]:
            yield f"definition-{scope}-{field}-{stack}", {**preset(stack), "operand": operand(ASSIGN, TEMPS, 0, scope, field)}
    for clock in ({"hours": 13, "minutes": 47, "minuteFractions": 75}, {"hours": 0, "minutes": 0, "minuteFractions": 149},
                  {"hours": 23, "minutes": 59, "minuteFractions": 1}):
        for scope in (43, 45):
            for data in range(-1, 6):
                yield f"clock-{scope}-{data}-{clock['hours']}-{clock['minuteFractions']}", {
                    "operand": operand(ASSIGN, TEMPS, 0, scope, data), "clock": clock}

    for step in (0, 1, 2, 4):  # direction writes snap to the rotation step (object data 23)
        for value in (-9, -1, 0, 3, 7, 9, 13):
            yield f"direction-{step}-{value}", {
                "operand": operand(ASSIGN, 3, 1, LITERAL, value),
                "objects": {str(CALLER): {"data": {"23": step}, "direction": 2}}}

    for operator in (20, 255):
        yield f"unknown-operator-{operator}", {"operand": operand(operator, TEMPS, 0, LITERAL, 1)}
    yield "upstairs-room-test", {**preset(False), "operand": operand(14, 3, 29, LITERAL, 1024)}
    for target in (0, 2, 99):
        yield f"stack-object-id-{target}", {"operand": operand(ASSIGN, 10, 0, LITERAL, target)}


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = pathlib.Path(sys.argv[1])
    lines = [json.dumps({"id": case_id, "opcode": 2, **request}, separators=(",", ":"))
             for case_id, request in cases()]
    assert len(set(json.loads(line)["id"] for line in lines)) == len(lines), "case IDs must be unique"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(lines)} cases written to {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
