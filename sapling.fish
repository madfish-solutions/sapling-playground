#!/opt/homebrew/bin/fish

alias mockup-client='tezos-client --mode mockup --base-dir /tmp/mockup'

function chosen_ligo
    docker run -v $PWD:$PWD --rm -i ligolang/ligo:next $argv
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

set token_storage_mich (chosen_ligo compile storage $PWD/contracts/main/TokenFA12.ligo (echo $token_storage_ligo | string collect))

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
  ledger = (Tezos.sapling_empty_state : sapling_state(8));
  token_a_address = (\"$token_a_address\" : address);
  token_b_address = (\"$token_b_address\" : address);
  token_a_pool = 0n;
  token_b_pool = 0n;
  total_supply = 0n;
  weight = 0n;
  last_sender = (\"tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg\" : address);
]"

set dex_storage_mich (chosen_ligo compile storage $PWD/contracts/main/SaplingDex.ligo (echo $dex_storage | string collect))

echo $dex_storage_mich

mockup-client originate contract sapling_dex transferring 0 from bootstrap1 \
                        running ./contracts/compiled/SaplingDex.tz \
                        --burn-cap 3 --force \
                        --init (echo $dex_storage_mich)

set sapling_dex_address (contract_address sapling_dex | string collect)

mockup-client get contract storage for sapling_dex

mockup-client call token_a from $alice \
    --burn-cap 1 \
    --entrypoint "approve" --arg "Pair \"$sapling_dex_address\" 100000000"

mockup-client call token_a from $bob \
    --burn-cap 1 \
    --entrypoint "approve" --arg "Pair \"$sapling_dex_address\" 100000000"

  mockup-client call token_b from $alice \
    --burn-cap 1 \
    --entrypoint "approve" --arg "Pair \"$sapling_dex_address\" 100000000"

mockup-client call token_b from $bob \
    --burn-cap 1 \
    --entrypoint "approve" --arg "Pair \"$sapling_dex_address\" 100000000"

# mockup-client sapling man

# generate two shielded keys for Alice and Bob and use them for the sapling_dex contract
# the memo size has to be indicated
mockup-client sapling gen key alice -f --unencrypted
mockup-client sapling use key alice for contract sapling_dex --memo-size 8
mockup-client sapling gen key bob -f --unencrypted
mockup-client sapling use key bob for contract sapling_dex --memo-size 8

set alice_sapling_address (gen_sapling_address alice)
set bob_sapling_address (gen_sapling_address bob)

mockup-client from fa1.2 contract token_a get balance for $alice

### initialize exchange ###

mockup-client call sapling_dex from $alice \
    --burn-cap 1 \
    --entrypoint "prepare" --arg "1000000"

mockup-client sapling shield 0.010000 from $alice to $alice_sapling_address using sapling_dex --burn-cap 2 
mockup-client get contract storage for sapling_dex
mockup-client from fa1.2 contract token_a get balance for $sapling_dex_address
mockup-client from fa1.2 contract token_b get balance for $sapling_dex_address

set bob_balance_before_invest (mockup-client from fa1.2 contract token_b get balance for $bob)


### invest some ###
mockup-client call sapling_dex from $bob \
    --burn-cap 1 \
    --entrypoint "prepare" --arg "0"
mockup-client sapling shield 0.001000 from $bob to $bob_sapling_address using sapling_dex --burn-cap 2 
mockup-client from fa1.2 contract token_a get balance for $sapling_dex_address
mockup-client from fa1.2 contract token_b get balance for $sapling_dex_address

### divest some ###
mockup-client call sapling_dex from $bob \
    --burn-cap 1 \
    --entrypoint "prepare" --arg "1000000"
mockup-client sapling unshield 0.001000 from bob to $bob using sapling_dex --burn-cap 2 
mockup-client from fa1.2 contract token_a get balance for $sapling_dex_address
mockup-client from fa1.2 contract token_b get balance for $sapling_dex_address