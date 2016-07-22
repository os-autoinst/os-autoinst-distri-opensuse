# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;

use testapi;

sub run() {
    my ($self) = @_;

    # This test works onlywith CDMODEL=ide-cd due to windows missing scsi drivers which are installed via scsi iso
    if (get_var('UEFI')) {
        assert_screen 'windows-boot';
        send_key 'spc';    # boot from CD or DVD
    }
    assert_screen 'windows-setup', 60;
    send_key 'alt-n';      # next
    send_key 'alt-i';      # install Now
    send_key 'alt-n';      # next
    assert_screen 'windows-activate';
    send_key 'alt-i';      # I dont have the product key
    assert_screen 'windows-select-system';
    send_key 'alt-n';      # select OS (Win 10 Pro)
    assert_screen 'windows-license';
    send_key 'alt-a';      # accept eula
    send_key 'alt-n';      # next
    assert_screen 'windows-installation-type';
    send_key 'alt-c';      # custom
    assert_screen 'windows-disk-partitioning';
    send_key 'alt-l';      # load driver
    assert_screen 'windows-load-driver';
    send_key 'alt-b';      # browse button
    send_key 'c';
    send_key 'c';          # go to second CD drive with drivers
    send_key 'ret';        # ok
    send_key_until_needlematch 'windows-all-drivers-selected', 'shift-down', 5;    # select all drivers
    wait_still_screen;
    send_key 'alt-n';                                                              # next
    wait_still_screen;
    send_key 'alt-n';                                                              # next ->Installing windows!
    assert_screen 'windows-restart', 600;
    send_key 'alt-r';                                                              # restart
    assert_screen 'windows-first-boot', 1000;
    send_key 'alt-e';                                                              # use express settings button
    assert_screen 'windows-owner', 200;
    assert_and_click 'windows-next';                                               # no alt-n shortcut
    assert_and_click 'windows-local-active-directory';
    assert_and_click 'windows-next';                                               # no alt-n shortcut
    assert_screen 'windows-user', 60;
    send_key 'tab';                                                                # select user name
    type_string $realname;
    send_key 'tab';                                                                # go to password
    type_password;
    send_key 'tab';                                                                # go to password
    type_password;
    send_key 'tab';                                                                # go to hint (hint is important for windows)
    type_string 'security';
    wait_still_screen;
    send_key 'alt-n';                                                              # next
    assert_screen 'desktop-at-first-boot', 600;
    send_key 'super';                                                              # windows menu
    wait_still_screen;
    send_key 'up';
    wait_still_screen;
    send_key 'up';
    wait_still_screen;
    send_key 'spc';                                                                # press power button
    wait_still_screen;
    send_key 'up';
    wait_still_screen;
    send_key 'up';
    wait_still_screen;
    send_key 'spc';                                                                # press shutdown button
    assert_shutdown;
}

1;
# vim: set sw=4 et:
