#include "../partial/FA12Types.ligo"
#include "../partial/FA12Methods.ligo"

const precision : nat = 1_000_000_000_000_000_000n;

type sapling_element is sapling_state(8);

type sapling_params is list(sapling_transaction(8));

type storage is record [
  ledger: sapling_element;
  token_a_address: address;
  token_b_address: address;
  token_a_pool: nat;
  token_b_pool: nat;
  total_supply: nat;
  weight : nat;
  last_sender : address;
];

type parameter is 
| Prepare of nat
| Default of sapling_params

type return is (list(operation) * storage)

function fa12_transfer_entrypoint(const token_address : address) : contract(transfer_params) is
  case (Tezos.get_entrypoint_opt("%transfer", token_address) : option(contract(transfer_params))) of [
  | Some(contr) -> contr
  | None -> (failwith("fa12-transfer-ep-not-found") : contract(transfer_params))
  ]

function ceil_div(
  const numerator       : nat;
  const denominator     : nat)
                        : nat is
  case ediv(numerator, denominator) of [
  | Some(result) ->
      if result.1 > 0n
      then result.0 + 1n
      else result.0
  | None         -> failwith("CEIL_DIV by 0")
  ]

[@inline] function require(
  const param           : bool;
  const error           : string)
                        : unit is
  if param then unit else failwith(error);

function prepare(const prep : nat; var s : storage) : return is block {
  s.weight := prep;
  s.last_sender := Tezos.get_sender();
} with ((nil : list(operation)), s)

[@inline] function get_nat_or_fail(
  const value           : int;
  const error           : string)
                        : nat is
  case is_nat(value) of [
  | Some(natural) -> natural
  | None -> (failwith(error): nat)
  ]

function initialize(const shares: nat; const weight: nat) is
  if weight >= 1_000_000n then 
      (shares, shares * weight / 1_000_000n)
  else
      (shares * 1_000_000n / weight, shares);

function invest(
  const shares   : nat;
  const token_a_pool : nat;
  const token_b_pool : nat;
  const total_supply : nat;
  const weight       : nat)
                     : (nat * nat) is
block {
  var token_a_req := 0n;
  var token_b_req := 0n;

  require(
    weight = 0n or weight = 500_000n or weight = 1_000_000n,
    "INVALID_WEIGHT"
  );
  if weight = 500_000n then {
    token_a_req := ceil_div(shares * token_a_pool, total_supply);
    token_b_req := ceil_div(shares * token_b_pool, total_supply);

  } else {
    const token_pool_in = if weight = 0n
      then // only token A
        token_a_pool
      else // only token B; weight == 1_000_000n by require above
        token_b_pool;

    const new_total_supply = total_supply + shares;
    const token_in_ratio = new_total_supply * new_total_supply * precision / (total_supply * total_supply); // (new_supply * old_supply) ^ 2
    const token_amount_in_after_fee = get_nat_or_fail(token_pool_in * token_in_ratio / precision - token_pool_in, "IMPOSSIBLE_NEW_POOL");
    const token_amount_in = ceil_div(token_amount_in_after_fee * 10_000n, 9985n);

    if weight = 0n then {
      token_a_req := token_amount_in;
    } else {
      token_b_req := token_amount_in;
    };
  };
} with (token_a_req, token_b_req)

function divest(
  const shares_to_burn : nat;
  const token_a_pool   : nat;
  const token_b_pool   : nat;
  const total_supply   : nat;
  const weight         : nat)
                       : (nat * nat) is
{
  var token_a_divested : nat := 0n;
  var token_b_divested : nat := 0n;
  if weight = 500_000n then {
    token_a_divested := token_a_pool * shares_to_burn / total_supply;
    token_b_divested := token_b_pool * shares_to_burn / total_supply;
  } else {
    const token_pool_out = if weight = 0n
      then // only token A
        token_a_pool
      else // only token B; weight == 1_000_000n by require above
        token_b_pool;

    const new_total_supply = get_nat_or_fail(total_supply - shares_to_burn, "LOW_TOTAL_SHARES");

    const token_out_ratio = ceil_div(new_total_supply * new_total_supply * precision, (total_supply * total_supply)); // (new_supply * old_supply) ^ 2
    const new_token_pool_out = token_out_ratio * token_pool_out / precision;

    const token_amount_out_before_swap_fee = get_nat_or_fail(token_pool_out - new_token_pool_out, "IMPOSSIBLE_NEW_POOL");

    const token_amount_out = token_amount_out_before_swap_fee * 9985n / 10_000n;                    
    
    if weight = 0n then { // only token A
      token_a_divested := token_amount_out;
    } else { // only token B
      token_b_divested := token_amount_out;
    };
  };
} with (token_a_divested, token_b_divested)

function handle_sapling(const sp : sapling_params; var s : storage ) : return is 
block {
  // require(Tezos.get_amount() = 0mutez, "Can't accept tez");
  var operations := (list [] : list(operation));
  for el in list(sp) block {
    case Tezos.sapling_verify_update(el, s.ledger) of [
      | Some(output) -> block {
          const bound_data : bytes = output.0;
          const value: int = output.1.0;
          if value = 0 then
            skip (* anonymous transfer case *)
          else {
            if value > 0 then { // divest
              require(
                s.weight = 0n or s.weight = 500_000n or s.weight = 1_000_000n,
                "INVALID_WEIGHT"
              );
              require(Tezos.get_sender() = s.last_sender, "WRONG_SENDER");

              const shares_to_burn = abs(value);

              const (token_a_divested, token_b_divested) =
                divest(shares_to_burn, s.token_a_pool, s.token_b_pool, s.total_supply, s.weight);

              s.total_supply := get_nat_or_fail(s.total_supply - shares_to_burn, "LOW_TOTAL_SHARES");
              s.token_a_pool := get_nat_or_fail(s.token_a_pool - token_a_divested, "LOW_POOL_A");
              s.token_b_pool := get_nat_or_fail(s.token_b_pool - token_b_divested, "LOW_POOL_B");

              const receiver : address = case (Bytes.unpack(bound_data) : option(key_hash)) of [
                | Some(h) -> Tezos.address(Tezos.implicit_account(h))
                | None -> (failwith("No receiver provided") : address)
              ];
              
              if token_a_divested > 0n then {
                const tx : operation = Tezos.transaction(
                  (Tezos.get_self_address(), (receiver, token_a_divested)),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_a_address)
                );
                operations := tx # operations;
              } else skip;

              if token_b_divested > 0n then {
                const tx : operation = Tezos.transaction(
                  (Tezos.get_self_address(), (receiver, token_b_divested)),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_b_address)
                );
                operations := tx # operations;
              } else skip;

            } else { // invest
              require(Tezos.get_sender() = s.last_sender, "WRONG_SENDER");

              const req_shares = abs(value);

              const (token_a_req, token_b_req) =
                if s.total_supply > 0n then
                  invest(req_shares, s.token_a_pool, s.token_b_pool, s.total_supply, s.weight)
                else
                  initialize(req_shares, s.weight);

              s.total_supply := s.total_supply + req_shares;
              s.token_a_pool := s.token_a_pool + token_a_req;
              s.token_b_pool := s.token_b_pool + token_b_req;
              
              if token_a_req > 0n then {
                const tx : operation = Tezos.transaction((Tezos.get_sender(), (Tezos.get_self_address(), token_a_req)),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_a_address)
                );
                operations := tx # operations;
              } else skip;

              if token_b_req > 0n then {
                const tx : operation = Tezos.transaction((Tezos.get_sender(), (Tezos.get_self_address(), token_b_req)),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_b_address)
                );
                operations := tx # operations;
              } else skip;
            }
          };
          (* update ledger state *)
          s.ledger := output.1.1;
        } 
      | None -> block {
        failwith("Incorrect sapling update")
      }
    ];
  }
} with (operations, s)

function main(const param : parameter; var s : storage) : return is 
case param of [
    | Prepare(a) -> prepare(a, s)
    | Default(sp) -> handle_sapling(sp, s)
  ];
