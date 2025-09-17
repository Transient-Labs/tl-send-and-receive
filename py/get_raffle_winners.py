import json
import subprocess

BLOCK_JUMP_AMOUNT = 25_000

# input
rpc_url = input("Please enter the rpc url: ")
contract_address = input("Please enter the raffle contract address: ")
start_block = int(input("Please enter the start block: "))
from_block = start_block
to_block = start_block + BLOCK_JUMP_AMOUNT

# get current block
latest_block = int(
    subprocess.run(
        ["cast", "block-number", "--rpc-url", rpc_url],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
)

# get logs
logs = []
while True:
    cmd = [
        "cast",
        "logs",
        "--rpc-url",
        rpc_url,
        "--address",
        contract_address,
        "--from-block",
        str(from_block),
        "--to-block",
        str(to_block),
        "--json",
        "0xdb4b459b9af0810582f21ec0ec043ee9c3f91ea26a3d3a675dea0e9e5e099f05",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    sublogs = json.loads(result.stdout.strip())
    logs += sublogs
    from_block = to_block + 1
    to_block += BLOCK_JUMP_AMOUNT
    if from_block > latest_block:
        break
print(f"Number of entries: {len(logs)}")

# parse logs and get a list of entrants
entrants = []
for log in logs:
    entry_raw = log["topics"][1]
    result = subprocess.run(
        ["cast", "parse-bytes32-address", entry_raw],
        capture_output=True,
        text=True,
        check=True,
    )
    entry = result.stdout.strip()
    entrants += [entry]

# loop through entrants and see who is a winner
winners = []
for entry in entrants:
    result = subprocess.run(
        " ".join(
            [
                "cast",
                "call",
                "--rpc-url",
                rpc_url,
                contract_address,
                "'isWinner(address) returns (bool)'",
                entry,
            ]
        ),
        capture_output=True,
        shell=True,
        text=True,
        check=True,
    )
    is_winner = json.loads(result.stdout.strip())
    if is_winner:
        winners += [entry]

# print winners
print("\nWinners:")
for winner in winners:
    print(winner)
