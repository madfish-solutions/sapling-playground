token_a_pool = 10000
token_b_pool = 10000
total_supply = 10000

shares_to_buy = 200
proportion = 500 # 1:1
PROPORTION_DENOM = 1000 


# 250 x 250

def swap(amount_in, from_pool, to_pool):
    in_net_fee = amount_in * 997
    numerator = in_net_fee * to_pool
    denominator = from_pool * 1000 + in_net_fee

    out = numerator // denominator

    from_pool = from_pool + amount_in;
    to_pool = abs(to_pool - out);

    return (out, from_pool, to_pool)

out, token_a_pool, token_b_pool = swap(2096, token_a_pool, token_b_pool)
print("out", out)
print("token_a_pool", token_a_pool)
print("token_b_pool", token_b_pool)


# out, token_a_pool_0, token_b_pool_0 = swap(9974, token_a_pool, token_b_pool)
# invest_a = shares_to_buy * token_a_pool_0 // total_supply
# invest_b = shares_to_buy * token_b_pool_0 // total_supply
# print("first_out", out)
# print("invest_a", invest_a)
# print("invest_b", invest_b)

# token_a_pool_1 = token_a_pool_0 + invest_a
# token_b_pool_1 = token_b_pool_0 + invest_b

# divest_a = token_a_pool * shares_to_buy // total_supply
# divest_b = token_b_pool * shares_to_buy // total_supply
# token_a_pool_2 = token_a_pool_1 - divest_a
# token_b_pool_2 = token_b_pool_1 - divest_b
# out, token_a_pool_3, token_b_pool_3 = swap(divest_a, token_a_pool_2, token_b_pool_2)
# print("out", out)
# print("token_a_pool_3", token_a_pool_3)
# print("token_b_pool_3", token_b_pool_3)

# exit(0)

# import math
# a0 = token_a_pool
# b0 = token_b_pool
# x0 = 500
# y0 = 500

# x = (a0*b0**2*x0 + a0*b0*x0*y0 - (a0**2 + a0*x0)*y0*math.sqrt((a0*b0**2 + a0*b0*y0)/(a0 + x0)))/(a0*b0**2 + a0*b0*y0 + (a0*b0 + b0*x0 + (a0 + x0)*y0)*math.sqrt((a0*b0**2 + a0*b0*y0)/(a0 + x0)))

# x=round(x)

# out, token_a_pool, token_b_pool = swap(x, token_a_pool, token_b_pool)

# print("amount_in: ", x0 - x)
# print("out: ", y0 + out)
# print("token_a_pool: ", token_a_pool)
# print("token_b_pool: ", token_b_pool)

# print("ratio of ins", (x0 - x)/(y0 + out))
# print("ratio of pool", token_a_pool/token_b_pool)

# exit(0)

#######################################################

# import math
# a0 = token_a_pool
# b0 = token_b_pool
# p = 0.5
# t = total_supply
# z = shares_to_buy

# x0 = 1/2*((b0*p + a0)*t + math.sqrt(8*a0*b0*p*t*z + 4*a0*b0*p*z**2 + (b0**2*p**2 + 2*a0*b0*p + a0**2)*t**2))/t
# y0 = 1/2*((b0*p + a0)*t + math.sqrt(8*a0*b0*p*t*z + 4*a0*b0*p*z**2 + (b0**2*p**2 + 2*a0*b0*p + a0**2)*t**2))/(p*t)

# x = 1/2*((b0*p + a0)*t + 2*a0*z + math.sqrt(8*a0*b0*p*t*z + 4*a0*b0*p*z**2 + (b0**2*p**2 + 2*a0*b0*p + a0**2)*t**2))/(t + z)

# y, token_a_pool, token_b_pool = swap(x, token_a_pool, token_b_pool)

# print("asked token a:", x0)
# print("asked token b:", y0)

# x1 = x0 - x
# y1 = y0 + y

# print("investing x1", x1)
# print("investing y1", y1)

# token_a_pool += x1
# token_b_pool += y1
# total_supply += z

# print("swapped", x, "token a for", y, "token b")
# print("token_a_pool: ", token_a_pool)
# print("token_b_pool: ", token_b_pool)
# print("total_supply: ", total_supply)

# print("would have a divested", token_a_pool * z // total_supply)
# print("would have b divested", token_b_pool * z // total_supply)

# exit(0)
import math
a0 = 10_000 
b0 = 10_000
t = 10_000
z = 10_000

x0 = (1997*a0*t*z - a0*z**2)/(997*t**2 - t*z)

exit(0)

import math
a0 = 10_000 
b0 = 10_000
t = 10_000
z = 10_000

# y0 = (2*b0*t*z + b0*z**2)/t**2
y0 = (1997*b0*t*z + 1996*b0*z**2)//(1000*t**2 + 999*t*z)
sold_token_pool = token_b_pool
requested_shares = z

tokens_to_ask = (1997 * sold_token_pool * total_supply * requested_shares + 1996 * sold_token_pool * requested_shares ** 2) // (1000 * total_supply ** 2 + 999 * total_supply * requested_shares)


print("tokens_to_ask",tokens_to_ask )
print("y0", y0)


# print("y0", y0)
# print("token_a_pool: ", token_a_pool)
# print("token_b_pool: ", token_b_pool)

exit(0)

# divest
x1 = (1997*a0*t*z + a0*z^2)/(997*t^2 + t*z)

# calculations
token_a_invest = shares_to_buy * proportion // PROPORTION_DENOM
token_b_invest = shares_to_buy - token_a_invest

ideal_a_invest = shares_to_buy * token_a_pool // total_supply
ideal_b_invest = shares_to_buy * token_b_pool // total_supply

ideal_b_invest = 664
ideal_a_invest = shares_to_buy - ideal_b_invest
# import math
# a = token_a_pool
# b = token_b_pool

# x = 1/2 * (-a ** 2 - math.sqrt(a**4 + 2 * a**3 * b + a**2 * b**2 + 400) - a * b)

# print(x)

# exit(0)

a_delta = token_a_invest - ideal_a_invest
b_delta = token_b_invest - ideal_b_invest

print("a_delta: ", a_delta)
print("b_delta: ", b_delta)

# TODO ignore zero deltas

should_sell_a = abs(a_delta) < abs(b_delta)

if should_sell_a:
    amount_in = abs(a_delta)
    out, token_a_pool, token_b_pool = swap(amount_in, token_a_pool, token_b_pool)
    token_a_invest += out
    token_b_invest -= amount_in
else:
    amount_in = abs(b_delta)
    out, token_b_pool, token_a_pool = swap(amount_in, token_b_pool, token_a_pool)
    token_a_invest -= amount_in
    token_b_invest += out

print("amount_in: ", amount_in)
print("out: ", out)
print("token_a_pool: ", token_a_pool)
print("token_b_pool: ", token_b_pool)
print("token_a_invest: ", token_a_invest)
print("token_b_invest: ", token_b_invest)