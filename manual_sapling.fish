#!/usr/bin/fish
# alias mockup-client='/home/julian/Projects/tezos-v9/tezos-client --mode mockup --base-dir /tmp/mockup'
alias mockup-client='tezos-client --mode mockup --base-dir /tmp/mockup'

function contract_address
    mockup-client show known contract $argv
end

set first_bootstrap_addr "tz1KqTpEZ7Yob7QbPE4Hy4Wo8fHG8LhKxZSx"

set token_storage_ligo "record [
  total_supply = 100000000n;
  ledger = big_map[
    (\"$first_bootstrap_addr\" : address) -> record[
        balance = 10000000n;
        allowances = (map [] : map(address, nat)); 
    ];
  ];
]"

set token_storage_mich (ligo compile-storage ./contracts/main/TokenFA12.ligo main (echo $token_storage_ligo | string collect))

mockup-client originate contract token transferring 1 from bootstrap1 \
                        running ./contracts/compiled/TokenFA12.tz \
                        --burn-cap 10 --force \
                        --init (echo $token_storage_mich)

set token_address (contract_address token | string collect)
mockup-client bake for bootstrap1


# originate the contract with its initial empty sapling storage,
# bake a block to include it.
# { } represents an empty Sapling state.
# "Pair 0 {}" represents empty contract storage of type (int * sapling_state(8))
mockup-client originate contract shielded-tez transferring 0 from bootstrap1 running ./contracts/compiled/SaplingFA12.tz --init "Pair (Pair 0 { }) \"$token_address\"" --burn-cap 3 --force
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
mockup-client sapling shield 10 from bootstrap1 to zet136jcCiCfgqivY7kUmyQMJ8FtgKXHTAwu6Gc2m8SMNpcV3xM1z2bopgzke77LT2rqK using shielded-tez --burn-cap 2 
# mockup-client bake for bootstrap1
# mockup-client sapling get balance for alice in contract shielded-tez

# mockup-client transfer 0 from bootstrap1 to KT1JeCMyc69iRQuSP1DiXSVp9TcXjuCRzVce \
#     --arg "{ Pair (Pair 0x00000000000001f3c4d9116cfb1bcbcea90c65f99ecffe8ae2696e46a4a2a61fe40a5e7621207b498dec07a60d4bbd27101b9893029c75491fb603344ae84c55bcefcf50ee400ad2092b7d37fa8b3c59663adfe6dd9b0e49ac62c783fe57e59106486239cf779df1f3f0e459845aa5ea31bce9763a38754ccbdb99987f87d2f6af87c0ee5d2a7d8a011a3ec23cdf765f3199ed695ddabb5c71d9b37b35fbaa294f4ba8512bd392c770e29fef669028897b3706d545b9638cb0d611f4f6c9b5493414d8705c1538312cc7d1c414f08d8c9a855fe7b83248fa54282d4adbdd9b174452944b89c69d594e8950dc0ad2d6598a1fcb4eb450fe08a8a08ae7ff6bd8b3c3a41139fc741487258e67cc6df88a15330fe936917dd403570c5a194f4d89eeca1f480fc3fafc1e0000004ffe5b5dff614a7c1721b5cfc44ef8a9d77afc2ecf160bb7726a0072a56d96f8f4f0b801f83564c45cab3ec4742155e7691f91a6bc19a08287d895cf36ac13827365f4d09cb2759f922370fd76cbbad60af90572567a4d12fb547b6e261f8eabfac28c1b37a0f1204be5bb3f321995d2c7a27dfe05f00cdbc0327ac519159ace4229ff5dd014b89103123385f665825e3b6393d1a383d5f1f7be9e14b60bc6584e8d80d3fc4d2bbe3697e64a6c28d50390834e90c873bdb067259a83db502cb4590df8d5af5e1156603408ad150ad0333a3757da103226a2df17c62cdff2a8a2308681cd6ac4af71db549d1a3f8c882583540278467e42c6e32d0e412fc5395f52e86b316b8f25dc4e32e1501def6609ffffffffff676980fbc2f4300c01f0b7820d00e3347c8da4ee614674376cbc45359daa54f9b5493e None) 10000000 }" \
#     --dry-run

# generate an address for Bob to receive shielded tokens.
# mockup-client sapling gen address bob
# replace it with output of the previous command
# zet142gVgegLFhnGb3KQUSuN7zNuaaEFucRtmDM2wp4jb8WRHeMkc1P3k4ZTjcWPtX9Bm # Bob's address

# ---------------------
# forge a shielded transaction from alice to bob that is saved to a file
# mockup-client sapling forge transaction 10 from alice to zet13qnKJmZSyuD1gQjbwqVayCZx5yWqkZTUbUwkjKjQpcd6LcjoKBvs5dxk92faCrBFQ using shielded-tez

mockup-client transfer 0 from bootstrap2 to KT1JeCMyc69iRQuSP1DiXSVp9TcXjuCRzVce \
     --arg "{ Pair (Pair 0x0000016074810fd5ec0e8b7800c167bcc104fb5650ae2938ac5ab6dc6688a7f41929910b9bae02dba8f2e9b7ef3ee1fc7e64ed23f0d095d8ff2ce253396cf3add093ba1a4f5f42f22e2a47d2f507655d04db5cbaf5ae5cae4095d7da9d8010cfc1d3cda6921a3a0d27b10b7a35751b23eea848f67027f59fcb21e4fa03a9d1bc15ab0784b0ba5d797107292076217dee0188927a89ff81f409e0d592eefa32e2d1a9b356578f75c207187f5aa3c2017fe90b7cd2641b7bccb93116742eb5318e6f18797e1575f612a9e502c0721afb7a2f3d8ad3da447129c6ba0fca0438425b61332a847128667d155bba9ebd9b2226bbe5a5a5b58335c6b2e4921e5a5cf726b5b8fd4e0208c85007b49e3ad0024e372b8050795feb93dc53527ec427394e33b405747776f38582cbf3ba8b6056cd9ae3d033dde6658c2490dc0b7f197cc7379544065be8435451de2fdafd4712fff139760578fe592b926a3e4966617bc68f05d1c708000003e67a575efdcf7d627aa35042e6261c0d0ca42433f5d785e894594ca29293246837ad68fb37a6e6f85ff490c901d4d54e75a928e312a6abebd5ff685bbaf8f4623f12d399c3e9e11055dc433d4adb070817a93afb4eb3ca92698911e46312ac67524c107afb4eb0cb89fd6bfdc36465f2f803643a89a308ebc5915bbc33cf0feb55079aed2e15b3481674ca508ddec73d958fcd1a2a0e77b09375df7f02ff1bcc090c45694bb52a4b7bad8690b45d59cbdfb772c97e03e8a15e94d93ec4e2429779346314f88e28fab77b6942dcda5490ba56968799d770b9087132b373c4ab7e780b59918193aac8ed0f135e824e3220b8b3c00b071d9d8d16be2d8549e4d4058b8da03c8c4525c16c6761b00cd30c517407af019945043f973cac3792211246400000004f0aa8375264a89d9efb9cdab5c0afb0b3851477992f5b1ea526453071bd9f78705e79743da6ea7e31ad581a41a5be0e4d89bac72834bc6ad713e0f918140978647da31260ea166868e716293a2639b4a4b553f02db70aec0e548bdd5554804231910e883cb788e2cfb0141da5e7a85735bbc2ccc5acf4ce08a3f933e28655515c9ad32e1fe1ee18cc6e0f41d4ddbd80e9c3c22798f708f6bf131812606566fc5a55d26c1bff7abe9730072600dced95f9ff124571aee32cbd38e036dcbc07a1b503c7a984040285f15f29af8ffa059c212a79e500d82c934db7d61b972ebce09b4364ae7eedc80581f7695bf12d5111a1013dce5ce3a0112eb13cfce7a86243aeda2a9d19865a684ad95f440e05d51386fbfe782a472d3d00b9467cfc07dc45b96acfccd74d5aeb3d2af5da568805c8994f1703ab3beb097eb0e3d540d24893239125f09b72296f7d84489788ba7ec011cab24c1d8ee3214755617e4f79c39c178e48b56ee07e832300bc5934de05fb9678831c7b64ab3d9b90be22a98e801bae3cb878624319006f5d8871a0fc28a486407436ffff1fa7dc1575493272d51445fa4a3cd6c362f2d15ad93ee39fe085f9097a742bff5415a5ab91d88d0993e649dc8b8ec32376a101a49b34df88d703d68d3637503e13febb1b8ca4a6e53d3d6d29f6c2e5c6db3f3a8ff174c1a36ce10000004f7c7780f38da1b8c8ee97eb6f55f9fccecff70fcf8a27a020a9455facc973e9082b0dd53007110a32334539046a7df3958bb79ed01ee73a4f34147da2942ffe4d00cad55cb4fac96580cf22945e5dd36a97501f44c5ab9856cd231b8334b28de0a9f7914dad42e78bc1b37ec64273af89a67775c9a485c3980d29b04138b9a7671d454f73bc204ae171acd8bbb9f17f86a247db5b1187764d8d7ce862065b1bfbf6e539ae646e5e10fcdb24cbe0a87edc34808827082651c8866340df9ad7d1ac3212946fa780769f82adcb0da98201a3073a2deacae29eed0b7c6245342eb027c821a7c0d08c4f9549e6ba9340b742645c6dcc92f339a87af5fb53350e9bd9e88698cf57602feead5ebdef61bea3040000000000000000e4118e9b0599ba32e028d6e7669eee170083efd8282f15421becffd32a328a19 None) 0 }" \
 --dry-run --burn-cap 1

# # submit the shielded transaction from any transparent account
# mockup-client sapling submit sapling_transaction from bootstrap2 using shielded-tez --burn-cap 1
# mockup-client bake for bootstrap1
# mockup-client sapling get balance for bob in contract shielded-tez

# # unshield from bob to any transparent account
# mockup-client sapling unshield 10 from bob to bootstrap1 using shielded-tez --burn-cap 1

# mockup-client bake for bootstrap1
