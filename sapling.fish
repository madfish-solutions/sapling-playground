#!/usr/bin/fish
alias mockup-client='tezos-client --mode mockup --base-dir /tmp/mockup'

# originate the contract with its initial empty sapling storage,
# bake a block to include it.
# { } represents an empty Sapling state.
# "Pair 0 {}" represents empty contract storage of type (int * sapling_state(8))
mockup-client originate contract shielded-tez transferring 0 from bootstrap1 running sapling.tz --init 'Pair 0 { }' --burn-cap 3
mockup-client bake for bootstrap1

# as usual you can check the mockup-client manual
# mockup-client sapling man

# generate two shielded keys for Alice and Bob and use them for the shielded-tez contract
# the memo size has to be indicated
mockup-client sapling gen key alice
mockup-client sapling use key alice for contract shielded-tez --memo-size 8
mockup-client sapling gen key bob
mockup-client sapling use key bob for contract shielded-tez --memo-size 8

# generate an address for Alice to receive shielded tokens.
# mockup-client sapling gen address alice
# replace it with output of the previous command
# zet14RYqSsKF4vbmHENFXfBHoXJjYDLmnfib1r372JARN3A1rSvVR95wMow8KRuKCueqA # Alice's address


# shield 10 tez from bootstrap1 to alice
mockup-client sapling shield 10 from bootstrap1 to zet14RYqSsKF4vbmHENFXfBHoXJjYDLmnfib1r372JARN3A1rSvVR95wMow8KRuKCueqA using shielded-tez --burn-cap 2 
mockup-client bake for bootstrap1
mockup-client sapling get balance for alice in contract shielded-tez

# generate an address for Bob to receive shielded tokens.
# mockup-client sapling gen address bob
# replace it with output of the previous command
# zet142gVgegLFhnGb3KQUSuN7zNuaaEFucRtmDM2wp4jb8WRHeMkc1P3k4ZTjcWPtX9Bm # Bob's address

# forge a shielded transaction from alice to bob that is saved to a file
mockup-client sapling forge transaction 10 from alice to zet142gVgegLFhnGb3KQUSuN7zNuaaEFucRtmDM2wp4jb8WRHeMkc1P3k4ZTjcWPtX9Bm using shielded-tez

# submit the shielded transaction from any transparent account
mockup-client sapling submit sapling_transaction from bootstrap2 using shielded-tez --burn-cap 1
mockup-client bake for bootstrap1
mockup-client sapling get balance for bob in contract shielded-tez

# unshield from bob to any transparent account
mockup-client sapling unshield 10 from bob to bootstrap1 using shielded-tez --burn-cap 1

mockup-client bake for bootstrap1
