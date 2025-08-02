# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: usb_nic
# Summary: Simple smoke test for testing USB drive connected to system
# Maintainer: LSG QE Kernel <kernel-qa@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use package_utils 'install_package';
use version_utils 'is_sle';
use usb;


# Define a helper function to run a multi-line script as a specified user.
sub assert_script_run_as {
    my ($user, $script, $timeout) = @_;
    $timeout //= 60;    # Default timeout of 60 seconds

    # Start a clean interactive session as the specified user.
    script_start_io("su - $user");

    # Send the script to the running shell via a temporary file.
    enter_cmd("cat > /tmp/temp_script.sh << 'EOS'\n$script\nEOS");
    enter_cmd('chmod +x /tmp/temp_script.sh');

    # Execute the script and get its exit code.
    enter_cmd('/tmp/temp_script.sh; echo "EXIT_CODE:$?"');

    # Wait for the exit code.
    my ($exit_code) = wait_serial(qr/^EXIT_CODE:(\d+)/, $timeout, "Script failed to return an exit code");

    # Clean up the script file.
    enter_cmd('rm /tmp/temp_script.sh');

    # End the shell session.
    enter_cmd('exit');
    script_finish_io();

    # Now, check the exit code.
    if ($exit_code != 0) {
        die "Script run as user '$user' failed with exit code $exit_code";
    }
}


sub run {
    my ($self) = @_;

    my $unpriv_user = 'unpriv';

    select_serial_terminal;
    check_usb_devices;

    my $lun = script_output 'lsscsi -t -v | awk -F" " \'/usb/ {split($2,a,/[\/]/); print a[6]}\'';
    die "no usb storage device connected" if $lun eq "";

    my $device = "/dev/" . script_output "lsscsi -v | awk -F\"/\" \'/$lun/ {print \$3; exit}\'";

    # create filesystem, mountpoint and temporary file
    my $tmp = script_output 'mktemp -d';
    my $file = "$tmp/file";
    my $md5 = "$tmp/md5";
    my $mountpoint = "$tmp/mount";
    my $file_copy = "$mountpoint/file";

    assert_script_run "mkdir $mountpoint";
    assert_script_run "chgrp disk $mountpoint";
    assert_script_run "chmod 777 $mountpoint";

    assert_script_run "mkfs.btrfs -f $device";
    assert_script_run "mount -t btrfs $device $mountpoint";

    assert_script_run "dd if=/dev/urandom of=$file bs=1M count=16";
    assert_script_run "md5sum $file > $md5";
    assert_script_run "cp $file $file_copy";

    # unmount and flush slab and page cache
    assert_script_run "umount $mountpoint";
    assert_script_run "echo 3 > /proc/sys/vm/drop_caches";

    # remount and check md5sum
    assert_script_run "mount -t btrfs $device $mountpoint";
    assert_script_run "cd $mountpoint; md5sum -c $md5; cd /";

    assert_script_run("umount $mountpoint");

    if (zypper_search('lklfuse')) {
        # Ensure the user exists.
        assert_script_run "useradd -m -G users,disk $unpriv_user -p $testapi::password";
        install_package 'lklfuse';

        # Now, we can run all the setup commands in one clean call.
        my $setup_script = <<"FIN";
dd if=/dev/urandom of=/home/$unpriv_user/file2 bs=1M count=16
md5sum /home/$unpriv_user/file2 > /home/$unpriv_user/md5
mkdir -p /home/$unpriv_user/mount
FIN
        assert_script_run_as($unpriv_user, $setup_script);

        # The lklfuse command still needs special handling for its interactive session.
        script_start_io("su - $unpriv_user");
        enter_cmd "lklfuse -o type=btrfs /dev/sda /home/$unpriv_user/mount &";
        wait_serial_output(qr/home\/$unpriv_user\/mount/, 10, "mount | grep lklfuse");

        # Run the test logic and then unmount in the same session.
        enter_cmd "cp /home/$unpriv_user/file2 /home/$unpriv_user/mount/file2";
        enter_cmd "fusermount -u /home/$unpriv_user/mount";

        enter_cmd "exit";
        script_finish_io();

        # Re-mount and verify.
        script_start_io("su - $unpriv_user");
        enter_cmd "lklfuse -o type=btrfs /dev/sda /home/$unpriv_user/mount &";
        wait_serial_output(qr/home\/$unpriv_user\/mount/, 10, "mount | grep lklfuse");
        enter_cmd "cd /home/$unpriv_user/mount; md5sum -c /home/$unpriv_user/md5; cd";
        enter_cmd "fusermount -u /home/$unpriv_user/mount";
        enter_cmd "exit";
        script_finish_io();
    } elsif (is_sle('16+')) {
        die "running on SLE16+ but lklfuse package is missing";
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
