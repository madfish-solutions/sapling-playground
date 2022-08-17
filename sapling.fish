#!/opt/homebrew/bin/fish
# alias mockup-client='/home/julian/Projects/tezos-v9/tezos-client --mode mockup --base-dir /tmp/mockup'
alias mockup-client='tezos-client --mode mockup --base-dir /tmp/mockup'

function chosen_ligo
    docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.45.0 $argv --protocol hangzhou
end

function contract_address
    mockup-client show known contract $argv
end

# gets alias sapling key address. Applies `sed` to get the third of the output
function gen_sapling_address
  mockup-client sapling gen address $argv | sed -n "2,2p"
end

set first_bootstrap_addr "tz1KqTpEZ7Yob7QbPE4Hy4Wo8fHG8LhKxZSx"

set token_storage_ligo "record [
  total_supply = 100000000n;
  ledger = big_map[
    (\"$first_bootstrap_addr\" : address) -> record[
        balance = 30000000n;
        allowances = (map [] : map(address, nat)); 
    ];
  ];
]"

set token_storage_mich (chosen_ligo compile storage $PWD/contracts/main/TokenFA12.ligo (echo $token_storage_ligo | string collect))
exit 0

mockup-client originate contract token transferring 1 from bootstrap1 \
                        running ./contracts/compiled/TokenFA12.tz \
                        --burn-cap 10 --force \
                        --init (echo $token_storage_mich)

set token_address (contract_address token | string collect)
mockup-client bake for bootstrap1
sleep 1

exit 0

# originate the contract with its initial empty sapling storage,
# { } represents an empty Sapling state.
mockup-client originate contract sapling_token transferring 0 from bootstrap1 running ./contracts/compiled/SaplingFA12.tz --init "Pair (Pair 0 { }) \"$token_address\"" --burn-cap 3 --force
mockup-client bake for bootstrap1
sleep 1

set sapling_token_address (contract_address sapling_token | string collect)


mockup-client call token from $first_bootstrap_addr \
    --burn-cap 1 \
    --entrypoint "approve" --arg "Pair \"$sapling_token_address\" 100000000"

mockup-client bake for bootstrap1

# as usual you can check the mockup-client manual
# mockup-client sapling man

# generate two shielded keys for Alice and Bob and use them for the sapling_token contract
# the memo size has to be indicated
mockup-client sapling gen key alice -f --unencrypted
mockup-client sapling use key alice for contract sapling_token --memo-size 8
mockup-client sapling gen key bob -f --unencrypted
mockup-client sapling use key bob for contract sapling_token --memo-size 8

# manually generate an address for Alice to receive shielded tokens.
# mockup-client sapling gen address alice
# replace it with output of the previous command
# zet13oMkE5SXGaMtEni351y2GmsUCgPLkgyXmTWwA3rJPNeXhZedn6U4tsQqnPZjoUuDf # Alice's address
set alice_sapling_address (gen_sapling_address alice)
set bob_sapling_address (gen_sapling_address bob)



# shield 10 tokens from bootstrap1 to alice
mockup-client sapling shield 10 from bootstrap1 to $alice_sapling_address using sapling_token --burn-cap 2 
mockup-client bake for bootstrap1
mockup-client sapling get balance for alice in contract sapling_token

# generate an address for Bob to receive shielded tokens.
# mockup-client sapling gen address bob
# replace it with output of the previous command
# zet149gV9CfoHByG2yMtiyWB2prfDW1puBy2Z7L9uPs7yoSrEyBufTDFYF5cUwN36eHbQ # Bob's address

# ---------------------
# forge a shielded transaction from alice to bob that is saved to a file
mockup-client sapling forge transaction 10 from alice to $bob_sapling_address using sapling_token

# # submit the shielded transaction from any transparent account
mockup-client sapling submit sapling_transaction from bootstrap2 using sapling_token --burn-cap 1
sleep 1
mockup-client bake for bootstrap1
mockup-client sapling get balance for bob in contract sapling_token

# # unshield from bob to any transparent account
mockup-client sapling unshield 5 from bob to bootstrap1 using sapling_token --burn-cap 1
mockup-client bake for bootstrap1
