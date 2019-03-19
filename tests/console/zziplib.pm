# SUSE"s openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test that uses zip command line tool to regression test.
# If succeed, the test passes without error.
#
# Maintainer: Marcelo Martins <mmartins@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $filezip = "files.zip";
    select_console "root-console";
    # create a tmp dir/files to work
    assert_script_run "mkdir /tmp/zip; cp /usr/share/doc/* /tmp/zip -R";
    assert_script_run "cd /tmp";

    # install requirements
    zypper_call "in libzzip-0-13 zziplib-devel zip";

    # create a zip file
    assert_script_run "zip -9 $filezip -xi zip/*";
    # Use unzip-mem on zip file to list archived files (-l)
    assert_script_run "unzip-mem -l $filezip";

    # Use unzip-mem on zip file to get a verbose list archived files (-v)
    # Option -v  creates a core dump(bsc#1129403), create a soft-failure
    my $RETURN_CODE = script_run("unzip-mem -v $filezip");
    if (($RETURN_CODE) eq "0") {
        assert_script_run("unzip-mem -v $filezip");
    } else {
        record_soft_failure "bsc#1129403 - Option -v creates a core dump";
        save_screenshot;
    }
    # Use unzip-mem on zip file to list archived files (-t)
    assert_script_run "unzip-mem -t $filezip";
    # Use unzip on archive to extract the files
    assert_script_run "unzzip $filezip";
    #Clean files used:
    assert_script_run "cd ; rm -rf /tmp/zip ; rm /tmp/$filezip";
}

1;
