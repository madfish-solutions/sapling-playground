from termios import B0
from z3 import *

x = Int('x')
y = Int('y')


# z = total_supply
# a = token_a_pool
# b = token_b_pool

z = Int("z")
t = Int("t")
p = Int("p")
x0 = Int("x0")
x1 = Int("x1")
y0 = Int("y0")
y1 = Int("y1")
a0 = Int("a0")
a1 = Int("a1")
b0 = Int("b0")
b1 = Int("b1")

# p, t, z, x0, x1, y0, y1, a0, a1, b0, b1 = var("p, t, z, x0, x1, y0, y1, a0, a1, b0, b1")

# invest
# solve([
#     x1 == x0-x,
#     y1 == y0+(x*997*b0)/(a0*1000+x),
#     a1 == a0+x,
#     b1 == b0-(x*997*b0)/(a0*1000+x),
#     x1/y1 == a1/b1,
#     x1 == z*a1/t,
#     y1 == z*b1/t,
#     y0 == 0,
# ], x, x1, y1, a1, b1, x0, y0)

# divest
# solve([
#     x1 == x0-x,
#     y1 == y0+(x*997*b0)/(a0*1000+x),
#     a1 == a0-x0,
#     b1 == b0-y0,
#     x1 == z*a0/t,
#     y1 == z*b0/t,
#     y0 == 0,
# ], x, x1, y1, a1, b1, x0, y0)
