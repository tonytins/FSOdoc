"""Writes `fso-oracle run-primitive` requests for a ported primitive, one JSON line each.

The output is deterministic, so it isn't committed; `NSOClient/scripts/oracle-fixtures.sh`
writes it beside FreeSO's answers. Cases that name real objects take the GUIDs of the lot's
objects 1 and 2 from ORACLE_GUIDS (every lot object's GUID in hex, in object ID order: the caller,
then the stack object, then the rest) and its multi-tile masters from ORACLE_MASTERS, which the fixture
script reads from
the oracle. Every value a case reads is set by the request, so the Swift tests can build the
same state.

    ORACLE_GUIDS=534564d5,6271eff3,... ORACLE_MASTERS=39ccf441 python3 -I NSOClient/SimAntics/OracleCases/make_cases.py PRIMITIVE OUTPUT
"""

import json
import os
import pathlib
import struct
import sys

# Variable scopes and Expression operators, as FreeSO numbers them.
MY_OBJECT, LITERAL, TEMPS, STACK_OBJECT_ID, TUNING, LOCAL, TEMP_XL, MY_LIST, STACK_LIST = 3, 7, 8, 10, 26, 25, 42, 46, 47
ASSIGN, PUSH, POP = 5, 18, 19
# The oracle lot's caller and the object tests use as the stack object.
CALLER, STACK_OBJECT = 1, 2

# MARK: Expression

def expression_operand(operator, lhs_scope, lhs_data, rhs_scope, rhs_data):
    return struct.pack("<hhBBBB", lhs_data, rhs_data, 0, operator, lhs_scope, rhs_scope).hex()


def expression_preset(stack_object):
    """State every read can rely on: distinct, recognizable values."""
    data = {str(i): 1000 + i for i in range(80) if i not in (1, 25)}
    # Every attribute index a case can reach (operand data, temps, and arguments as indexes), since
    # the objects on FreeSO's lot may already have values there and fresh Swift entities don't.
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


def expression_cases():
    values = [0, 1, -1, 3, -7, 17, 32767, -32768]
    for operator in range(18):  # every operator but push and pop, on temps
        for left in values:
            for right in values:
                yield f"temps-{operator}-{left}-{right}", {
                    "operand": expression_operand(operator, TEMPS, 0, LITERAL, right), "temps": [left]}

    for operator in (3, 4, 5, 6, 7, 11, 12, 13, 17):  # 32-bit values in TempXL
        for left in (-2**31, 2**31 - 1, 70000, -70000, 0):
            for right in (-1, 0, 2, 1000):
                yield f"tempxl-{operator}-{left}-{right}", {
                    "operand": expression_operand(operator, TEMP_XL, 0, LITERAL, right), "tempXL": [left]}
            yield f"tempxl-{operator}-{left}-xl", {
                "operand": expression_operand(operator, TEMP_XL, 0, TEMP_XL, 1), "tempXL": [left, -3]}

    for operator in (8, 9, 10):  # flags, including shifts past 31 and 16-bit masks
        for bit in (-1, 0, 1, 2, 16, 17, 32, 33):
            yield f"flag-{operator}-{bit}-temp", {"operand": expression_operand(operator, TEMPS, 0, LITERAL, bit), "temps": [5]}
            yield f"flag-{operator}-{bit}-xl", {"operand": expression_operand(operator, TEMP_XL, 0, LITERAL, bit),
                                                "tempXL": [0x10001]}

    for scope in range(60):  # every scope byte, read and written
        for data in (0, 3, 19, 20, -1, 80, 600):
            for stack_object in (False, True):
                suffix = f"{scope}-{data}-{'stack' if stack_object else 'nostack'}"
                yield f"read-{suffix}", {**expression_preset(stack_object), "operand": expression_operand(ASSIGN, TEMPS, 0, scope, data)}
                yield f"write-{suffix}", {**expression_preset(stack_object), "operand": expression_operand(ASSIGN, scope, data, LITERAL, 42)}

    for caller in (CALLER, STACK_OBJECT):  # the objects' own, semi-global, and global tuning
        for table in (0, 1, 2, 3, 5, 63, 64, 65, 66, 70, 127, 128, 129, 130, 131, 140, 191, 192, 300, 511):
            for key in (0, 1, 2, 5, 10, 127):
                yield f"tuning-{caller}-{table}-{key}", {
                    "operand": expression_operand(ASSIGN, TEMPS, 0, TUNING, (table << 7 | key) - (65536 if table >= 256 else 0)),
                    "caller": caller}

    for scope in (MY_LIST, STACK_LIST):  # lists
        for stack_object in (False, True):
            state = expression_preset(stack_object)
            for position in (0, 1, 2, 7):
                yield f"push-{scope}-{position}-{stack_object}", {
                    **state, "operand": expression_operand(PUSH, scope, position, LITERAL, 9)}
                yield f"pop-{scope}-{position}-{stack_object}", {
                    **state, "operand": expression_operand(POP, TEMPS, 1, scope, position)}
            empty = {**state, "objects": {key: {**value, "list": []} for key, value in state["objects"].items()}}
            yield f"pop-empty-{scope}-{stack_object}", {**empty, "operand": expression_operand(POP, TEMPS, 1, scope, 0)}

    for scope, stack in ((21, True), (53, True), (21, False)):  # object definition fields
        for field in list(range(-1, 99)) + [600]:
            yield f"definition-{scope}-{field}-{stack}", {**expression_preset(stack), "operand": expression_operand(ASSIGN, TEMPS, 0, scope, field)}
    for clock in ({"hours": 13, "minutes": 47, "minuteFractions": 75}, {"hours": 0, "minutes": 0, "minuteFractions": 149},
                  {"hours": 23, "minutes": 59, "minuteFractions": 1}):
        for scope in (43, 45):
            for data in range(-1, 6):
                yield f"clock-{scope}-{data}-{clock['hours']}-{clock['minuteFractions']}", {
                    "operand": expression_operand(ASSIGN, TEMPS, 0, scope, data), "clock": clock}

    for room in (-5, 0, 1, 3, 5, 6, 100):  # room data: temp 0 picks the room, clamped to the lot's rooms
        for data in range(-1, 6):
            yield f"room-{room}-{data}", {"operand": expression_operand(ASSIGN, TEMPS, 1, 23, data), "temps": [room]}

    for step in (0, 1, 2, 4):  # direction writes snap to the rotation step (object data 23)
        for value in (-9, -1, 0, 3, 7, 9, 13):
            yield f"direction-{step}-{value}", {
                "operand": expression_operand(ASSIGN, 3, 1, LITERAL, value),
                "objects": {str(CALLER): {"data": {"23": step}, "direction": 2}}}

    for operator in (20, 255):
        yield f"unknown-operator-{operator}", {"operand": expression_operand(operator, TEMPS, 0, LITERAL, 1)}
    yield "upstairs-room-test", {**expression_preset(False), "operand": expression_operand(14, 3, 29, LITERAL, 1024)}
    for target in (0, 2, 99):
        yield f"stack-object-id-{target}", {"operand": expression_operand(ASSIGN, 10, 0, LITERAL, target)}


# MARK: Sleep

def sleep_operand(argument):
    return struct.pack("<h", argument).hex()


def sleep_cases():
    for idle_start in (0, 7, 10, 15):  # before, at, and after the current tick (10), or none
        for value in (-32768, -2, -1, 0, 1, 2, 5, 32767):
            for interrupt in (False, True):
                for slot in (0, 3):
                    args = [0, 0, 0, 0]
                    args[slot] = value
                    yield f"sleep-{idle_start}-{value}-{interrupt}-{slot}", {
                        "operand": sleep_operand(slot), "args": args, "currentTick": 10,
                        "idleStart": idle_start, "interrupt": interrupt}
    for slot, args in ((-1, [0, 0, 0, 0]), (4, [0, 0, 0, 0]), (5, [0, 0, 0, 0, 0, 3]), (0, [])):
        yield f"sleep-slot-{slot}-{len(args)}", {"operand": sleep_operand(slot), "args": args, "currentTick": 10,
                                               "idleStart": 0, "interrupt": False}
    for current, idle_start, value in ((1, 0, 0), (5, 3, 1), (4_000_000_000, 3_999_999_990, 20)):
        yield f"sleep-tick-{current}-{idle_start}-{value}", {
            "operand": sleep_operand(0), "args": [value, 0, 0, 0], "currentTick": current,
            "idleStart": idle_start, "interrupt": False}


# MARK: Test Object Type

def test_object_type_operand(guid, scope, data):
    return struct.pack("<IhB", guid, data, scope).hex()


def test_object_type_cases(caller_guid, stack_guid):
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
            yield f"test-object-type-{name}-{label}", {"operand": test_object_type_operand(guid, scope, data), **state}


# MARK: Refresh

def refresh_cases():
    for target in (-1, 0, 1, 2):
        for refresh_type in (-1, 0, 1, 2, 3):
            for stack_object in (False, True):
                yield f"refresh-{target}-{refresh_type}-{stack_object}", {
                    "operand": struct.pack("<hh", target, refresh_type).hex(),
                    **({"stackObject": 2} if stack_object else {})}


# MARK: Set To Next

def set_to_next_operand(guid, flags, scope, local, data):
    return struct.pack("<IBBBB", guid, flags, scope, local, data).hex()


def set_to_next_cases(stack_guid):
    searches = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 20]
    for search in searches:
        for start in (-1, 0, 1, 2, 5, 11, 12, 99):
            for guid_label, guid in (("stack", stack_guid), ("none", 0x12345678)):
                if search != 4 and guid_label == "none":
                    continue
                for category in (0, 2, 5) if search == 6 else (0,):
                    yield f"set-to-next-{search}-{start}-{guid_label}-{category}", {
                        "operand": set_to_next_operand(guid, 0x80 | search, TEMPS, 0, 3),
                        "temps": [0, 0, 0, start], "args": [category, 0, 0, 0]}
    # Parts of a multi-tile object, from every object on the lot (the default lot has one).
    for start in range(1, 14):
        yield f"set-to-next-part-{start}", {"operand": set_to_next_operand(0, 0x80 | 3, TEMPS, 0, 3), "temps": [0, 0, 0, start]}
    # Objects next to the anchor in local 0, from every lot object and several starting points.
    for anchor in range(1, 14):
        for start in (0, 1, 2, 5, 9, 12):
            yield f"set-to-next-adjacent-{anchor}-{start}", {
                "operand": set_to_next_operand(0, 0x80 | 9, TEMPS, 0, 3), "temps": [0, 0, 0, start], "locals": [anchor]}
    yield "set-to-next-adjacent-bad-local", {"operand": set_to_next_operand(0, 0x80 | 9, TEMPS, 2, 3), "locals": [1]}
    # Without the top flag bit, the stored target is ignored for the stack object ID.
    for start in (0, 2, 12):
        yield f"set-to-next-flagless-{start}", {"operand": set_to_next_operand(0, 0, TEMPS, 0, 3), "temps": [0, 0, 0, 9],
                                                **({"stackObject": start} if start else {})}
    yield "set-to-next-bad-temp", {"operand": set_to_next_operand(0, 0x80, TEMPS, 0, 25)}
    yield "set-to-next-into-stack-object", {"operand": set_to_next_operand(0, 0x80, STACK_OBJECT_ID, 0, 0), "stackObject": 2}


# MARK: Random Number

def random_number_operand(destination_scope, destination_data, range_scope, range_data):
    return struct.pack("<hHhH", destination_data, destination_scope, range_data, range_scope).hex()


