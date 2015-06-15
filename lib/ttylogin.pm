#!/usr/bin/perl -w

package ttylogin;

use base Exporter;
use Exporter;

use strict;

use testapi;

our @EXPORT = qw/ttylogin/;

sub ttylogin {

    my $ttynr = shift || '4';
    my $user = shift || $username;
    # log into text console
    send_key "ctrl-alt-f$ttynr";
    # we need to wait more than five seconds here to pass the idle timeout in
    # case the system is still booting (https://bugzilla.novell.com/show_bug.cgi?id=895602)
    assert_screen "tty$ttynr-selected", 10;
    assert_screen "text-login", 10;
    type_string "$user\n";
    if (!get_var("LIVETEST")) {
        assert_screen "password-prompt", 10;
        type_password;
        type_string "\n";
    }
    assert_screen "text-logged-in", 10;
}

1;

# vim: sw=4 et
