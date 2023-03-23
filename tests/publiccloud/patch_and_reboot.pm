# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Refresh repositories, apply patches and reboot
#
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::ssh_interactive qw(select_host_console);

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    my $remote = $args->{my_instance}->username . '@' . $args->{my_instance}->public_ip;

    my $cmd_time = time();
    my $ref_timeout = check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE') ? 3600 : 240;
    $args->{my_instance}->ssh_script_retry("sudo zypper -n --gpg-auto-import-keys ref", timeout => $ref_timeout, retry => 6, delay => 60);
    record_info('zypper ref time', 'The command zypper -n ref took ' . (time() - $cmd_time) . ' seconds.');
    record_soft_failure('bsc#1195382 - Considerable decrease of zypper performance and increase of registration times') if ((time() - $cmd_time) > 240);

    ssh_fully_patch_system($remote);

    $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
