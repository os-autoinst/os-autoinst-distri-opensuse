# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: dm crypt -> add flags to optionally bypass kcryptd
#          workqueues, the options are 'no_read_workqueue' and
#          'no_write_workqueue'
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#88873, tc#1768663

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'reconnect_mgmt_console';
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use package_utils 'install_package';

sub run {
    my $self = shift;
    select_serial_terminal;

    # Install runtime dependencies
    install_package("device-mapper", trup_reboot => 1);

    # Simulate a ram device. rd_size is in KB, so this creates a 500MiB ramdisk
    assert_script_run("modprobe brd rd_nr=1 rd_size=512000");

    my $ram_dev = '/dev/ram0';
    my $cipher = 'capi:ecb(cipher_null)';
    # dm-crypt target length is in 512-byte sectors: 512000KB * 1024 / 512
    # covers the whole ramdisk created above
    my $sectors = 1024000;

    # Create dm-crypt devices upon the ram device, one per bypass flag
    my @variants = (
        {flag => 'no_write_workqueue', dev => 'eram0-inline-write'},
        {flag => 'no_read_workqueue', dev => 'eram0-inline-read'},
    );

    for my $variant (@variants) {
        assert_script_run("echo '0 $sectors crypt $cipher - 0 $ram_dev 0 1 $variant->{flag}' | dmsetup create $variant->{dev}");
        # Check the flag is set correctly
        assert_script_run("dmsetup table /dev/mapper/$variant->{dev} | grep $variant->{flag}");
    }

    # Teardown and release the ram resource
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;

    # For aarch64 and ppc64le platforms, OS may need a bit more
    # time to boot up, so add some wait time here
    $self->wait_boot(textmode => 1, bootloader_time => 400, ready_time => 600);
    select_serial_terminal;
}

1;
