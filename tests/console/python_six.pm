# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: this test checks "python-six" and "python3-six" packages.
#          Six provides simple utilities for wrapping over differences between Python 2 and Python 3. It is intended to support codebases that work on both Python 2 and 3 without modification.

# - Install test harness tappy, it can produce TAP format result in python testsuite.
# - data/python_six.py is a testsuite of 24 testcases, it tests various functions of python-six, including fundamental types, object model, syntax, modules and attributes etc.
# - In SUT, run python_six.py, and produce the result to a TAP format file.
# Maintainer: Shukui Liu <skliu@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run_test {
    my ($my_py)     = @_;
    my $tap_results = "results.tap";
    my $ret         = script_run("prove -ve $my_py python_six.py >> $tap_results");
    return $ret;
}

sub run {
    select_console 'root-console';
    zypper_call('install python-six python3-six');
    my $python_six_dir = "/home/bernhard/data/python_six";
    if (script_run("test -d $python_six_dir")) {    #dir does not exist.
        my $archive = "python_six.data";
        assert_script_run(
            sprintf "cd; curl -L -v %s/data/python_six > %s && cpio -id < %s && mv data python_six && ls python_six",
            autoinst_url(), $archive, $archive
        );
        assert_script_run("cd python_six");
    } else {
        assert_script_run("cd $python_six_dir");
    }
    if (is_sle('15+')) {
        zypper_call('install python2-pip python3-pip');
    } else {
        # tappy cannot be installed using easy_install on sle12(compile error appears randomly), so install pip.
        zypper_call('install python3');
        assert_script_run('python2 ./get-pip.py; python3 ./get-pip.py');
    }
    assert_script_run('pip2 install ./tap.py-2.6.2-py2.py3-none-any.whl; pip3 install ./tap.py-2.6.2-py2.py3-none-any.whl');
    run_test("python2");
    run_test("python3");
    my $tap_results = "results.tap";
    parse_extra_log(TAP => $tap_results);
}

1;
