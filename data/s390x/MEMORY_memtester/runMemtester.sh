# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

LOGFILE="logfile_memtester"
memtester $@ >$LOGFILE
cat $LOGFILE | sed "s/\(testing\|setting\)[ ]*[0-9]*//g" | sed "s/.\x08//g" | sed "s/:[ ]*\(.*\)/: \1/g"
