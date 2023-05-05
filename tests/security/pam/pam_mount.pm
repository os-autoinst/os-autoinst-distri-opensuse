# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: PAM tests for pam-mount, the encrypted volume should be mounted
#          and unmounted during user login and logout
# Maintainer: QE Security <none@suse.de>
# Tags: poo#70345, tc#1767581

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use utils 'script_run_interactive';
use base 'consoletest';

sub run {
    # There is some issue with script_run_interactive script,
    # it fails to match the serial console output sometimes,
    # so switch to root-console here
    select_console 'root-console';

    # Install runtime dependencies
    zypper_call("in pam_mount cryptsetup");

    # Define the uesr and encrypt key for the volume
    my $user = 'bernhard';
    my $key = 'SUSE_t595_qw';
    my $testfile = 'testfile';
    assert_script_run "modprobe loop";
    my $loopdev = script_output 'losetup -f';
    my $loop_vol = 'enc_loop';

    # Setup a loop device to be used as encrypted volume
    assert_script_run "dd if=/dev/zero of=$testfile bs=1024k count=500";
    assert_script_run "losetup $loopdev $testfile";
    assert_script_run "losetup -a | grep $testfile";
    script_run_interactive(
        "cryptsetup luksFormat --type luks2 $loopdev",
        [
            {
                prompt => qr/Are you sure.*/m,
                string => "YES\n",
            },
            {
                prompt => qr/Enter passphrase.*/m,
                string => "$key\n",
            },
            {
                prompt => qr/Verify passphrase.*/m,
                string => "$key\n",
            },
        ],
        400
    );

    # Create file "/etc/pam_mount_keys/enc_key" with a password contained
    my $key_dir = '/etc/pam_mount_keys';
    my $key_file = 'enc_key';
    assert_script_run "mkdir -p $key_dir";
    assert_script_run "echo '$key' > $key_dir/$key_file";
    script_run_interactive(
        "cryptsetup luksAddKey $loopdev $key_dir/$key_file",
        [
            {
                prompt => qr/Enter any existing passphrase.*/m,
                string => "$key\n",
            },
        ],
        100
    );
    assert_script_run(
        "expect -c 'spawn cryptsetup luksOpen $loopdev $loop_vol; \\
expect \"Enter passphrase for \/dev\/$loopdev: \"; send \"$key\\n\"; interact'"
    );
    assert_script_run "mkfs.ext4 -L $user /dev/mapper/$loop_vol";
    assert_script_run "cryptsetup luksClose $loop_vol";

    # Configure the "/etc/security/pam_mount.conf.xml" file
    my $pam_mount_cfg = '/etc/security/pam_mount.conf.xml';
    my $pam_mount_cfg_bak = '/etc/security/pam_mount.conf.xml.bak';
    assert_script_run "cp $pam_mount_cfg $pam_mount_cfg_bak";
    assert_script_run "sed -i '/<pam_mount>/,/<\\/pam_mount>/d' $pam_mount_cfg";
    assert_script_run(
        "echo \"\$(cat <<EOF
<pam_mount>
  <volume user=\"$user\" path=\"$loopdev\" mountpoint=\"~\" fstype=\"crypt\" fskeycipher=\"none\" fskeyhash=\"md5\" fskeypath=\"$key_dir/$key_file\" />
</pam_mount>
EOF
        )\" >> $pam_mount_cfg"
    );

    # Modify the pam common-session and common-auth files
    my $pam_session = '/etc/pam.d/common-session';
    my $pam_session_bak = '/etc/pam.d/common-session.bak';
    my $pam_auth = '/etc/pam.d/common-auth';
    my $pam_auth_bak = '/etc/pam.d/common-auth.bak';
    assert_script_run "cp $pam_session $pam_session_bak";
    assert_script_run "cp $pam_auth $pam_auth_bak";
    assert_script_run "sed -i '\$a session \[success=1 default=ignore\] pam_succeed_if.so service = systemd-user' $pam_session";
    assert_script_run "sed -i '\$a session optional        pam_mount.so   disable_interactive' $pam_session";
    assert_script_run "sed -i '\$a auth \[success=1 default=ignore\] pam_succeed_if.so service = systemd-user' $pam_auth";
    assert_script_run "sed -i '\$a auth    optional        pam_mount.so   disable_interactive' $pam_auth";
    upload_logs($pam_auth);
    upload_logs($pam_session);
    upload_logs($pam_mount_cfg);

    # Test and make sure user's home directory can mount/unmount during login/logout
    enter_cmd "su - $user";
    assert_script_run "df -k | grep /home/$user";
    enter_cmd "exit";
    validate_script_output "df -k | grep /home/$user || echo 'check pass'", sub { m/check pass/ };

    # Tear down, clear the pam configuration changes
    assert_script_run "mv $pam_session_bak $pam_session";
    assert_script_run "mv $pam_auth_bak $pam_auth";
    assert_script_run "mv $pam_mount_cfg_bak $pam_mount_cfg";
}

sub test_flags {
    return {always_rollback => 1};
}

sub post_fail_hook {
    select_console 'root-console';
    assert_script_run 'cp -pr /mnt/pam.d /etc';
}

1;

