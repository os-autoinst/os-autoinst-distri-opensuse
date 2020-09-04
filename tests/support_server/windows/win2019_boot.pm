# SUSE's openQA tests
#
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot Windows server 2019 and wait samba_ad job child tests
# Maintainer: mmartins <mmartins@suse.com>

use strict;
use warnings;
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
