# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: samba samba-client yast2-samba-client yast2-samba-server apparmor-utils
# Summary: Test with "usr.sbin.smbd" is in "enforce" mode and AppArmor is
#          "enabled && active", access the shared directory should have no error.
# - Install samba samba-client yast2-samba-client yast2-samba-server
# - Restart smb
# - Add a new share named "testdir", description "This is smbtest", type
# directory, at "/home/testdir"
# - Install expect
# - Delete/create testuser
# - Set a smb password for testuser
# - Run "aa-enforce usr.sbin.smbd" and check for enforce mode confirmation
# - Run aa-status to make sure profile is on enforce mode
# - Restart apparmor and smb
# - Access the samba share using the previously created user
# - Create and delete a test folder inside the share
# - Check audit.log for error messages related to smbd
# Maintainer: QE Security <none@suse.de>
# Tags: poo#48776, poo#134780

use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);
use Utils::Architectures;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);

sub samba_server_setup {
    my $testdir = $apparmortest::testdir;

    zypper_call("in samba samba-client yast2-samba-client yast2-samba-server");

    my $smb_config = <<EOF;
[testdir]
        comment = samba test
        inherit acls = Yes
        path = /home/testdir
        read only = No
EOF
    assert_script_run("echo '$smb_config' >> /etc/samba/smb.conf");
    assert_script_run("mkdir /home/$apparmortest::testdir");
    systemctl("restart smb");
}

sub samba_client_access {
    my $self = shift;
    my $ip = shift;

    my $testuser = $apparmortest::testuser;
    my $testdir = $apparmortest::testdir;
    my $pw = $apparmortest::pw;
    my $smb_test_dir = "mydir";

    select_user_serial_terminal;

    assert_script_run(
        "expect -c 'spawn smbclient -U $testuser -L $ip; expect \"Enter WORKGROUP\\testuser'\"'\"'s password:\"; send \"$pw\\n\"; interact'"
    );

    assert_script_run(
        "smbclient //$ip/$testdir -U $testuser%$pw -c \"mkdir $smb_test_dir; ls; rmdir $smb_test_dir; ls; exit\""
    );

    select_serial_terminal;
}

sub run {
    my ($self) = shift;
    my $audit_log = $apparmortest::audit_log;
    my $prof_dir = $apparmortest::prof_dir;
    my $profile_name = "usr.sbin.smbd";
    my $named_profile = "";
    my $testuser = $apparmortest::testuser;
    my $testdir = $apparmortest::testdir;
    my $pw = $apparmortest::pw;
    my $ip = "";

    select_serial_terminal;

    # Set up samba server
    $self->samba_server_setup();

    # Add a samba/linux common test user
    zypper_call("in expect");
    script_run("userdel -rf $testuser");
    assert_script_run("useradd -m -d \/home\/$testuser $testuser");
    assert_script_run(
        "expect -c 'spawn smbpasswd -a $testuser; expect \"New password:\"; send \"$pw\\n\"; expect \"Retype new password:\"; send \"$pw\\n\"; interact'"
    );

    # Change the owner and group for the samba test dir
    assert_script_run("chown $testuser\:users /home/$testdir");
    # Fetch the localhost ip
    $ip = $self->ip_fetch();

    # Set the AppArmor security profile to enforce mode
    validate_script_output("aa-enforce $profile_name", sub { m/Setting .*$profile_name to enforce mode./ });
    # Recalculate profile name in case
    $named_profile = $self->get_named_profile($profile_name);
    # Check if $profile_name is in "enforce" mode
    $self->aa_status_stdout_check($named_profile, "enforce");

    # Restart apparmor
    systemctl("restart apparmor");
    validate_script_output("systemctl is-active apparmor", sub { m/active/ });

    # Cleanup audit log, restart smb
    assert_script_run("echo > $audit_log");
    systemctl("restart smb");

    # Access the shared folder by "Windows Share"
    $self->samba_client_access("$ip");

    # Verify audit log contains no "DENIED" (etc. "samba/smbd") operations
    my $script_output = script_output("cat $audit_log");
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* profile=.*/sx) {
        record_info("ERROR", "There are denied records found in $audit_log");
        record_soft_failure('bsc#1196850') if is_sle('>=15-SP3');
        $self->result('fail') unless is_sle('>=15-SP3');
    }

    # Upload logs for reference
    upload_logs("/var/log/samba/log.smbd");
    upload_logs("$audit_log");
}

1;
