#! /bin/bash

echo 'PAPI: cloning'

git clone https://bitbucket.org/icl/papi.git

echo 'PAPI: cloning done'

cd ./papi/src

echo 'PAPI: configure'

./configure

echo 'PAPI: configure done'

echo 'PAPI: make'

make

echo 'PAPI: make done'

cd examples

echo 'PAPI: make examples'

make

echo 'PAPI: make examples done'

echo 'PAPI: run example'

./PAPI_hw_info
