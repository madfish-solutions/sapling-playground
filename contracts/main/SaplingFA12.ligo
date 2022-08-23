#include "../partial/FA12Types.ligo"
#include "../partial/FA12Methods.ligo"

const precision : nat = 1_000_000n;

type sapling_element is (int * sapling_state(8));

type sapling_params is list((sapling_transaction(8) * option(key_hash)));

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
  case (Tezos.get_entrypoint_opt("%transfer", token_address) : option(contract(transfer_params))) of
  | Some(contr) -> contr
  | None -> (failwith("fa12-transfer-ep-not-found") : contract(transfer_params))
  end

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
  s.last_sender := Tezos.sender;
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
  var operations := (list [] : list(operation));
  for el in list(sp) block {
    case Tezos.sapling_verify_update(el.0, s.ledger.1) of
      | Some(output) -> block {
          const value: int = output.0;
          if value = 0 then
            skip (* anonymous transfer case *)
          else {
            if value > 0 then {
              const shares = abs(value);
              var token_a_divested : nat := s.token_a_pool * shares / s.total_supply;
              var token_b_divested : nat := s.token_b_pool * shares / s.total_supply;

              require(
                s.weight = 0n or s.weight = 500_000n or s.weight = 1_000_000n,
                "INVALID_WEIGHT"
              );
              require(Tezos.sender = s.last_sender, "WRONG_SENDER");
              
              if s.weight = 0n then { // only token A
                const (out, token_b_pool, token_a_pool) = swap(token_b_divested, s.token_b_pool, s.token_a_pool);
                token_a_divested := token_a_divested + out;
                token_b_divested := 0n;

                s.token_a_pool := token_a_pool;
                s.token_b_pool := token_b_pool;
              } else if s.weight = 1_000_000n then { // only token B
                const (out, token_a_pool, token_b_pool) = swap(token_a_divested, s.token_a_pool, s.token_b_pool);
                token_a_divested := 0n;
                token_b_divested := token_b_divested + out;

                s.token_a_pool := token_a_pool;
                s.token_b_pool := token_b_pool;
              } else skip; // according to current pools

              s.total_supply := abs(s.total_supply - shares);
              s.token_a_pool := abs(s.token_a_pool - token_a_divested);
              s.token_b_pool := abs(s.token_b_pool - token_b_divested);

              const receiver : address = case (el.1) of
                | Some(hash) -> Tezos.address(Tezos.implicit_account(hash))
                | None -> (failwith("No receiver provided") : address)
              end;
              
              if token_a_divested > 0n then {
                const tx : operation = Tezos.transaction(
                  (Tezos.self_address, (receiver, token_a_divested)),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_a_address)
                );
                operations := tx # operations;
              } else skip;

              if token_b_divested > 0n then {
                const tx : operation = Tezos.transaction(
                  (Tezos.self_address, (receiver, token_b_divested)),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_b_address)
                );
                operations := tx # operations;
              } else skip;

            } else {
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
                  const total_supply_sq = s.total_supply * s.total_supply;
                  const req_shares_sq = req_shares * req_shares;
                  if s.weight = 0n then { // only token A
                    token_a_req := (1997n * s.token_a_pool * s.total_supply * req_shares + 1996n * s.token_a_pool * req_shares_sq) / (1000n * total_supply_sq + 999n * s.total_supply * req_shares);
                  } else if s.weight = 1_000_000n then { // only token B
                    token_b_req := (1997n * s.token_b_pool * s.total_supply * req_shares + 1996n * s.token_b_pool * req_shares_sq) / (1000n * total_supply_sq + 999n * s.total_supply * req_shares);
                  } else skip;
                };
              } else {
                if s.weight >= 1_000_000n then {
                  token_a_req := req_shares;
                  token_b_req := req_shares * s.weight / 1_000_000n;
                } else {
                  token_a_req := req_shares * s.weight / 1_000_000n;
                  token_b_req := req_shares;
                }
              };

              require(Tezos.sender = s.last_sender, "WRONG_SENDER");

              s.total_supply := s.total_supply + req_shares;
              s.token_a_pool := s.token_a_pool + token_a_req;
              s.token_b_pool := s.token_b_pool + token_b_req;
              
              if token_a_req > 0n then {
                const tx : operation = Tezos.transaction((Tezos.sender, (Tezos.self_address, token_a_req)),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_a_address)
                );
                operations := tx # operations;
              } else skip;

              if token_b_req > 0n then {
                const tx : operation = Tezos.transaction((Tezos.sender, (Tezos.self_address, token_b_req)),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_b_address)
                );
                operations := tx # operations;
              } else skip;
            }
          };
          (* update ledger state *)
          s.ledger := output;
        } 
      | None -> block {
        failwith("Incorrect sapling update")
      }
    end;
  }
} with (operations, s)

function main(const param : parameter; var s : storage) : return is 
case param of [
    | Prepare(a) -> prepare(a, s)
    | Default(sp) -> handle_sapling(sp, s)
  ];
