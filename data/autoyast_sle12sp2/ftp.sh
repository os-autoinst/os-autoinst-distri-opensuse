#!/bin/bash

set -e -x

echo test > test.txt
curl -T test.txt ftp://localhost/ --user anonymous:anystring
curl ftp://localhost/test.txt > test2.txt

diff -u test.txt test2.txt && echo "AUTOYAST OK"
