# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Refresh repositories, apply patches and reboot
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use utils qw(ssh_fully_patch_system);
use publiccloud::utils qw(kill_packagekit ssh_update_transactional_system is_cloudinit_supported permit_root_login zypper_remote_call);
use publiccloud::ssh_interactive qw(select_host_console);
use version_utils qw(is_sle_micro);

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    my $cmd_time = time();
    my $ref_timeout = check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE') ? 3600 : 240;
    my $remote = $args->{my_instance}->username . '@' . $args->{my_instance}->public_ip;
    # pkcon not present on SLE-micro
    kill_packagekit($args->{my_instance}) unless (is_sle_micro);

    # Record package list before fully patch system
    if (get_var('SAVE_LIST_OF_PACKAGES')) {
        $args->{my_instance}->ssh_script_run(cmd => 'rpm -qa > /tmp/rpm-qa-before-patch-system.txt');
        $args->{my_instance}->upload_log('/tmp/rpm-qa-before-patch-system.txt');
    }

    $args->{my_instance}->zypper_remote_call(cmd => "sudo zypper -n --gpg-auto-import-keys ref", timeout => $ref_timeout, retry => 6, delay => 60, fail_message => 'Remote execution of zypper ref failed. See previous steps for details');
    record_info('zypper ref time', 'The command zypper -n ref took ' . (time() - $cmd_time) . ' seconds.');
    record_soft_failure('bsc#1195382 - Considerable decrease of zypper performance and increase of registration times') if ((time() - $cmd_time) > 240);
    if (is_sle_micro) {
        ssh_update_transactional_system($args->{my_instance});
    } else {
        ssh_fully_patch_system($remote);
    }
    record_info('UNAME', $args->{my_instance}->ssh_script_output(cmd => 'uname -a'));
    $args->{my_instance}->ssh_assert_script_run(cmd => 'rpm -qa > /tmp/rpm-qa.txt');
    $args->{my_instance}->upload_log('/tmp/rpm-qa.txt');

    if (is_cloudinit_supported) {
        $args->{my_instance}->cleanup_cloudinit();
        $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600), scan_ssh_host_key => 1);
        $args->{my_instance}->check_cloudinit();
        permit_root_login($args->{my_instance});
    } else {
        $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    }
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
