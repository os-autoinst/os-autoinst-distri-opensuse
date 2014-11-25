#!/usr/bin/perl -w
use strict;
use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    # Install apache2
    script_sudo("zypper -n -q in mysql", 10);

    # After installation, mysql is disabled
    script_sudo("systemctl status mysql.service | tee /dev/ttyS0 -", 5);
    wait_serial ".*inactive.*", 2;

    # Now must be enabled
    script_sudo("systemctl start mysql.service", 10);
    script_sudo("systemctl status mysql.service | tee /dev/ttyS0 -", 5);
    wait_serial(".*Syntax error.*", 2, 1) || die "have error while starting mysql";

    assert_screen 'test-mysql_srv-1', 3;
}

1;
# vim: set sw=4 et:
