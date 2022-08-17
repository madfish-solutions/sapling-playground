#include "../partial/FA12Types.ligo"
#include "../partial/FA12Methods.ligo"

type sapling_element is (int * sapling_state(8));

type storage is record [
  ledger: sapling_element;
  token_address: address;
]

type parameter is list(sapling_transaction(8) * option(key_hash))

type return is (list(operation) * storage)

function fa12_transfer_entrypoint(const token_address : address) : contract(transfer_params) is
  case (Tezos.get_entrypoint_opt("%transfer", token_address) : option(contract(transfer_params))) of [
  | Some(contr) -> contr
  | None -> (failwith("fa12-transfer-ep-not-found") : contract(transfer_params))
  ]

function main(const param : parameter; var s : storage) : return is 
  block {
    var operations : list(operation) := list[];

    for el in list(param) block {
      case Tezos.sapling_verify_update(el.0, s.ledger.1) of [
        | Some(output) -> block {
            const value: int = output.0;
            if value = 0 then
              skip (* anonymous transfer case *)
            else {
              if value > 0 then {
                const receiver : address = case (el.1) of [
                  | Some(keyhash) -> Tezos.address(Tezos.implicit_account(keyhash))
                  | None -> (failwith("No receiver provided") : address) 
                ];
                const tx : operation = Tezos.transaction((Tezos.get_self_address(), (receiver, abs(value))),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_address)
                );
                operations := tx # operations;
              } else {
                const tx : operation = Tezos.transaction((Tezos.get_sender(), (Tezos.get_self_address(), abs(value))),
                  0mutez,
                  fa12_transfer_entrypoint(s.token_address)
                );
                operations := tx # operations;
              }
            };
            (* update ledger state *)
            s.ledger := output;
          } 
        | None -> block {
          failwith("Incorrect sapling update")
        }
      ];
    }
  } with (operations, s)
