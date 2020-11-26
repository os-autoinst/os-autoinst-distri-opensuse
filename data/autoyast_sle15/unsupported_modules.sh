#!/bin/bash

set -e -x
[[ -n $(zgrep -l\
            'Could not process these unsupported profile sections: \["autofs", "restore"\]'\
        /var/log/YaST2/y2log*) \
]] && echo "AUTOYAST OK"
