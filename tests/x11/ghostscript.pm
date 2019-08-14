# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
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
# - Launch a xterm
# - Stop packagekit service
# - Install ghostscript ghostscript-x11 and gv
# - Download test files from datadir
# - Run "ghostscript_ps2pdf.sh"
# - Upload log results
# - Check a reference pdf
# - Close gv
# - Cleanup
# Maintainer: Dario Abatianni <dabatianni@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console "x11";
    x11_start_program('xterm');

    # become root, disable packagekit and install all needed packages
    become_root;
    pkcon_quit;
    zypper_call "in ghostscript ghostscript-x11";

    # special case for gv which is not installed on all flavors
    my $gv_missing = zypper_call("in gv", exitcode => [0, 104]);

    # Remove known failing test file poo#41393/bsc#1109788
    my $excluded_file = "/usr/share/ghostscript/9.25/examples/transparency_example.ps";
    my $file_status   = script_run("ls $excluded_file");
    unless ($file_status) {
        record_soft_failure("bsc#1109788");
        assert_script_run("rm $excluded_file");
    }

    # exit root shell
    type_string "exit\n";

    my $gs_script = "ghostscript_ps2pdf.sh";
    my $gs_log    = "ghostscript.log";
    my $gs_failed = "/tmp/ghostscript_failed";
    my $reference = "alphabet.pdf";

    # download ghostscript converter script and test if download succeeded
    assert_script_run "wget " . data_url("ghostscript/$gs_script");
    assert_script_run "test -f $gs_script";
    assert_script_run "test -s $gs_script";

    # convert example *.ps files to *.pdf
    assert_script_run "sh ./$gs_script";

    # show the resulting logfile onthe screen for reference and upload logs
    script_run "cat $gs_log";
    upload_logs $gs_log;

    # check if there was an error during the pdf generation
    assert_script_run "test ! -f $gs_failed";

    # display one reference pdf on screen and check if it looks correct
    # skip this when there is no gv installed
    if (!$gv_missing) {
        script_run "gv $reference", 0;
        assert_screen "ghostview_alphabet";

        # close gv
        send_key "alt-f4";
        wait_still_screen;
    }

    # cleanup temporary files
    script_run "rm -f $gs_log $reference $gs_script";

    # close xterm
    send_key "alt-f4";
}

1;

