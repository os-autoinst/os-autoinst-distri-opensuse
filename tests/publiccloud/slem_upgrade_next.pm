# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: in public cloud, upgrade SLE Micro images
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle_micro);
use transactional 'check_target_version';

sub run {
    my ($self, $args) = @_;
    return unless (is_sle_micro('6.1+'));

    my $instance = $self->{my_instance} = $args->{my_instance};
    my $timeout = 900;

    # start migration
    select_serial_terminal();
    $instance->ssh_script_retry("sudo zypper -n ref", retry => 3, timeout => int($timeout / 3), fail_message => "zypper refresh failed");
    record_info('Repos', $instance->ssh_script_output('zypper lr -u'));

    my $exit = $instance->ssh_script_run(cmd => 'sudo transactional-update -n up', timeout => 900) // -1;
    die "transactional-update returned error $exit" unless ($exit == 0);
    $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));

    record_info("SLE-M migration", "Initial version: " . get_var('VERSION'));
    $exit = $instance->ssh_script_run(cmd => 'sudo transactional-update -n migration', timeout => 900) // -1;
    die "transactional-update migration returned error $exit" unless ($exit == 0);
    $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));

    my $ver = check_target_version($instance);
    # update new version
    set_var('VERSION', $ver);
    record_info("target version", "Final version: " . get_var('VERSION'));
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