def random_number_cases():
    seeds = ["0f50d0c5eed00001", "1", "ffffffffffffffff", "123456789abcdef0"]
    for seed in seeds:
        for value in (0, 1, 2, 7, 100, 32767, -1, -32768):
            yield f"random-literal-{seed}-{value}", {
                "operand": random_number_operand(TEMPS, 0, LITERAL, value), "seed": seed}
            yield f"random-temp-{seed}-{value}", {
                "operand": random_number_operand(TEMPS, 1, TEMPS, 4), "seed": seed, "temps": [0, 0, 0, 0, value]}
    destinations = [("local", LOCAL, 1, {"locals": [0, 0]}), ("object-data", MY_OBJECT, 5, {}),
                    ("literal", LITERAL, 0, {}), ("tempxl", TEMP_XL, 0, {}), ("bad-local", LOCAL, 9, {}),
                    ("wide-scope", 0x0108, 0, {})]
    for name, scope, data, state in destinations:
        yield f"random-destination-{name}", {"operand": random_number_operand(scope, data, LITERAL, 50), **state}
    yield "random-wide-range-scope", {"operand": random_number_operand(TEMPS, 0, 0x0107, 50)}


# MARK: Play Sound

def play_sound_cases():
    for event in (0, 1, 300, 4096, 8192):
        for options in range(16):
            for stack_object in (False, True):
                yield f"play-sound-{event}-{options}-{stack_object}", {
                    "operand": struct.pack("<HHBB", event, 0, options, 50).hex(),
                    **({"stackObject": STACK_OBJECT} if stack_object else {})}

# MARK: Create Object Instance

def create_object_instance_cases(lot_guids, masters):
    caller_guid, stack_guid = lot_guids[0], lot_guids[1]
    # Every position mode (10 is invalid), with flags that change what main gets, the stack
    # object, and the locals and parameter some modes read. Objects out of the world stay there;
    # every other mode needs the new object placed.
    guids = [("caller", caller_guid), ("stack", stack_guid), ("missing", 0x12345678)]
    flag_sets = [0, 2, 16, 18, 4, 64, 128]  # pass IDs, temp 0, both, neighbor, callback, persist
    for position in range(11):
        for guid_name, guid in guids:
            for flags in flag_sets:
                for stack_object in (False, True):
                    yield f"create-{position}-{guid_name}-{flags}-{stack_object}", {
                        "operand": struct.pack("<IBBBB", guid, position, flags, 0, 0).hex(),
                        "temps": [7], "locals": [STACK_OBJECT, 0], "args": [STACK_OBJECT, 0, 0, 0],
                        **({"stackObject": STACK_OBJECT} if stack_object else {})}
    for local, value in ((0, 99), (1, 2), (1, 4), (1, 6), (1, 3), (5, 0)):  # missing objects, directions, a bad local
        for position in (8, 9):
            yield f"create-local-{position}-{local}-{value}", {
                "operand": struct.pack("<IBBBB", caller_guid, position, 0, local, 0).hex(),
                "locals": [value, value]}
    yield "create-param-missing", {"operand": struct.pack("<IBBBB", caller_guid, 7, 0, 0, 0).hex(), "args": [99, 0, 0, 0]}
    # Placing on the lot: next to, in front of, and under the lot's objects in the world (7 to 12),
    # with every object on the lot and its multi-tile masters as the new object.
    kinds = sorted(set(lot_guids) | set(masters))
    for anchor in range(7, 13):
        for guid in kinds:
            name = f"{anchor}-{guid:08x}"
            yield f"place-front-of-stack-{name}", {"operand": struct.pack("<IBBBB", guid, 3, 0, 0, 0).hex(), "stackObject": anchor}
            yield f"place-below-local-{name}", {"operand": struct.pack("<IBBBB", guid, 8, 0, 0, 0).hex(), "locals": [anchor]}
            yield f"place-below-param-{name}", {"operand": struct.pack("<IBBBB", guid, 7, 0, 0, 0).hex(), "args": [anchor, 0, 0, 0]}
            for position in (0, 1, 5):  # in front of, on top of, and under the caller
                yield f"place-{position}-caller-{name}", {"operand": struct.pack("<IBBBB", guid, position, 0, 0, 0).hex(),
                                                         "caller": anchor}
            for direction in (0, 2, 4, 6):  # next to the caller, north, east, south, west
                yield f"place-next-{direction}-{name}", {"operand": struct.pack("<IBBBB", guid, 9, 0, 0, 0).hex(),
                                                        "caller": anchor, "locals": [direction]}


