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

function swap(
    const amount_in : nat;
    var from_pool : nat;
    var to_pool : nat
) : (nat * nat * nat) is block {
    const from_in_with_fee : nat = amount_in * 997n;
    const numerator : nat = from_in_with_fee * to_pool;
    const denominator : nat = from_pool * 1000n + from_in_with_fee;

    (* calculate swapped token amount *)
    const out : nat = numerator / denominator;

    (* update pools amounts *)
    to_pool := abs(to_pool - out);
    from_pool := from_pool + amount_in;
} with (out, from_pool, to_pool)

function handle_sapling(const sp : sapling_params; var s : storage ) : return is 
block {
  require(Tezos.get_amount() = 0mutez, "Can't accept tez");
  var operations := (list [] : list(operation));
  for el in list(sp) block {
    case Tezos.sapling_verify_update(el, s.ledger) of [
      | Some(output) -> block {
          const bound_data : bytes = output.0;
          const value: int = output.1.0;
          if value = 0 then
            skip (* anonymous transfer case *)
          else {
            if value > 0 then {
              require(
                s.weight = 0n or s.weight = 500_000n or s.weight = 1_000_000n,
                "INVALID_WEIGHT"
              );
              require(Tezos.get_sender() = s.last_sender, "WRONG_SENDER");

              const shares = abs(value);

              var token_a_divested : nat := 0n;
              var token_b_divested : nat := 0n;
              if s.weight = 500_000n then {
                token_a_divested := s.token_a_pool * shares / s.total_supply;
                token_b_divested := s.token_b_pool * shares / s.total_supply;
              } else {
                const token_pool_out = if s.weight = 0n
                  then // only token A
                    s.token_a_pool
                  else // only token B; weight == 1_000_000n by require above
                    s.token_b_pool;

                const new_total_supply = abs(s.total_supply - shares);
            
                const token_out_ratio = ceil_div(new_total_supply * new_total_supply * precision, (s.total_supply * s.total_supply)); // (new_supply * old_supply) ^ 2
                const new_token_pool_out = token_out_ratio * token_pool_out / precision;

                const token_amount_out_before_swap_fee = abs(token_pool_out - new_token_pool_out);

                const token_amount_out = token_amount_out_before_swap_fee * 9985n / 10_000n;                    
                
                if s.weight = 0n then { // only token A
                  token_a_divested := token_amount_out;
                } else { // only token B
                  token_b_divested := token_amount_out;
                };
              };

              s.total_supply := abs(s.total_supply - shares);
              s.token_a_pool := abs(s.token_a_pool - token_a_divested);
              s.token_b_pool := abs(s.token_b_pool - token_b_divested);

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

            } else {
              require(Tezos.get_sender() = s.last_sender, "WRONG_SENDER");

              const req_shares = abs(value);

              var token_a_req := 0n;
              var token_b_req := 0n;

              if s.total_supply =/= 0n then {
                require(
                  s.weight = 0n or s.weight = 500_000n or s.weight = 1_000_000n,
                  "INVALID_WEIGHT"
                );
                if s.weight = 500_000n then {
                  token_a_req := ceil_div(req_shares * s.token_a_pool, s.total_supply);
                  token_b_req := ceil_div(req_shares * s.token_b_pool, s.total_supply);
                } else {
                  const token_pool_in = if s.weight = 0n
                    then // only token A
                      s.token_a_pool
                    else // only token B; weight == 1_000_000n by require above
                      s.token_b_pool;

                  const new_total_supply = s.total_supply + req_shares;
                  const token_in_ratio = new_total_supply * new_total_supply * precision / (s.total_supply * s.total_supply); // (new_supply * old_supply) ^ 2
                  const token_amount_in_after_fee = abs(token_pool_in * token_in_ratio / precision - token_pool_in);
                  const token_amount_in = token_amount_in_after_fee * 9985n / 10_000n;

                  if s.weight = 0n then {
                    token_a_req := token_amount_in;
                  } else {
                    token_b_req := token_amount_in;
                  };
                };
              } else {
                if s.weight >= 1_000_000n then {
                  token_a_req := req_shares;
                  token_b_req := req_shares * s.weight / 1_000_000n;
                } else {
                  token_a_req := req_shares * 1_000_000n / s.weight;
                  token_b_req := req_shares;
                }
              };

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
