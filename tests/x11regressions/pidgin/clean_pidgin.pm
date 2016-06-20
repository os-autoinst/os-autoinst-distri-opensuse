# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

# Cleaning for testing pidgin
sub remove_pkg() {
    my $self     = shift;
    my @packages = qw/pidgin/;
    x11_start_program("xterm");

    # Remove packages
    type_string "xdg-su -c 'rpm -e @packages'\n";
    sleep 3;
    if ($password) {
        type_password;
        send_key "ret";
    }
    sleep 30;    # give time to uninstall
    type_string "clear\n";
    sleep 2;
    type_string "rpm -qa @packages\n";
    assert_screen "pidgin-pkg-removed";    #make sure pkgs removed.

    type_string "exit\n";
    sleep 2;
}

sub run() {
    my $self = shift;
    remove_pkg;
}

1;
# vim: set sw=4 et:
