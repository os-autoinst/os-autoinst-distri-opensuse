#!/bin/bash

# Check if all users has some value in the password field
# (bsc#973639, bsc#974220, bsc#971804 and bsc#965852)

set -e -x

# It's OK if we DO NOT find a blank password.
getent shadow | grep --extended-regexp "^[^:]+::" || echo "AUTOYAST OK"
