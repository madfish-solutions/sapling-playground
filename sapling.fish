#!/opt/homebrew/bin/fish

alias mockup-client='tezos-client --mode mockup --base-dir /tmp/mockup'

function chosen_ligo
    docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.21.0 $argv
end

function contract_address
    mockup-client show known contract $argv
end

# gets alias sapling key address. Applies `sed` to get the third of the output
function gen_sapling_address
  mockup-client sapling gen address $argv | sed -n "2,2p"
end

set alice "tz1ddb9NMYHZi5UzPdzTZMYQQZoMub195zgv" # bootstrap5
set bob "tz1b7tUupMgCNw2cCLpKTkSD1NZzB5TkP2sv" # bootstrap4
set eve "tz1faswCTDciRzE4oJ9jn2Vm2dvjeyA9fUzU" # bootstrap3

set token_storage_ligo "record [
  total_supply = 100_000_000n;
  ledger = big_map[
    (\"$alice\" : address) -> record[
        balance = 450_000n;
        allowances = (map [] : map(address, nat)); 
    ];
    (\"$bob\" : address) -> record[
        balance = 50_000n;
        allowances = (map [] : map(address, nat)); 
    ];
  ];
]"

set token_storage_mich (chosen_ligo compile-storage $PWD/contracts/main/TokenFA12.ligo main (echo $token_storage_ligo | string collect))

mockup-client originate contract token_a transferring 1 from bootstrap1 \
                        running ./contracts/compiled/TokenFA12.tz \
                        --burn-cap 10 --force \
                        --init (echo $token_storage_mich)

set token_a_address (contract_address token_a | string collect)

mockup-client originate contract token_b transferring 1 from bootstrap1 \
                        running ./contracts/compiled/TokenFA12.tz \
                        --burn-cap 10 --force \
                        --init (echo $token_storage_mich)

set token_b_address (contract_address token_b | string collect)

set dex_storage "record [
  ledger = (0, (Tezos.sapling_empty_state : sapling_state(8)));
  token_a_address = (\"$token_a_address\" : address);
  token_b_address = (\"$token_b_address\" : address);
  token_a_pool = 0n;
  token_b_pool = 0n;
  total_supply = 0n;
  proportion = 0n;
]"

set dex_storage_mich (chosen_ligo compile-storage $PWD/contracts/main/SaplingFA12.ligo main (echo $dex_storage | string collect))

echo $dex_storage_mich

mockup-client originate contract sapling_token transferring 0 from bootstrap1 \
                        running ./contracts/compiled/SaplingFA12.tz \
                        --burn-cap 3 --force \
                        --init (echo $dex_storage_mich)

set sapling_token_address (contract_address sapling_token | string collect)

mockup-client call sapling_token from $bob \
    --burn-cap 1 \
    --entrypoint "prepare" --arg "500"

mockup-client get contract storage for sapling_token

mockup-client call token_a from $alice \
    --burn-cap 1 \
    --entrypoint "approve" --arg "Pair \"$sapling_token_address\" 100000000"

mockup-client call token_a from $bob \
    --burn-cap 1 \
    --entrypoint "approve" --arg "Pair \"$sapling_token_address\" 100000000"

  mockup-client call token_b from $alice \
    --burn-cap 1 \
    --entrypoint "approve" --arg "Pair \"$sapling_token_address\" 100000000"

mockup-client call token_b from $bob \
    --burn-cap 1 \
    --entrypoint "approve" --arg "Pair \"$sapling_token_address\" 100000000"

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

mockup-client from fa1.2 contract token_a get balance for $alice

# shield 10 tokens from alice to zet1alice
mockup-client sapling shield 0.900000 from $alice to $alice_sapling_address using sapling_token --burn-cap 2 
# mockup-client sapling get balance for alice in contract sapling_token
# mockup-client get contract storage for sapling_token

mockup-client sapling shield 0.100000 from $bob to $bob_sapling_address using sapling_token --burn-cap 2 

mockup-client call sapling_token from $bob \
    --burn-cap 1 \
    --entrypoint "prepare" --arg "1000"

mockup-client sapling unshield 0.100000 from bob to $bob using sapling_token --burn-cap 1

mockup-client get contract storage for sapling_token
mockup-client from fa1.2 contract token_a get balance for $bob
mockup-client from fa1.2 contract token_b get balance for $bob

exit 0

mockup-client sapling unshield 0.900000 from alice to $alice using sapling_token --burn-cap 1


mockup-client from fa1.2 contract token_a get balance for $alice
mockup-client from fa1.2 contract token_b get balance for $alice
