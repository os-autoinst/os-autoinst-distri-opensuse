# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the aws-efs-utils package against a pre-provisioned EFS file system.
# The SUT is deployed into a shared "tf-vpc"/"tf-subnet" with the "tf-sg" security group
# (see lib/publiccloud/provider.pm) and has access to a persistent EFS
# ("tf-efs", one mount target per AZ in tf-subnet, NFS ingress on tf-sg).
# This test installs and inspects the aws-efs-utils package (helper binaries, the mount.efs
# as Python script and its man page), then mounts the existing EFS into a job-private
# subdirectory, runs basic read/write checks and finally unmounts and removes that subdirectory.
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use publiccloud::zypper qw(pc_zypper_call);

# creation_token of the persistent EFS provisioned by the infra terraform (aws/tf/main.tf)
use constant EFS_CREATION_TOKEN => 'tf-efs';
# Local mount point on the SUT
use constant EFS_MOUNT_DIR => '/mnt/efs';

# Discover the id of the pre-provisioned EFS in the SUT region by its terraform creation_token.
# Returns the file system id (e.g. fs-0123456789abcdef0) or dies with a hint if not found.
sub efs_file_system_id {
    my ($region) = @_;
    my $fs_id = script_output(
        "aws efs describe-file-systems --region '$region' --creation-token '" . EFS_CREATION_TOKEN . "'" .
          " --query 'FileSystems[0].FileSystemId' --output text", timeout => 90);
    die "No EFS with creation-token '" . EFS_CREATION_TOKEN . "' found in region '$region'." .
      " Apply the EFS terraform from the infra repo (aws/tf/main.tf) first."
      if (!$fs_id || $fs_id eq 'None');
    return $fs_id;
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    $self->{my_instance} = $args->{my_instance};
    my $region = $self->{my_instance}->region;
    my $job_id = get_current_job_id();

    pc_zypper_call($self->{my_instance}, 'in aws-efs-utils');

    # Package content inspection and validation
    my $files = $self->{my_instance}->ssh_script_output('rpm -ql aws-efs-utils', quiet => 1);
    my @file_list = grep { /\S/ } split(/\r?\n/, $files);
    my $file_table = $self->{my_instance}->ssh_script_output('file ' . join(' ', @file_list), quiet => 1);
    record_info('aws-efs-utils', $file_table);

    # Smoke test the bundled helper binaries and scripts, if present
    my ($efs_proxy) = grep { m{/efs-proxy$} } @file_list;
    $self->{my_instance}->ssh_assert_script_run("$efs_proxy --help") if ($efs_proxy);

    my ($mount_efs) = grep { m{/mount\.efs$} } @file_list;
    $self->{my_instance}->ssh_assert_script_run("$mount_efs --version", proceed_on_failure => 1, quiet => 1) if ($mount_efs);

    # Man page shipped by the package
    $self->{my_instance}->ssh_assert_script_run('test -f /usr/share/man/man8/mount.efs.8.gz');

    # Configure logging in /etc/amazon/efs/efs-utils.conf for troubleshooting
    if (get_var('PUBLIC_CLOUD_AWSEFS_DEBUG')) {
        $self->{my_instance}->ssh_script_run(
            'sudo sed -i -e "s/^[#[:space:]]*logging_level[[:space:]]*=.*/logging_level = DEBUG/"' .
              ' -e "s/^[#[:space:]]*stunnel_debug_enabled[[:space:]]*=.*/stunnel_debug_enabled = true/" /etc/amazon/efs/efs-utils.conf'
        );
    }

    # Discover the persistent EFS provisioned by the infra terraform
    my $fs_id = efs_file_system_id($region);
    my $efs_dns = "$fs_id.efs.$region.amazonaws.com";
    record_info('EFS', "id=$fs_id\ndns=$efs_dns");

    # Mount the existing EFS into a job-private subdirectory.
    # The EFS is shared across concurrent jobs, so never touch the root: work only under
    # a per-job directory and remove it again in cleanup().
    my $job_dir = EFS_MOUNT_DIR . "/openqa-$job_id";
    $self->{my_instance}->ssh_assert_script_run('sudo mkdir -p ' . EFS_MOUNT_DIR);

    # A mount target exists in the SUT AZ and tf-sg allows NFS from the VPC, so the DNS-based
    # mount is expected to work; fall back to ip only for triage of DNS issues.
    my $mount_cmd = "sudo mount -t efs -o tls $fs_id:/ " . EFS_MOUNT_DIR;
    if ($self->{my_instance}->ssh_script_run($mount_cmd, timeout => 120) != 0) {
        my $sut_az = script_output("aws ec2 describe-instances --region '$region'" .
              " --instance-ids " . $self->{my_instance}->instance_id .
              " --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text", timeout => 60);
        my $mt_ip = script_output("aws efs describe-mount-targets --region '$region' --file-system-id $fs_id" .
              " --query \"MountTargets[?AvailabilityZoneName=='$sut_az'].IpAddress | [0]\" --output text", timeout => 60);
        record_info('Mount fallback', "DNS mount failed; retrying with mounttargetip=$mt_ip (SUT az=$sut_az)");
        $self->{my_instance}->ssh_assert_script_run(
            "sudo mount -t efs -o tls,mounttargetip=$mt_ip $fs_id:/ " . EFS_MOUNT_DIR, timeout => 120);
    }
    record_info('EFS mount', 'EFS mounted successfully');
    $self->{my_instance}->ssh_assert_script_run('systemctl status mnt-efs.mount');

    # Basic read/write checks inside the job-private directory
    $self->{my_instance}->ssh_assert_script_run("sudo mkdir -p $job_dir");
    $self->{my_instance}->ssh_assert_script_run("echo 'openqa-efs-test-$job_id' | sudo tee $job_dir/test.txt");
    $self->{my_instance}->ssh_assert_script_run("sudo grep -q 'openqa-efs-test-$job_id' $job_dir/test.txt");
    $self->{my_instance}->ssh_assert_script_run("sudo df -h " . EFS_MOUNT_DIR);
    $self->{my_instance}->ssh_assert_script_run("sudo ls -la $job_dir/");
}

