import subprocess
import argparse
import sys

from decimal import Decimal
from bottle import get, post, run, request, response, hook, HTTPResponse

from utils import mock_tez_amount, extract_sapling_parameter_from_error
from utils import extract_generic_error


# CLIENT = ["tezos-client", "--mode", "mockup", "--base-dir", "/tmp/mockup"]
DUMMY_ALIAS = "dummy_safe_to_delete"

# network-wide bob secret added just to allow tezos-client to fail so we can extract the payload
UNECRYPTED_BOB_SK = "unencrypted:edsk3RFfvaFaxbHx8BMtEW1rKQcPtDML3LXjNqMNLCzC3wLC1bWbAt"

weights = ["mainnet", "jakartanet", "kathmandunet", "mockup"]

parser = argparse.ArgumentParser(description='Shim to access tezos-client Sapling wallet')
parser.add_argument('--rpc',
                    type=str,
                    default="https://rpc.jakartanet.teztnets.xyz/",
                    help='RPC to use'
                    )

args = parser.parse_args()

CLIENT = ["tezos-client", "--endpoint", args.rpc]

# add dummy non-sapling account to provoke tezos-client to yield an error


def check_dummy_account_exists():
    result = subprocess.run(CLIENT + ["show", "address", DUMMY_ALIAS], capture_output=True)
    return result.returncode == 0


def add_dummy_secret_key():
    result = subprocess.run(CLIENT + ["import", "secret", "key", DUMMY_ALIAS,
                            UNECRYPTED_BOB_SK, "--force"], capture_output=True)
    assert result.returncode == 0, "Could not import dummy alias"


### Endpoint handlers ###

@get("/accounts")
def get_accounts():
    result = subprocess.run(CLIENT + ["sapling", "list", "keys"], capture_output=True, text=True)
    accounts = result.stdout.splitlines()
    return {"accounts": accounts}


@post("/gen_new_address")
def gen_new_address():
    account = request.json.get('account')
    args = CLIENT + ["sapling", "gen", "address", account]
    out, err, code = interactive_run(args)
    if code != 0:
        generic_error = extract_generic_error(err)
        return {"error": generic_error}

    split = out.splitlines()
    address = split[1]
    index = split[2].split(" ")[2]

    return {"address": address, "index": index}


@get("/balance")
def get_balance():
    account = request.query.get('account')
    contract = request.query.get('contract')

    authorize(account, contract)

    client_args = CLIENT + ["sapling", "get", "balance", "for", account, "in", "contract", contract]
    (out, err, code) = interactive_run(client_args)
    if code != 0:
        return {"error": "no_such_account_or_contract"}

    print(out)

    words = out.split(" ")
    amount_word = words[-1]
    amount_numbers = "".join(filter(str.isdigit, amount_word))
    amount = Decimal(amount_numbers) * Decimal(1_000_000)
    return {"account": account, "contract": contract, "balance": str(amount)}


@post("/create_account")
def create_account():
    account = request.json.get('account')
    result = subprocess.Popen(CLIENT + ["sapling", "gen", "key", account, "--unencrypted"], text=True)
    result.wait()
    if result.returncode != 0:
        return {"error": "already_exists"}
    return {"account": account}


def authorize(account, contract):
    result = subprocess.Popen(CLIENT + ["sapling", "use", "key", account, "for", "contract", contract], text=True)
    result.wait()


@post("/shield")
def shield():
    account = request.json.get('account')
    contract = request.json.get('contract')
    amount = request.json.get('amount')
    to_zaddress = request.json.get('to_zaddress')

    dummy_exists = check_dummy_account_exists()
    if not dummy_exists:
        add_dummy_secret_key()

    authorize(account, contract)

    client_args = CLIENT + ["sapling", "shield",
                            mock_tez_amount(amount), "from", DUMMY_ALIAS, "to", to_zaddress, "using", contract, "--dry-run"]

    print(client_args)

    (out, err, code) = interactive_run(client_args)

    # code is expected to be -1 here, so we attempt to detect a real error here
    if out.find("Parameter:") == -1:
        generic_error = extract_generic_error(err)
        return {"error": generic_error}

    # somehow this payload ends up in stdout
    sapling_payload = extract_sapling_parameter_from_error(out)

    return {"shield": sapling_payload[2:]}


@post("/unshield")
def unshield():
    account = request.json.get('account')
    amount = request.json.get('amount')
    to_address = request.json.get('to_address')
    contract = request.json.get('contract')

    dummy_exists = check_dummy_account_exists()
    if not dummy_exists:
        add_dummy_secret_key()

    authorize(account, contract)

    client_args = CLIENT + ["sapling", "unshield", mock_tez_amount(
        amount), "from", account, "to", to_address, "using", contract, "--dry-run", "--burn-cap", "0.1"]

    print(client_args)

    (out, err, code) = interactive_run(client_args)

    print(err)

    # code is expected to be -1 here, so we attempt to detect a real error here
    if out.find("Parameter:") == -1:
        generic_error = extract_generic_error(err)
        return {"error": generic_error}

    # somehow this payload ends up in stdout
    sapling_payload = extract_sapling_parameter_from_error(out)

    return {"unshield": sapling_payload[2:]}


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

    print("\nDone!")

    return (outbuf, errbuf, process.returncode)


### Setup CORS stuff ###

cors_headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
}


@hook('before_request')
def handle_options():
    if request.method == 'OPTIONS':
        # Bypass request routing and immediately return a response
        raise HTTPResponse(headers=cors_headers)


@hook('after_request')
def enable_cors():
    for key, value in cors_headers.items():
        response.set_header(key, value)


### Run the server ###
try:
    result = subprocess.run(CLIENT, stdout=subprocess.DEVNULL)
    if result.returncode != 0:
        print("Could not run `tezos-client`. Verify it is in $PATH and configured correctly")
        exit(1)
except FileNotFoundError:
    print("Could not find `tezos-client` binary. Make sure it is installed in your system. Please refer to https://assets.tqtezos.com/docs/setup/1-tezos-client/")
    exit(1)

run(host='0.0.0.0', port=8765)
