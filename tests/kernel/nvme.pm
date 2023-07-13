# SUSE's openQA tests
#
# Copyright 2018-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nvme
# Summary: NVMe smoke tests
# Maintainer: Sebastian Chlad <schlad@suse.de>, Michael Moese <mmoese@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Logging 'export_logs_basic';


sub run {
    my ($self) = @_;

    select_serial_terminal;

    # list of packages to be installed and checked for their version using zypper info
    my @packages = split ' ', get_var('NVME_PACKAGES', "nvmetcli nvme-cli nvme-stas");
    my $nvmetcli_upstream = get_var('NVMETCLI_UPSTREAM', "http://git.infradead.org/users/hch/nvmetcli.git/blob_plain/HEAD:");
    my @nvme_modules = split ' ', get_var('NVME_MODULES', "nvme_loop nvmet nvme_fabrics");

    foreach my $package (@packages) {
        zypper_call("install $package");
        my $package_info = script_output("zypper info $package");
        foreach my $line (split /\n/, $package_info) {
            if ($line =~ "Version") {
                my @version = split /:/, $line;
                record_info("INFO", "$package is installed in version: $version[1]\n");
            }
        }
    }

    # check if nvmetcli is the latest upstream version
    assert_script_run("curl -o /tmp/nvmetcli $nvmetcli_upstream/nvmetcli");
    my $result = script_output('diff /tmp/nvmetcli /usr/sbin/nvmetcli');

    record_info("ERROR", "nvmetcli is not equal to upstram version: $result", result => 'fail') unless ($result eq "");

    # load modules
    foreach my $module (@nvme_modules) {
        assert_script_run("modprobe $module");

    }
    #setup nvme loop device
    assert_script_run("dd if=/dev/zero of=/tmp/nvme_loopback bs=1M count=4096");
    assert_script_run("losetup /dev/loop0 /tmp/nvme_loopback");
    assert_script_run("curl -o /tmp/loop.json $nvmetcli_upstream/examples/loop.json");
    assert_script_run("sed -i 's/nvme0n1/loop0/g' /tmp/loop.json");
    assert_script_run("nvmetcli restore /tmp/loop.json");
    assert_script_run("nvme connect -t loop -n testnqn -q hostnqn");
    assert_script_run("nvme list");
    zypper_call("in fio");
    assert_script_run("fio --filename=/dev/nvme0n1  --rw=write --bs=4k --numjobs=1 --iodepth=1 --runtime=60 --time_based --group_reporting --name=journal-test");

}

sub test_flags {
    return {fatal => 0};
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    export_logs_basic;
    script_run('rpm -qi kernel-default > /tmp/kernel_info');
    upload_logs('/tmp/kernel_info');
}

1;
