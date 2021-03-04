#!/bin/bash

# Dump kiwi obs page, dump build status and check for failures
curl -k https://build.suse.de/project/monitor/QA:Maintenance:Images:$1:$2 | grep tbody | sed 's/&quot//g' | tr -d \'\; | sed -n 's/\(data-statushash={.*}\)/@\1@/p' | cut -d "@" -f 2 | tr { '\n' | grep package: | sed 's/package:\(test-image.*\),code:\(.*\)}.*/\1 \2/' | tr -d } > $3
if grep -q failed $3; then
    echo "KIWI build failed, check $3"
    exit 1
fi
echo "KIWI build successfully finished"
exit 0


