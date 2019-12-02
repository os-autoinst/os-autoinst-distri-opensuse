# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wrap runltp-ng, should be run on baremetal workers
#
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use lockapi;
use ipmi_backend_utils;

sub run {
    my $self = shift;

    $self->select_serial_terminal;

    zypper_call('in git-core qemu squashfs xz');

    assert_script_run('mount /dev/nvme0n1p2 /mnt && cd /mnt/var/tmp');
    assert_script_run('git clone --recurse-submodules https://gitlab.suse.de/kernel-qa/runltp-support.git');
    assert_script_run('cd runltp-support && curl -OL https://openqa.suse.de/assets/iso/' . get_var('ISO'));
    assert_script_run('./install-setup-run-syzkaller.sh ' . get_var('SCC_REGCODE') . ' ' . get_var('ISO'),
        timeout => 3600);
    assert_script_run('./tar-up-results.sh');
    upload_logs('runltp-ng/results.tar.xz');
}

1;
