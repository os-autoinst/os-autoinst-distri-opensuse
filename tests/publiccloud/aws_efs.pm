# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the aws-efs-utils package against a pre-provisioned EFS file system.
# The openQA EC2 SUT is always launched into the shared "tf-vpc"/"tf-subnet" with the
# "tf-sg" security group (see lib/publiccloud/provider.pm). The infra terraform provisions
# a persistent EFS ("tf-efs", one mount target per AZ in tf-subnet, NFS ingress on tf-sg),
# so the SUT can mount it directly by DNS without creating any AWS resource per test.
# This test installs and inspects the aws-efs-utils package (helper binaries, the mount.efs
# Python interpreter ABI and its man page), then mounts the existing EFS into a job-private
# subdirectory, runs basic read/write checks and finally unmounts and removes that subdirectory.
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';

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

    my $instance = $self->{my_instance} = $args->{my_instance};
    my $region = $instance->region;
    my $job_id = get_current_job_id();

    $instance->ssh_assert_script_run('sudo zypper -n in aws-efs-utils', timeout => 300);

    # Package content inspection and validation
    my $files = $instance->ssh_script_output('rpm -ql aws-efs-utils', quiet => 1);
    my @file_list = grep { /\S/ } split(/\r?\n/, $files);
    my $file_table = $instance->ssh_script_output('file ' . join(' ', @file_list), quiet => 1);
    record_info('aws-efs-utils', $file_table);

    # Smoke test the bundled helper binaries and scripts, if present
    my ($efs_proxy) = grep { m{/efs-proxy$} } @file_list;
    $instance->ssh_assert_script_run("$efs_proxy --help") if ($efs_proxy);

    # aws-efs-utils is a set of Python helper scripts. mount.efs runs with the /usr/bin/python3
    # shebang, while its modules are installed under /usr/lib/pythonX.Y and the package requires
    # python(abi) = X.Y. Validate that the interpreter mount.efs runs with matches that ABI,
    # otherwise mount.efs would fail to import its own modules at runtime.
    my ($mount_efs) = grep { m{/mount\.efs$} } @file_list;
    if ($mount_efs) {
        my $mount_efs_version = $instance->ssh_script_output("$mount_efs --version", proceed_on_failure => 1, quiet => 1);
        my $shebang = $instance->ssh_script_output("head -1 $mount_efs", quiet => 1);
        my $py_version = $instance->ssh_script_output('/usr/bin/python3 -V 2>&1', quiet => 1);
        my $py_libdir = $instance->ssh_script_output(
            "rpm -ql aws-efs-utils | grep -oE '/usr/lib/python[0-9.]+' | sort -u || true", quiet => 1);
        my $py_requires = $instance->ssh_script_output(
            'rpm -q --requires aws-efs-utils | grep -Ei python || true', quiet => 1);
        record_info('mount.efs python', join("\n",
                "mount.efs --version: $mount_efs_version",
                "shebang: $shebang",
                "/usr/bin/python3 -V: $py_version",
                "shipped module dir(s): $py_libdir",
                "python requires: $py_requires"));

        # The interpreter behind the shebang must satisfy the required python ABI
        my ($abi) = $py_requires =~ /python\(abi\)\s*=\s*([0-9]+\.[0-9]+)/;
        my ($run_ver) = $py_version =~ /Python\s+([0-9]+\.[0-9]+)/;
        die "aws-efs-utils requires python(abi) = $abi but /usr/bin/python3 is $run_ver"
          if ($abi && $run_ver && $abi ne $run_ver);
    }
    # Man page shipped by the package
    $instance->ssh_assert_script_run('test -f /usr/share/man/man8/mount.efs.8.gz');

    # Discover the persistent EFS provisioned by the infra terraform
    my $fs_id = efs_file_system_id($region);
    my $efs_dns = "$fs_id.efs.$region.amazonaws.com";
    record_info('EFS', "id=$fs_id\ndns=$efs_dns");

    # Mount the existing EFS into a job-private subdirectory.
    # The EFS is shared across concurrent jobs, so never touch the root: work only under
    # a per-job directory and remove it again in cleanup().
    my $job_dir = EFS_MOUNT_DIR . "/openqa-$job_id";
    $instance->ssh_assert_script_run('sudo mkdir -p ' . EFS_MOUNT_DIR);

    # A mount target exists in the SUT AZ and tf-sg allows NFS from the VPC, so the DNS-based
    # mount is expected to work; fall back to mounttargetip only for triage of DNS issues.
    my $mount_cmd = "sudo mount -t efs -o tls $fs_id:/ " . EFS_MOUNT_DIR;
    if ($instance->ssh_script_run($mount_cmd, timeout => 120) != 0) {
        my $sut_az = script_output("aws ec2 describe-instances --region '$region'" .
              " --instance-ids " . $instance->instance_id .
              " --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text", timeout => 60);
        my $mt_ip = script_output("aws efs describe-mount-targets --region '$region' --file-system-id $fs_id" .
              " --query \"MountTargets[?AvailabilityZoneName=='$sut_az'].IpAddress | [0]\" --output text", timeout => 60);
        record_info('Mount fallback', "DNS mount failed; retrying with mounttargetip=$mt_ip (SUT az=$sut_az)");
        $instance->ssh_assert_script_run(
            "sudo mount -t efs -o tls,mounttargetip=$mt_ip $fs_id:/ " . EFS_MOUNT_DIR, timeout => 120);
    }
    record_info('EFS mount', 'EFS mounted successfully');
    $instance->ssh_assert_script_run('systemctl status mnt-efs.mount');

    # Basic read/write checks inside the job-private directory
    $instance->ssh_assert_script_run("sudo mkdir -p $job_dir");
    $instance->ssh_assert_script_run("echo 'openqa-efs-test-$job_id' | sudo tee $job_dir/test.txt");
    $instance->ssh_assert_script_run("sudo grep -q 'openqa-efs-test-$job_id' $job_dir/test.txt");
    $instance->ssh_assert_script_run("sudo df -h " . EFS_MOUNT_DIR);
    $instance->ssh_assert_script_run("sudo ls -la $job_dir/");
}

# Remove the job-private directory and unmount the EFS. Never delete any AWS resource:
# the EFS is a persistent, terraform-managed resource shared by all jobs.
# Called as a method by publiccloud::basetest::finalize() on both success and failure.
sub cleanup {
    my ($self) = @_;
    my $instance = $self->{my_instance};
    return 1 unless $instance;
    my $job_id = get_current_job_id();
    my $job_dir = EFS_MOUNT_DIR . "/openqa-$job_id";
    $instance->ssh_script_run("sudo rm -rf $job_dir");
    $instance->ssh_script_run('sudo umount ' . EFS_MOUNT_DIR);
    return 1;
}

sub test_flags {
    return {fatal => 0, milestone => 0};
}

1;
