# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Configures hugepages on boot time
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;

    my $hugepages = get_required_var('HUGEPAGES');
    my $hugepagesz = get_required_var('HUGEPAGESZ');
    my $grub_file = '/boot/grub2/grub.cfg';
    my $boot_line = "default_hugepagesz=$hugepagesz hugepagesz=$hugepagesz hugepages=$hugepages";

    record_info("INFO", "Add $boot_line to the Kernel boot command");
    assert_script_run("sed -i 's/showopts/showopts " . $boot_line . "/' " . $grub_file);
    assert_script_run("sed -i 's/showopts/showopts " . $boot_line . "/' " . $grub_file);
    assert_script_run("grub2-mkconfig");
    upload_logs($grub_file, failok => 1);

    # needs reboot, but we rely on mellanox_config.pm for the reboot process.
}

sub test_flags {
    return {fatal => 1};
}

1;
