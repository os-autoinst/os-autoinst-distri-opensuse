import pysample_package

print(pysample_package.__version__)
#print(pysample_package.__author__)

from pysample_package import mymodule
mymodule.greet("Ram")
mymodule.print_hello()
