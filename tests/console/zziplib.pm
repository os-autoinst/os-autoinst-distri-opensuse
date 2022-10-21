# SUSE"s openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libzzip-0-13 zziplib-devel zip
# Summary: test that uses zip command line tool to regression test.
# If succeed, the test passes without error.
# - Add SDK repository if necessary (devel package necessary for test)
# - Create a temp dir, copy files from /usr/share/doc to it
# - Compress all the files on temp dir in zip file
# - List zip file contents using unzip-mem -l
# - List zip file contents using unzip-mem -v
# - List zip file contents using unzip-mem -t
# - Unzip file using unzzip
# - Cleanup files
# Maintainer: Marcelo Martins <mmartins@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use registration qw(cleanup_registration register_product add_suseconnect_product get_addon_fullname remove_suseconnect_product);
use version_utils 'is_sle';

sub run {
    my $filezip = "files.zip";
    select_serial_terminal;

    # development module needed for dependencies, released products are tested with sdk module
    if (!main_common::is_updates_tests()) {
        cleanup_registration;
        register_product;
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product(get_addon_fullname('sdk'));
    }
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
    # unregister SDK
    if (!main_common::is_updates_tests()) {
        remove_suseconnect_product(get_addon_fullname('sdk'));
    }
}

1;
