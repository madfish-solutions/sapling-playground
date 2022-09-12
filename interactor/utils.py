from decimal import Decimal

def mock_tez_amount(amount):
    return str(Decimal(amount) / Decimal(1e6))


def extract_sapling_parameter_from_error(message):
    pos = message.index("Parameter:")
    length_plus_spaces = 13
    rest = message[pos + length_plus_spaces:]
    end = rest.index("}") - 1

    param = rest[:end]
    return param

def extract_generic_error(message):
    pos = message.rfind("rror:") # intentionally skipped `e`
    start = pos + 7
    end = message[start:].find("\n\n")
    return message[start:start + end]

def find_nth(haystack, needle, n):
    start = haystack.find(needle)
    while start >= 0 and n > 1:
        start = haystack.find(needle, start+len(needle))
        n -= 1
    return start

def calc_pool_in_given_single_out(
        token_pool_out,
        pool_supply,
        token_amount_out,
    ):
        normalized_weight = Decimal(0.5)
        swap_fee = Decimal(0.003)
        # charge swap fee on the output token side 
        #t_ao_before_swap_fee = t_ao / (1 - (1-weight_to) * swap_fee) 
        zoo = 1 - normalized_weight
        zar = zoo * swap_fee
        token_amount_out_before_swap_fee = token_amount_out / (1 - zar)

        new_token_pool_out = token_pool_out - token_amount_out_before_swap_fee
        token_out_ratio = new_token_pool_out / token_pool_out

        #new_pool_supply = (ratio_to ^ weight_to) * pool_supply
        pool_ratio = pow(token_out_ratio, normalized_weight)
        new_pool_supply = pool_ratio * pool_supply
        pool_amount_in = pool_supply - new_pool_supply

        return pool_amount_in