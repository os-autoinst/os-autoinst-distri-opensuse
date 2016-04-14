#!/bin/bash

set -e -x

lvs
pvs
vgs

mount 

mount |grep -i "root_lv on /" && echo "AUTOYAST OK"
