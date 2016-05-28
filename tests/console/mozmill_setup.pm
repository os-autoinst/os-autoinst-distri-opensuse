# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;
use utils;

# http://mozmill-crowd.blargon7.com/#/functional/reports

sub run() {
    my $self = shift;
    script_sudo("zypper -n in gcc python-devel python-pip mercurial curlftpfs");
    assert_screen 'test-mozmill_setup-1', 3;
    clear_console;

    #script_sudo("pip install mozmill mercurial");
    script_sudo("pip install mozmill mercurial");

    #script_sudo("pip install mozmill==1.5.3 mercurial");
    sleep 5;
    wait_idle 50;
    assert_screen 'test-mozmill_setup-2', 3;
    clear_console;
    script_run("cd /tmp");    # dont use home to not confuse dolphin test
    script_run("wget -q openqa.opensuse.org/opensuse/qatests/qa_mozmill_setup.sh");
    script_run("sh -x qa_mozmill_setup.sh");
    sleep 9;
    wait_idle 90;
    wait_serial("qa_mozmill_setup.sh done", 120) || die 'setup failed';
    save_screenshot;
}

1;
# vim: set sw=4 et:
