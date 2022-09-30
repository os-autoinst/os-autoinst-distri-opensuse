# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: samba samba-client yast2-samba-client yast2-samba-server nautilus
# apparmor-utils
# Summary: Test with "usr.sbin.smbd" is in "enforce" mode and AppArmor is
#          "enabled && active", access the shared directory should have no error.
# - Install samba samba-client yast2-samba-client yast2-samba-server
# - Restart smb
# - Select X11 console
# - Launch yast2 samba-server
# - Fill Workgroup name as "WORKGROUP"
# - Add a new share named "testdir", description "This is smbtest", type
# directory, at "/home/testdir"
# - Switch to text console
# - Install expect
# - Delete/create testuser
# - Set a smb password for testuser
# - Run "aa-enforce usr.sbin.smbd" and check for enforce mode confirmation
# - Run aa-status to make sure profile is on enforce mode
# - Restart apparmor and smb
# - Go to X11 console
# - Launch nautilus and access "smb://<server address>"
# - Check for the shared dir
# - Fill in user, workgroup, password and access the share directory
# - Create and delete a test folder inside the share
# - Switch back to text console
# - Check audit.log for error messages related to smbd
# Maintainer: QE Security <none@suse.de>
# Tags: poo#48776, tc#1695952

use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);

# Setup samba server
sub samba_server_setup {
    my $testdir = $apparmortest::testdir;

    # Install samba packages in case
    zypper_call("in samba samba-client yast2-samba-client yast2-samba-server");
    systemctl("restart smb");

    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11("samba-server", target_match => "samba-server-installation", match_timeout => 200);

    send_key "alt-w";
    send_key "ctrl-a";
    send_key "delete";
    type_string("WORKGROUP");
    send_key_until_needlematch("samba-server-configuration", 'alt-n', 11, 2);
    send_key "alt-s";
    assert_screen("samba-server-configuration-shares");
    send_key "alt-a";
    assert_screen("samba-server-configuration-shares-newshare");
    send_key "alt-n";
    send_key "ctrl-a";
    send_key "delete";
    type_string("$testdir");
    send_key "alt-a";
    send_key "ctrl-a";
    send_key "delete";
    type_string("This is smbtest");
    send_key "alt-d";
    send_key "alt-s";
    send_key "ctrl-a";
    send_key "delete";
    type_string("/home/$testdir");
    send_key "alt-o";
    assert_screen("samba-server-configuration-shares-newshare-createdir");
    assert_and_click("samba-server-configuration-shares-newshare-createdir-Yes", timeout => 60);
    assert_screen("samba-server-configuration");
    send_key "alt-o";

    # Exit x11 and turn to console
    send_key("alt-f4");
    assert_screen("generic-desktop");
    select_console("root-console");
}

# Start "nautilus" to access the shares by "Windows Shares"
sub samba_client_access {
    my $self = shift;
    my $ip = shift;

    my $testuser = $apparmortest::testuser;
    my $testdir = $apparmortest::testdir;
    my $pw = $apparmortest::pw;

    # Start "nautilus" to access the shares by "Windows Shares"
    select_console 'x11';
    x11_start_program("nautilus", target_match => "nautilus-other-locations", match_timeout => 200);

    # Connect to samba server
    assert_and_click("nautilus-other-locations");
    send_key_until_needlematch("nautilus-connect-to-server", 'tab', 21, 2);
    type_string("smb://$ip");
    send_key "ret";
    wait_still_screen(2);

    # Search the shared dir
    send_key_until_needlematch("nautilus-sharedir-search", 'ctrl-f', 6, 2);
    type_string("$testdir");
    assert_screen("nautilus-sharedir-selected");
    send_key "ret";

    # Input password for samb user
    assert_screen("nautilus-selected-sharedir-access-passwd");
    send_key_until_needlematch("nautilus-registered-user-login", 'down', 6, 2);
    send_key "tab";
    send_key "ctrl-a";
    send_key "delete";
    type_string("$testuser");
    send_key "ret";
    send_key "ctrl-a";
    send_key "delete";
    type_string("WORKGROUP");
    send_key "ret";
    send_key "ctrl-a";
    send_key "delete";
    type_string("$pw");
    send_key "ret";
    assert_screen("nautilus-sharedir-opened");

    # Do some operations, e.g., create a test folder then delete it
    assert_and_click("nautilus-open-menu");
    assert_and_click("nautilus-new-folder");
    assert_screen("nautilus-folder-name-input-box");
    type_string("sub-testdir", wait_screen_change => 10);
    send_key "ret";
    send_key_until_needlematch("nautilus-sharedir-delete", "delete", 6, 2);
    send_key "ret";
    assert_screen("nautilus-sharedir-deleted");

    # Exit x11 and turn to console
    send_key("alt-f4");
    assert_screen("generic-desktop");
    select_console("root-console");
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

    # Set up samba server
    $self->samba_server_setup();

    # Add a samba/linux common test user
    zypper_call("in expect");
    script_run("userdel -rf $testuser");
    assert_script_run("useradd -m -d \/home\/$testuser $testuser");
    assert_script_run(
        "expect -c 'spawn smbpasswd -a $testuser; expect \"New password:\"; send \"$pw\\n\"; expect \"Retype new password:\"; send \"$pw\\n\"; interact'");

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
