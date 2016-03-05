# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


## TEST BEHAVIOUR-DESCRIPTION:
# testing the undochange snapper function.
# we create a snapshot, without a testfile.
# we create a file with some text,  then undochange function with snapper-undochange.
# and assert that file exist or not, in both situation


use base "consoletest";
use strict;
use testapi;

sub run() {
    select_console 'root-console';

    # snapper undochange [options] number1..number2 [files] return -> numb snapshot created

    # create the 2 snapshots, inbetweeen create the file. then go back when file doesn't exist
    type_string('before_snap=$(snapper create -p -d \'before undochange test\');');
    type_string('snapfile="/root/test_snapfile";date > $snapfile; after_snap=$(($before_snap + 1));');
    assert_script_run('test -f $snapfile');
    type_string('snapper create -p -d \'after undochange test\';');
    type_string('snapper undochange $before_snap..$after_snap $snapfile;');
    type_string('snapper list; ls /root;');

    # file shouldn't exist, after undochange. test it.
    assert_script_run('test ! -f $snapfile');

    # go back when file exist and test it.
    type_string('snapper undochange $after_snap..$before_snap $snapfile;');
    assert_script_run('test -f $snapfile');

    assert_screen('snapper_undochange');
}

sub test_flags() {
    return {important => 1};
}

1;