# MARK: Find Location For

def find_location_for_cases():
    # Every mode (6 and 7 do nothing), the flags (4 is the buildable area), objects to place out of
    # the world (2, 3, 5) and on the lot (7 to 12), and references: the caller, or an object in local 0.
    for mode in range(8):
        for flags in (0, 2, 4):
            for target in (2, 3, 5, 7, 9, 10, 11, 12):
                for caller in (1, 7, 11, 12):
                    yield f"find-location-{mode}-{flags}-{target}-{caller}", {
                        "operand": struct.pack("<BBB", mode, 0, flags).hex(), "stackObject": target, "caller": caller}
                for reference in (7, 10, 12, 99):
                    yield f"find-location-local-{mode}-{flags}-{target}-{reference}", {
                        "operand": struct.pack("<BBB", mode, 0, flags | 1).hex(), "stackObject": target, "locals": [reference]}
    yield "find-location-bad-local", {"operand": struct.pack("<BBB", 0, 3, 1).hex(), "stackObject": 2, "locals": [7]}
    yield "find-location-no-stack-object", {"operand": struct.pack("<BBB", 0, 0, 0).hex()}


# MARK: Writing

# Each primitive's opcode, whether its cases name real objects, and its cases given
# (the lot's GUIDs in object ID order, its multi-tile masters' GUIDs).
# MARK: Run Tree By Name

def run_tree_by_name_cases(lot_guids):
    """Every destination, string, and table scope, from every object on the lot (the mock lamp names
    one of its routines in table 300), with no stack object, itself, and object 1 as the stack object."""
    for caller in range(1, min(len(lot_guids), 13) + 1):
        for stack_object in sorted({0, caller, 1}):
            for table in (128, 129, 300):
                for scope in (0, 1):
                    for string in (0, 1, 2, 3):
                        for destination in (0, 1, 2, 5):
                            operand = struct.pack("<HBBBB", table, scope, 0, string, destination).hex()
                            yield (f"caller{caller}-stack{stack_object}-table{table}-scope{scope}-string{string}-to{destination}",
                                   {"operand": operand, "caller": caller, "stackObject": stack_object,
                                    "temps": [4, 5, 6, 7, 8]})


# MARK: Notify Stack Object Out Of Idle

def notify_out_of_idle_cases(lot_guids):
    """No stack object, and each lot object as the stack object, from the first object and from
    itself (so the response shows its thread rescheduled and interrupted), at several ticks."""
    count = min(len(lot_guids), 13)
    for caller in (1, 2) if count > 1 else (1,):
        for stack_object in range(0, count + 1):
            for tick in (None, 0, 1, 7, 500):
                for interrupt in (False, True):
                    request = {"caller": caller, "stackObject": stack_object, "interrupt": interrupt, "operand": "ff" * 8}
                    if tick is not None:
                        request["currentTick"] = tick
                    yield f"caller{caller}-stack{stack_object}-tick{tick}-interrupt{interrupt}", request


# MARK: Get Distance To and Get Direction To

def between_objects(lot_guids):
    """Callers 1 and 2; each lot object (or none) as the stack object; each lot object, a missing
    one, and 0 as the other object, by literal; and flag 1 set or clear (clear means the caller)."""
    count = min(len(lot_guids), 13)
    for caller in (1, 2) if count > 1 else (1,):
        for stack_object in range(0, count + 1):
            for other in range(0, count + 2):
                for flags in (0, 1):
                    yield caller, stack_object, other, flags


