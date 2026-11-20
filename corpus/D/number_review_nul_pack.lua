-- surface: NUL bytes in an integer pack result found by review 3
print(string.pack('i4', 3.0):len())
