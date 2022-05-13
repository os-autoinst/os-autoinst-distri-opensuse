# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1479221: Firefox: HTML5
# - Launch xterm, install python and selenium
# - Open opensuse html5 test page
# - Access various page elements and check results
# - Close
# Maintainer: vanastasiadis <vasilios.anastasiadis@suse.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console "x11";
    x11_start_program('xterm');
    
    # prepare python + selenium
    become_root;
    quit_packagekit;
    zypper_call("in python3");
    enter_cmd "exit";
    assert_script_run("pip3 install selenium");
    assert_script_run "mkdir temp_selenium && cd temp_selenium";
    assert_script_run "wget https://github.com/mozilla/geckodriver/releases/download/v0.30.0/geckodriver-v0.30.0-linux64.tar.gz && tar -xf geckodriver-v0.30.0-linux64.tar.gz";
    assert_script_run "export PATH=\"\$(pwd):\$PATH\"";
    assert_script_run "wget --quiet " . data_url('selenium/selenium_html5.py')     . " -O selenium_html5.py";

    # run selenium script, parse results and upload logs
    assert_script_run "python3 selenium_html5.py >&1 | tee selenium_output.txt ";
    my $res = script_output("cat selenium_output.txt");
    my @errs = ();
    foreach my $line (split(/\n/, $res)) {
        if (index($line, 'FAIL') != -1) {
            my ($match) = $line =~ /\[\[ ( (?:(?!\]\]).)* ) \]\]/x;
            push (@errs, $match);
        }
    }
    upload_logs('geckodriver.log', log_name => 'html5-geckodriver-log.txt');
    upload_logs('selenium_output.txt', log_name => 'html5-selenium-results.txt');
    if (@errs){
        my $errors = join(" | ", @errs);
        die "$errors";
    }
}
1;
