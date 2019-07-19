# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot kiwi live or oem image
# - at bootloader screen, manipulate grub to stop timeout
# - checks if imagem is based on old kiwi and is oem type
# - in this case, press down key 16 times and accept option (hard drive, not
# ramdisk)
# - confirm installation procedure and wait for login screen
# - if not old kiwi & oem, just press ENTER and wait for login screen
# Maintainer: Ednilson Miura <emiura@suse.com>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils "is_sle";

sub run {
    my $install_type = get_var('KIWI_OLD');
    my $iso_name     = get_var('ISO');
    # bootloader screen is too fast to openqa
    sleep(10);
    send_key 'down';
    send_key 'up';
    # perl kiwi oem installer does not work correctly on non interactive
    if (($install_type == 1) && ($iso_name =~ /OEM/)) {
        assert_screen('kiwi_boot', 15);
        send_key 'ret';
        # choose last option on installer screen
        assert_screen('kiwi_oem_install_installer', 300);
        my $count = 0;
        while ($count < 16) {
            send_key 'down';
            $count++;
        }
        sleep 2;
        send_key 'spc';
        send_key 'ret';
        assert_screen('kiwi_oem_install_confirm', 1200);
        send_key 'ret';
        assert_screen('linux-login', 1200);
    }
    else {
        assert_screen('kiwi_boot', 15);
        send_key 'ret';
        assert_screen('linux-login', 1000);
    }
}
1;