def get_distance_to_cases(lot_guids):
    for caller, stack_object, other, flags in between_objects(lot_guids):
        for temp in (0, 7, 19, 20):
            operand = struct.pack("<HBBh", temp, flags, LITERAL, other).hex()
            yield (f"caller{caller}-stack{stack_object}-other{other}-flags{flags}-temp{temp}",
                   {"operand": operand, "caller": caller, "stackObject": stack_object})


def get_direction_to_cases(lot_guids):
    for caller, stack_object, other, flags in between_objects(lot_guids):
        for result_scope, result_data in ((TEMPS, 3), (LOCAL, 0), (MY_OBJECT, 21)):
            operand = struct.pack("<hHBBh", result_data, result_scope, flags, LITERAL, other).hex()
            yield (f"caller{caller}-stack{stack_object}-other{other}-flags{flags}-into{result_scope}.{result_data}",
                   {"operand": operand, "caller": caller, "stackObject": stack_object, "locals": [0]})


GENERATORS = {
    "expression": (2, False, lambda guids: expression_cases()),
    "sleep": (0, False, lambda guids: sleep_cases()),
    "refresh": (7, False, lambda guids: refresh_cases()),
    "random_number": (8, False, lambda guids: random_number_cases()),
    "play_sound": (23, False, lambda guids: play_sound_cases()),
    "set_to_next": (31, True, lambda guids: set_to_next_cases(guids[0][1])),
    "test_object_type": (32, True, lambda guids: test_object_type_cases(guids[0][0], guids[0][1])),
    "create_object_instance": (42, True, lambda guids: create_object_instance_cases(*guids)),
    "find_location_for": (16, False, lambda guids: find_location_for_cases()),
    "run_tree_by_name": (28, True, lambda guids: run_tree_by_name_cases(guids[0])),
    "stackobj_notify_out_of_idle": (49, True, lambda guids: notify_out_of_idle_cases(guids[0])),
    "get_distance_to": (11, True, lambda guids: get_distance_to_cases(guids[0])),
    "get_direction_to": (12, True, lambda guids: get_direction_to_cases(guids[0])),
}


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in GENERATORS:
        print(__doc__ + "\nPRIMITIVE is one of: " + ", ".join(GENERATORS), file=sys.stderr)
        return 2
    guids = None
    if "ORACLE_GUIDS" in os.environ:
        guids = tuple(int(value, 16) for value in os.environ["ORACLE_GUIDS"].split(","))
        masters = tuple(int(value, 16) for value in os.environ.get("ORACLE_MASTERS", "").split(",") if value)
        guids = (guids, masters)
    opcode, needs_guids, generate = GENERATORS[sys.argv[1]]
    if needs_guids and guids is None:
        print(f"{sys.argv[1]} cases name real objects and need ORACLE_GUIDS", file=sys.stderr)
        return 2
    cases = list(generate(guids))
    if guids is not None:
        # A smaller lot, such as the mock install's, has fewer objects than FreeSO's empty lot, whose
        # IDs the cases name; leave out the cases that set up an object the lot doesn't have.
        count = len(guids[0])
        def fits(request):
            named = [request.get("caller", 1), request.get("stackObject", 0)] + [int(key) for key in request.get("objects", {})]
            return all(object_id <= count for object_id in named)
        cases = [(case_id, request) for case_id, request in cases if fits(request)]
    lines = [json.dumps({"id": case_id, "opcode": opcode, **request}, separators=(",", ":")) for case_id, request in cases]
    assert len({case_id for case_id, _ in cases}) == len(cases), "case IDs must be unique"
    path = pathlib.Path(sys.argv[2])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(lines)} {sys.argv[1]} cases written to {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
