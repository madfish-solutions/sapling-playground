import asyncio
import subprocess
import argparse
import websockets
import json
# from pytezos import pytezos

from utils import mock_tez_amount, extract_sapling_parameter_from_error, find_nth
from utils import calc_pool_in_given_single_out, extract_generic_error


CLIENT = ["tezos-client", "--mode", "mockup", "--base-dir", "/tmp/mockup"]
# DUMMY_ALIAS = "sapling_dex_dummy_alias_safe_to_delete"
DUMMY_ALIAS = "bootstrap4"
CALLER = "bootstrap5"
BURN_CAP = 0.2

# network-wide bob secret added just to allow tezos-client to fail so we can extract the payload
UNECRYPTED_BOB_SK = "unencrypted:edsk3RFfvaFaxbHx8BMtEW1rKQcPtDML3LXjNqMNLCzC3wLC1bWbAt"
SAPLING_ACOUNT_NAME = "account3"

# weights = ["token_a_only", "token_b_only", "proportional"]

# parser = argparse.ArgumentParser(description='Generate Sapling payload')
# parser.add_argument('command', type=str, nargs=1,
#                     help='Either invest or divest')
# parser.add_argument('type', choices=weights,
#                     help='Tokens involved in operation')
# parser.add_argument('amount', type=int,
#                     help='Amount of token. In case of `proportional` is amount of shares to buy')
# parser.add_argument('to', type=str,
#                     help='Either zet1 address in `invest`, tz1 address in `divest`')
# parser.add_argument('contract', type=str, nargs='?', default="sapling_dex",
#                     help='Contract of Sapling DEX')
            
# args = parser.parse_args()
# print(args)

# add dummy non-sapling account to provoke tezos-client to yield an error
def check_dummy_account_exists():
    result = subprocess.run(CLIENT + ["show", "address", DUMMY_ALIAS], capture_output=True)
    return result.returncode == 0

def add_dummy_secret_key():
    result = subprocess.run(CLIENT + ["import", "secret", "key", DUMMY_ALIAS, UNECRYPTED_BOB_SK], capture_output=True)
    assert result.returncode == 0, "Could not import dummy alias"

def get_pools_from_storage(contract):
    result = subprocess.run(CLIENT + ["get", "contract", "storage", "for", contract, "--unparsing-mode", "Optimized"], capture_output=True, text=True)
    assert result.returncode == 0, "Could not get contract storage"

    result = result.stdout
    
    start = find_nth(result, "Pair", 2)
    start += 52
    end = result[start:].find(")")

    print(result[start:])

    pool_a = result[start:end]

    start = find_nth(result, "Pair", 5)
    start += 52
    end = result[start:].find(";") - 1
    print(result[start:])

    pool_b = result[start:start + end]
    return pool_a, pool_b

async def get_accounts():
    result = subprocess.run(CLIENT + ["sapling", "list", "keys"], capture_output=True, text=True)
    accounts = result.stdout.splitlines()
    return accounts

async def gen_new_address(account):
    args = CLIENT + ["sapling", "gen", "address", account]
    out, err, code = interactive_run(args)
    if code != 0:
        generic_error = extract_generic_error(err)
        return {"error" : generic_error}
    
    split = out.splitlines()
    address = split[1]
    index = split[2].split(" ")[2]
    
    return {"address" : address, "index" : index}

async def get_balance(account, contract):
    result = subprocess.run(CLIENT + ["sapling", "get", "balance", "for", account, "in", "contract", contract], capture_output=True, text=True)
    words = result.stdout.split(" ")
    amount = words[3]
    amount = amount[:-2]
    if result.returncode != 0:
        return {"error" : "no_such_account_or_contract"}
    return {"account": account, "contract": contract, "balance" : amount}

async def create_account(name):
    result = subprocess.Popen(CLIENT + ["sapling", "gen", "key", name], text=True)
    result.wait()
    if result.returncode != 0:
        return {"error" : "already_exists"}
    return {"new_account" : name}

async def authorize_contract(account, contract):
    result = subprocess.Popen(CLIENT + ["sapling", "use", "key", account, "for", "contract", contract], text=True)
    result.wait()
    if result.returncode != 0:
        return {"error" : "unspecified_error_or_already_authorized"}
    return {"account": account, "contract": contract, "authorized" : True}

async def shield(account, amount, to_zaddress, contract):
    dummy_exists = check_dummy_account_exists()
    if not dummy_exists:
        add_dummy_secret_key()
    
    client_args = CLIENT + ["sapling", "shield", mock_tez_amount(amount), "from", DUMMY_ALIAS, "to", to_zaddress, "using", contract, "--dry-run"]

    print(client_args)

    (out, err, code) = interactive_run(client_args)

    # code is expected to be -1 here, so we attempt to detect a real error here
    if out.find("Parameter:") == -1:
        generic_error = extract_generic_error(err)
        return {"error" : generic_error}

    # somehow this payload ends up in stdout
    sapling_payload = extract_sapling_parameter_from_error(out)

    return {"shield" : sapling_payload}

async def unshield(from_zaddress, amount, to_address, contract):
    dummy_exists = check_dummy_account_exists()
    if not dummy_exists:
        add_dummy_secret_key()
    
    client_args = CLIENT + ["sapling", "unshield", mock_tez_amount(amount), "from", from_zaddress, "to", to_address, "using", contract, "--dry-run"]

    print(client_args)

    (out, err, code) = interactive_run(client_args)

    print(err)

    # code is expected to be -1 here, so we attempt to detect a real error here
    if out.find("Parameter:") == -1:
        generic_error = extract_generic_error(err)
        return {"error" : generic_error}

    # somehow this payload ends up in stdout
    sapling_payload = extract_sapling_parameter_from_error(out)

    return {"unshield" : sapling_payload}


async def respond(websocket):
    async for message in websocket:
        try:
            data = json.loads(message)
        
            command = data["command"]
            response = {}
            if command == "shield":
                account = data["account"]
                amount = data["amount"]
                to_zaddress = data["to_zaddress"]
                contract = data["contract"]
                response = await shield(account, amount, to_zaddress, contract)
            elif command == "unshield":
                from_zaddress = data["from_zaddress"]
                amount = data["amount"]
                to_address = data["to_address"]
                contract = data["contract"]
                response = await unshield(from_zaddress, amount, to_address, contract)
            elif command == "get_account":
                response = await get_accounts()
            elif command == "create_account":
                name = data["name"]
                response = await create_account(name)
            elif command == "gen_new_address":
                account = data["account"]
                response = await gen_new_address(account)
            elif command == "get_balance":
                account = data["account"]
                contract = data["contract"]
                response = await get_balance(account, contract)
            elif command == "authorize_contract":
                account = data["account"]
                contract = data["contract"]
                response = await authorize_contract(account, contract)
            else:
                response = {"unknown_command": command}
        except Exception as e:
            print(e)
            response = {"error": "cant_parse_json"}
            
        await websocket.send(json.dumps(response))

def interactive_run(args):
    outbuf = ""
    errbuf = ""
    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    while process.poll() is None:
        reading = process.stdout.read(1).decode('utf-8', errors='replace')

        sys.stdout.write(reading)
        sys.stdout.flush()

        outbuf += reading

    last_reading = process.stdout.read().decode('utf-8', errors='replace')
    outbuf += last_reading

    errbuf = process.stderr.read().decode('utf-8', errors='replace')


    return (outbuf, errbuf, process.returncode)

import sys        

async def main():
    async with websockets.serve(respond, "localhost", 8765):
        await asyncio.Future()  # run forever

asyncio.run(main())