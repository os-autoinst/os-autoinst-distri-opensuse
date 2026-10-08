#!/bin/bash
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test to check that the logs with the custom error level are inserted
# in the journal
# Maintainer: Ivan Lausuch <ilausuch@suse.de>

code=$(date +%s)
logger -p $1 -t Test "This message comes from $USER $code"

sleep 1
retries=3

while [ $(journalctl -r --no-pager --since "1 minute ago"  | grep $code | wc -l) -eq 0 -a $retries -gt 0 ]; do
  sleep 1
  retries=$(expr $retries - 1)
done

echo -n "TEST logger & journalctl - "
if [ $retries -eq 0 ]; then
  echo "ERR"
  exit 1
else
  echo "OK"
  exit 0
fi
