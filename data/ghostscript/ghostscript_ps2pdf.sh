#!/bin/bash

# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add ghostscript test 
#    This test downloads a script that converts all the .ps images in 
#    the examples to .pdf files. If one (or more) were not converted
#    then a file called failed is created and the test fails. Also it
#    will display one of the generated PDFs to see if gv works.
# Maintainer: Dario Abatianni <dabatianni@suse.de>

tempfolder="ghostscript_test"
log="ghostscript.log"
failed="/tmp/ghostscript_failed"
reference="alphabet.pdf"

mkdir $tempfolder
cd $tempfolder

# timestamp the start of the logfile
date > $log

# run through all of the example *.ps files in the ghostscript folder
version=`gs --version`
for i in `find /usr/share/ghostscript/$version/examples/*.ps -type f`
do
  # convert all *.ps files to *.pdf files in the current temporary folder
  echo Running ps2pdf $i ... >> $log

  # in case converting of one file fails, add a "failed" marker file
  ps2pdf $i 2>> $log || touch $failed
done

# timestamp the end of the logfile
date >> $log

# list the final files (for reference on the screenshot)
ls -l .
cd -

# check if our gv reference pdf is there, exit if not
test -f $tempfolder/$reference || exit 2

# move the logfile and the reference one folder down
mv $tempfolder/$log $tempfolder/$reference .

# clean up temporary folder
rm -f $tempfolder/*
rmdir $tempfolder

