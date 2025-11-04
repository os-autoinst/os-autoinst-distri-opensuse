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


# Check upgraded version after migration
sub check_upgraded_version {
    my $self = shift;
    my $expected_version = get_required_var("TARGET_VERSION") =~ /^(\d+\.\d+)$/;
    $expected_version = $1 // 0;
    my $release = $self->ssh_script_output("cat /etc/os-release");
    # Selector valid from SL micro 6.2 on
    my $selector = qq|SUSE_SUPPORT_PRODUCT_VERSION="$expected_version"|;
    die "Error: target version '$expected_version' not present in:\n$release"
      unless ($expected_version >= 6.2 && $release =~ $selector);
    return $expected_version;
}


sub run {
    my ($self, $args) = @_;
    return unless (is_sle_micro('6.1+'));

    my $instance = $self->{my_instance} = $args->{my_instance};
    my $timeout = 900;
    my $reboot_timeout = get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT');

    # start migration
    select_serial_terminal();
    $instance->ssh_script_retry("sudo zypper -n ref", retry => 3, timeout => int($timeout / 3), fail_message => "zypper refresh failed");
    record_info('Repos', $instance->ssh_script_output('zypper lr -u'));

    my $exit = $instance->ssh_script_run(cmd => 'sudo transactional-update -n up', timeout => $timeout) // -1;
    die "transactional-update returned error $exit" unless ($exit == 0);
    $instance->softreboot(timeout => $reboot_timeout);

    record_info("SLEM migration", "Initial version: " . get_var('VERSION'));
    $exit = $instance->ssh_script_run(cmd => 'sudo transactional-update -n migration', timeout => $timeout) // -1;
    die "transactional-update migration returned error $exit" unless ($exit == 0);
    $instance->softreboot(timeout => $reboot_timeout);

    my $ver = check_upgraded_version($instance);
    # update new version
    set_var('VERSION', $ver);
    record_info("target version", "Final version: $ver");
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
