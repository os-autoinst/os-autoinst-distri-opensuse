# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package windows_utils;

use base Exporter;
use Exporter;

use strict;
use warnings;

use testapi;

our @EXPORT = qw(wait_boot_windows);

# makes sure splash screen appears and then boots to desktop
# arguments: bootloader_time => seconds # now long to wait for splash to appear
sub wait_boot_windows {
    my %args            = @_;
    my $bootloader_time = $args{bootloader_time} // 100;

    assert_screen 'windows-screensaver', 600;

    # Reset the consoles after the reboot: there is no user logged in anywhere
    reset_consoles;

    send_key 'esc';    # press shutdown button

    assert_screen 'windows-login';
    type_password;
    send_key 'ret';    # press shutdown button

    assert_screen 'windows-desktop', 120;
}

1;
