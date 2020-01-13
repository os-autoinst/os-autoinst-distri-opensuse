#!/bin/sh

echo "Powering ON"

# Update path where https://github.com/kxtells/tenma-serial is cloned
tool_path=/tmp/tenma-serial/tenma
device=/dev/ttyACM0

current_ma=3100 # 3.1A
voltage_mv=5000 # 5V

pushd $tool_path/
python tenmaControl.py -c $current_ma -v $voltage_mv --verbose  $device # Set voltage and max current
python tenmaControl.py --on $device # Switch ON
popd
