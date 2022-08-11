#!/bin/bash -e
# COPY and RUN this script in a container image, to:
# create a python virtualenv named as test_$1,
# pip install the modules provided as parameters from $2 on,
# collect the resulting dependencies in a resource_$1.txt file
# copy the txt in a common dir.
# --- 
# $1 CLI Cloud type: aws, azure, ec2, openstack
# $2 resources output file
# $3,... : install modules
# ---

echo $0 $*

MINPAR=2
# parameters check
if [ $# -lt $MINPAR ]
then
    echo "Parameters missing in $@"
    exit 1
fi

# create venv
VENV_CLOUD=test_$1

RESOURCE_FILE=resources_$1.txt

virtualenv $VENV_CLOUD; 

cd $VENV_CLOUD; 

# activate venv
source bin/activate;

# Versions in venv
python3 --version
pip --version

shift 1 # remove 1 used param from $@

# install the modules
pip install $@

# collect the resulting modules and versions
pip freeze > $RESOURCE_FILE; 

#deact. venv
deactivate

# copy file in parent dir
cp $RESOURCE_FILE .. 

# file exists and size>0
if [ ! -s ../$RESOURCE_FILE ]
then
    echo "Resource file $(pwd)/../$RESOURCE_FILE error"
    exit 2
fi