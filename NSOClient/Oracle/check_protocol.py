"""Runs Examples/expression.jsonl through `fso-oracle run-primitive` and checks the answers.

A regression check for the oracle's protocol, not for the Swift port. Needs TSO_GAME_DIR
and a built oracle (`dotnet build NSOClient/NSOClient.slnx -c Release`). Exits 1 on failure.

    python3 -I NSOClient/Oracle/check_protocol.py
"""

import json
import pathlib
import subprocess
import sys

ORACLE = pathlib.Path(__file__).resolve().parent


def check(responses):
    """Yields a message for each answer that isn't what FreeSO gives."""
    def expect(request_id, description, condition):
        if not condition(responses.get(request_id, {})):
            yield f"{request_id}: expected {description}, got {json.dumps(responses.get(request_id))}"

    yield from expect("assign", "temp 0 = 5", lambda r: r.get("temps", [None])[0] == 5)
    yield from expect("plus", "temp 1 = 7", lambda r: r.get("temps", [None, None])[1] == 7)
    yield from expect("less", "GOTO_TRUE", lambda r: r.get("exit") == "GOTO_TRUE")
    yield from expect("divide-by-zero", "temp 0 = -1 (FreeSO doesn't fail)", lambda r: r.get("temps", [None])[0] == -1)
    yield from expect("global", "global 10 = 3", lambda r: r.get("globals") == {"10": 3})
    yield from expect("object-data", "object 1 data 3 = 9", lambda r: r.get("objects") == {"1": {"data": {"3": 9}}})
    yield from expect("object-data-again", "the same answer (requests are isolated)",
                      lambda r: r.get("objects") == responses.get("object-data", {}).get("objects"))
    yield from expect("attribute", "object 1 attribute 1 = 42", lambda r: r.get("objects") == {"1": {"attributes": {"1": 42}}})
    yield from expect("no-stack-object", "an exception", lambda r: "exception" in r)
    yield from expect("random", "a value from 0 to 99 and a new seed",
                      lambda r: 0 <= r.get("temps", [-1])[0] < 100 and r.get("seed") != "0f50d0c5eed00001")
    yield from expect("random-again", "the same answer (the seed is fixed)",
                      lambda r: r.get("temps") == responses.get("random", {}).get("temps"))
    yield from expect("no-primitive", "GOTO_TRUE with noPrimitive", lambda r: r.get("noPrimitive") is True and r.get("exit") == "GOTO_TRUE")
    yield from expect("bad-opcode", "a request error", lambda r: "requestError" in r)
    yield from expect("unknown-field", "a request error", lambda r: "requestError" in r)


def main():
    requests = (ORACLE / "Examples" / "expression.jsonl").read_text(encoding="utf-8")
    result = subprocess.run(
        ["dotnet", "run", "--project", str(ORACLE), "-c", "Release", "--no-build", "--", "run-primitive"],
        input=requests, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        print(f"fso-oracle exited with {result.returncode}", file=sys.stderr)
        return 1

    responses = {}
    for line in result.stdout.splitlines():
        response = json.loads(line)
        if response.get("protocol") != 1:
            print(f"unexpected protocol version: {line}", file=sys.stderr)
            return 1
        responses[response.get("id")] = response

    expected = sum(1 for line in requests.splitlines() if line.strip() and not line.startswith("#"))
    failures = list(check(responses))
    if len(responses) != expected:
        failures.append(f"expected {expected} responses, got {len(responses)}")
    for failure in failures:
        print(failure, file=sys.stderr)
    print(f"{expected - len(failures)} of {expected} checks passed" if failures else f"all {expected} checks passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
