# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;
use strict;

# test for basic function of aide. Check different between aide.db and file system
sub run() {
    my $self = shift;
    select_console 'root-console';
    validate_script_output "zypper -n in aide", sub { m/(Installing.*)|(.*already installed)/ };
    assert_script_run "cp /etc/aide.conf /etc/aide.conf.bak";
    assert_script_run "sed -i \'s/^\\//!\\//\' /etc/aide.conf && sed -i \'s/^!\\/var\\/log/\\/var\\/log/\' /etc/aide.conf";
    assert_script_run "aide -i";
    assert_script_run "cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db";
    assert_script_run "aide --check";
    assert_script_run "touch /var/log/testlog";
    assert_script_run "clear";
    script_run "aide --check";
    assert_screen "aide_result";
    assert_script_run "mv /etc/aide.conf.bak /etc/aide.conf && rm /var/log/testlog";
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
