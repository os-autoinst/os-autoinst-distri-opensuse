#!/usr/bin/perl -w
use strict;
use base "serverstep";
use bmwqemu;

sub run() {
    my $self = shift;

    # Install apache2
    script_sudo("zypper -n -q in mysql");
    wait_idle 10;

    # After installation, mysql is disabled
    script_sudo("systemctl status mysql.service | tee /dev/ttyS0 -");
    wait_idle 5;
    die unless wait_serial ".*inactive.*", 2;

    # Now must be enabled
    script_sudo("systemctl start mysql.service");
    script_sudo("systemctl status mysql.service | tee /dev/ttyS0 -");
    wait_idle 5;
    die if wait_serial ".*Syntax error.*", 2;

    assert_screen 'test-mysql_srv-1', 3;
}

1;
# vim: set sw=4 et:
