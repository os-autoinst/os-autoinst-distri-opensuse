# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Windows 10 installation test module
#    modiffied (only win10 drivers) iso from https://fedoraproject.org/wiki/Windows_Virtio_Drivers is needed
#    Works only with CDMODEL=ide-cd and QEMUCPU=host or core2duo (maybe other but not qemu64)
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "installbasetest";
use strict;
use warnings;

use testapi;

sub run {
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
}

1;
