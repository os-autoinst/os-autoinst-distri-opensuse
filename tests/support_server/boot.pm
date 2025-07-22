# Copyright 2015 SUSE Linux GmbH
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: supportserver and supportserver generator implementation
# Maintainer: Pavel Sladek <psladek@suse.com>

use base 'basetest';
use testapi;

sub run {

    unless (get_var("BOOTFROM") eq 'c') {
        check_screen("inst-bootmenu", 10);
        send_key "ret";    #faster boot if boot from cd
    }
    assert_screen("bootloader", 10);
    send_key "ret";    #faster boot

}

sub test_flags {
    return {fatal => 1};
}

1;

