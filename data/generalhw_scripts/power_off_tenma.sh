#!/bin/sh

echo "Powering OFF"

# Update path where https://github.com/kxtells/tenma-serial is cloned
tool_path=/tmp/tenma-serial/tenma
device=/dev/ttyACM0

pushd $tool_path/
python tenmaControl.py --off $device
popd
