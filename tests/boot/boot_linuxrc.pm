# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the ability to boot installed linux from cd with linuxrc.
# Maintainer: Jonathan Rivrain <jrivrain@suse.com>

use base "bootbasetest";
use strict;
use warnings;
use testapi;
use bootloader_setup qw(select_bootmenu_more ensure_shim_import);

sub run {
    my ($self) = @_;
    ensure_shim_import;
    select_bootmenu_more('inst-boot_linuxrc', 1);
    for (1 .. 3) {
        assert_screen("OK_button_linuxrc", 120);
        send_key "ret";
    }
    assert_screen "edit_kernel_options";
    send_key "ret";
    assert_screen "edit_kexec_options";
    # The kexec step is triggered wnen we put debug options, and proposes a
    # default option that never works, --real-mode. we have to remove it
    if (check_screen "kexec_opt_realmode") {
        record_soft_failure 'bsc#1141875';
        for (0 .. 11) { send_key "backspace" }
        save_screenshot;
    }
    send_key "ret";
    $self->{in_boot_desktop} = 1;
    assert_screen([qw(linux-login displaymanager generic-desktop)], 180);
}


1;
