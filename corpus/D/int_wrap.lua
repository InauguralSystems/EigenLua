-- surface: integers overflow wraparound
print(math.maxinteger + 1)
print(math.maxinteger + 1 == math.mininteger)
print(math.mininteger - 1)
print(math.mininteger - 1 == math.maxinteger)
print(math.maxinteger * 2)
print(-math.mininteger)