sub collect_efs_logs {
    my ($self) = @_;
    return unless $self->{my_instance};

    # Show mount helper log in openQA details
    my $mount_log = $self->{my_instance}->ssh_script_output('sudo cat /var/log/amazon/efs/mount.log 2>/dev/null', proceed_on_failure => 1);
    record_info('mount.log', $mount_log) if ($mount_log && $mount_log =~ /\S/);

    # Show watchdog log in openQA details if present
    my $watchdog_log = $self->{my_instance}->ssh_script_output('sudo cat /var/log/amazon/efs/mount-watchdog.log 2>/dev/null', proceed_on_failure => 1);
    record_info('watchdog.log', $watchdog_log) if ($watchdog_log && $watchdog_log =~ /\S/);

    # Show active efs-utils configuration
    my $efs_conf = $self->{my_instance}->ssh_script_output('sudo cat /etc/amazon/efs/efs-utils.conf 2>/dev/null', proceed_on_failure => 1);
    record_info('efs-utils.conf', $efs_conf) if ($efs_conf && $efs_conf =~ /\S/);

    # Show watchdog systemd service status/journal if relevant
    my $journal = $self->{my_instance}->ssh_script_output('sudo journalctl -n 50 -u amazon-efs-mount-watchdog --no-pager 2>/dev/null', proceed_on_failure => 1);
    record_info('watchdog journal', $journal) if ($journal && $journal =~ /\S/);

    # Upload all efs logs and configuration as a tarball asset
    my $files = $self->{my_instance}->ssh_script_output('sudo ls -d /var/log/amazon/efs/* 2>/dev/null', proceed_on_failure => 1);
    my @logs = grep { /\S/ } split(/\s+/, $files // '');
    push @logs, '/etc/amazon/efs/efs-utils.conf';
    $self->{my_instance}->upload_check_logs_tar(@logs) if (@logs);
    $self->{my_instance}->upload_log('/var/log/amazon/efs/mount.log', failok => 1);
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    eval { $self->collect_efs_logs(); };
    $self->SUPER::post_fail_hook;
}

# Remove the job-private directory and unmount the EFS. Never delete any AWS resource:
# the EFS is a persistent, terraform-managed resource shared by all jobs.
# Called as a method by publiccloud::basetest::finalize() on both success and failure.
sub cleanup {
    my ($self) = @_;
    return 1 unless $self->{my_instance};
    my $job_id = get_current_job_id();
    my $job_dir = EFS_MOUNT_DIR . "/openqa-$job_id";
    $self->{my_instance}->ssh_script_run("sudo rm -rf $job_dir");
    $self->{my_instance}->ssh_script_run('sudo umount ' . EFS_MOUNT_DIR);
    return 1;
}

sub test_flags {
    return {fatal => 0, milestone => 0};
}

1;
