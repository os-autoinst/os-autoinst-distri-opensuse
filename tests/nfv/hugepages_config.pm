# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
# Summary: Configures hugepages on boot time
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    my $hugepages  = get_required_var('HUGEPAGES');
    my $hugepagesz = get_required_var('HUGEPAGESZ');
    my $grub_file  = '/boot/grub2/grub.cfg';
    my $boot_line  = "default_hugepagesz=$hugepagesz hugepagesz=$hugepagesz hugepages=$hugepages";

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
