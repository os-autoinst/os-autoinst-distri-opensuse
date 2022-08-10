#!/bin/bash
# COPY and RUN this script in a container image, to:
# create a python virtualenv named as $1,
# pip install the modules provided as parameters from $2 on,
# collect the resulting dependencies in a resource_$1.txt file
# copy the txt in a common dir.
# --- 
# $1 CLI Cloud type: aws, azure, ec2, openstack
# $2 resources output file
# $3,... : install modules
# ---

echo $0 $*

# parameters check
[ $# -lt 3 ] && exit 1

# create venv
CLOUD=$1
FILE=$2

virtualenv test_$CLOUD; 

cd test_$CLOUD; 

# activate venv
source bin/activate;

# Versions in venv
python3 --version
pip --version

# install the modules
shift 2 # remove 2 used param
pip install $@

# install result
[ $? -ne 0 ] && exit 2

# collect the resulting modules and versions
pip freeze > $FILE; 

#deact. venv
deactivate

# copy file in parent dir
cp $FILE .. 

cd ..
