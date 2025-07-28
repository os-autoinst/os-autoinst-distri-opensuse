# SUSE's openQA tests
#
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot Windows server 2019 and wait samba_ad job child tests
# Maintainer: mmartins <mmartins@suse.com>

use base 'windowsbasetest';
use testapi;
use mmapi;

sub run {
    my $self = shift;
    assert_screen "windows-installed-ok", timeout => 400;
    $self->windows_server_login_Administrator;

    #wait child job.
    wait_for_children;
    record_info 'SAMBA Done', 'SAMBA  test done.';
    #shutdonw
    $self->reboot_or_shutdown();
    check_shutdown;
}

1;
