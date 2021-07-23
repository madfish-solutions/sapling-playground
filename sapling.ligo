type ss is sapling_state (8)

type storage is (int * ss)
type parameter is list(sapling_transaction(8) * option(key_hash))

type return is (list(operation) * storage)

function main(const param : parameter; var store : storage) : list (operation) * storage is
  ((nil : list (operation)), 
  block {
    for el in list(param) block {
      store := case Tezos.sapling_verify_update(el.0, store.1) of
          | Some(x) -> x
          | None -> (failwith("failed") : storage)
      end;
    }
  } with store
  )
