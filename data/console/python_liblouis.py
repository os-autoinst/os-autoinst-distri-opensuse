import louis

ctb_file = 'en-ueb-g1.ctb'

with open("braille_result_lowercase.txt", 'w') as braille_result_lowercase:
  print(louis.translate(["unicode.dis",ctb_file], "abcdefghijklmnopqrstuvwxyz")[0], file=braille_result_lowercase)

with open("braille_result_uppercase.txt", 'w') as braille_result_uppercase:
  print(louis.translate(["unicode.dis",ctb_file], "ABCDEFGHIJKLMNOPQRSTUVWXYZ")[0], file=braille_result_uppercase)

symbols = ' !"#$%()*+-./:;<=>?@[\\]_{}~123456790'+"'"
with open("braille_result_symbols.txt", 'w') as braille_result_symbols:
  print(louis.translate(["unicode.dis",ctb_file], symbols)[0], file=braille_result_symbols)
