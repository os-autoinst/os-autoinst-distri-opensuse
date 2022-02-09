import louis

with open("braille_result1.txt", 'w') as braille_result1:
  print(louis.translate(["unicode.dis","en-chardefs.cti"], "abcdefghijklmnopqrstuvwxyz")[0], file=braille_result1)

with open("braille_result2.txt", 'w') as braille_result2:
  print(louis.translate(["unicode.dis","en-chardefs.cti"], "ABCDEFGHIJKLMNOPQRSTUVWXYZ")[0], file=braille_result2)

symbols = ' !"#$%()*+-./:;<=>?@[\]_{}~123456790'+"'" 
with open("braille_result3.txt", 'w') as braille_result3:
  print(louis.translate(["unicode.dis","en-chardefs.cti"], symbols)[0], file=braille_result3)
