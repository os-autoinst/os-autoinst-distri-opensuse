# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check cloud-init status on the public cloud instance
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils qw(is_cloudinit_supported is_azure);
use publiccloud::ssh_interactive qw(select_host_console);
use version_utils qw(is_sle);

sub check_cloudinit {
    my ($instance) = @_;

    # cloud-init status
    my $rc = $instance->ssh_script_run(cmd => "sudo cloud-init status --wait", timeout => 300);
    record_info("cloud-init", $instance->ssh_script_output("sudo cloud-init status --long", proceed_on_failure => 1, timeout => 300), result => $rc == 0 ? 'ok' : 'fail');
    # Cloud-init error codes: 0 - success, 1 - unrecoverable error, 2 - recoverable error (See cloud-init documentation)
    # As of https://bugzilla.suse.com/show_bug.cgi?id=1266207 we ignore recoverable errors
    if (get_var('PUBLIC_CLOUD_IGNORE_CLOUDINIT_ERRORS') != 1) {
        if ($rc == 1) {
            die "unrecoverable cloud-init error";
        } elsif ($rc == 2) {
            record_info("cloud-init", "recoverable error (return code 2)");
        } elsif ($rc != 0) {
            die "unknown cloud-init return code $rc";
        }
    }

    # cloud-id
    my $cloud_id = (is_azure) ? 'azure' : 'aws';
    $instance->ssh_assert_script_run(cmd => "sudo cloud-id | grep '^$cloud_id\$'");

    # cloud-init collect-logs
    $instance->ssh_assert_script_run('sudo cloud-init collect-logs');
    $instance->upload_log('~/cloud-init.tar.gz', failok => 1);

    if (get_var('PUBLIC_CLOUD_CLOUD_INIT')) {
        # Check for bootcmd, runcmd and write_files module
        $instance->ssh_assert_script_run('sudo grep pookie /root/test_cloud-init.txt');
        $instance->ssh_assert_script_run('sudo grep Mithrandir /root/test_cloud-init.txt');
        $instance->ssh_assert_script_run('sudo grep snickerdoodle /root/test_cloud-init.txt');

        # Check for packages module
        $instance->ssh_assert_script_run('ed -V');

        # Check for final_message module
        $instance->ssh_assert_script_run('sudo journalctl -b | grep "cloud-init qa has finished"');

        # cloud-init schema
        $instance->ssh_assert_script_run('sudo cloud-init schema --system') unless (is_sle('=12-SP5'));
    }
}

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    return unless (is_cloudinit_supported);
    check_cloudinit($args->{my_instance});
}

sub test_flags {
    return {fatal => 0};
}

1;
