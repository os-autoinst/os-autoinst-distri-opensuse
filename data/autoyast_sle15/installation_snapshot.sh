#!/bin/bash

set -e -x

# It is enough to check the return value in order to check if
# snapper has been set up correctly.
snapper list && echo "AUTOYAST OK"
