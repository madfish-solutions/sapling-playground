#include "../partial/FA12Types.ligo"
#include "../partial/FA12Methods.ligo"

type sapling_element is (int * sapling_state(8));

type sapling_params is list((sapling_transaction(8) * option(key_hash)));

type storage is record [
  ledger: sapling_element;
  token_a_address: address;
  token_b_address: address;
  token_a_pool: nat;
  token_b_pool: nat;
  total_supply: nat;
  proportion : nat;
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

function prepare(const prep : nat; var s : storage) : return is block {
  s.proportion := prep;
} with ((nil : list(operation)), s)

function swap(var s : storage) : (nat * nat * storage) is block {
    const from_in_with_fee : nat = tmp.amount_in * 997n;
    const numerator : nat = from_in_with_fee * swap.to_.pool;
    const denominator : nat = swap.from_.pool * 1000n + from_in_with_fee;

    (* calculate swapped token amount *)
    const out : nat = numerator / denominator;

    (* update pools amounts *)
    swap.to_.pool := abs(swap.to_.pool - out);
    swap.from_.pool := swap.from_.pool + tmp.amount_in;
}

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
              // HACK use amount to simulate proportioning of the shoulders to extract
              // Resolution is 1000mutez. Examples:
              // 0mutez means take out 100.0% of token_a and 0% of token b.
              // 500 mutez means 1:1 token_a to token b
              // 750 mutez takes 75% of token_a and 25% of token b
              const shares_to_divest = abs(value) * 997n / 1000n;

              const a_shares : nat = shares_to_divest * s.proportion / 1000n;
              const b_shares : nat = abs(shares_to_divest - a_shares);

              const token_a_divested : nat = s.token_a_pool * a_shares / s.total_supply;
              const token_b_divested : nat = s.token_b_pool * b_shares / s.total_supply;

              s.total_supply := abs(s.total_supply - value);
              s.token_a_pool := abs(s.token_a_pool - token_a_divested);
              s.token_b_pool := abs(s.token_b_pool - token_b_divested);

              const receiver : address = case (el.1) of
                | Some(hash) -> Tezos.address(Tezos.implicit_account(hash))
                | None -> (failwith("No receiver provided") : address)
              end;
              const tx_a : operation = Tezos.transaction((Tezos.self_address, (receiver, token_a_divested)),
                0mutez,
                fa12_transfer_entrypoint(s.token_a_address)
              );
              const tx_b : operation = Tezos.transaction((Tezos.self_address, (receiver, token_b_divested)),
                0mutez,
                fa12_transfer_entrypoint(s.token_b_address)
              );
              operations := tx_a # operations;
              operations := tx_b # operations;
            } else {
              const shoulder_amt = abs(value / 2);
              const tx_a : operation = Tezos.transaction((Tezos.sender, (Tezos.self_address, shoulder_amt)),
                0mutez,
                fa12_transfer_entrypoint(s.token_a_address)
              );
              const tx_b : operation = Tezos.transaction((Tezos.sender, (Tezos.self_address, shoulder_amt)),
                0mutez,
                fa12_transfer_entrypoint(s.token_b_address)
              );
              s.total_supply := s.total_supply + abs(value);
              s.token_a_pool := s.token_a_pool + shoulder_amt;
              s.token_b_pool := s.token_b_pool + shoulder_amt;
              operations := tx_a # operations;
              operations := tx_b # operations;
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
