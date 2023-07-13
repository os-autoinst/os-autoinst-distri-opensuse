# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Rebuild initrd without ignition and combustion
#          KIWI provided initrd loads ignition and combustion
#          modules that can interfere with tests
#          e.g. qemu/qemu.pm (s390x)
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base "consoletest";
use testapi;
use transactional;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    assert_script_run(q|echo 'omit_dracutmodules+="ignition ignition-microos combustion"' > /etc/dracut.conf.d/20-disable_ignition.conf|);
    trup_call('initrd');
    check_reboot_changes;
}

1;
