# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
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
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#48776, tc#1695952

use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;

# Setup samba server
sub samba_server_setup {
    my $testdir = $apparmortest::testdir;

    # Install samba packages in case
    zypper_call("in samba samba-client yast2-samba-client yast2-samba-server");
    systemctl("restart smb");

    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11(module => "samba-server", target_match => "samba-server-installation", match_timeout => 200);

    send_key "alt-w";
    send_key "ctrl-a";
    send_key "delete";
    type_string("WORKGROUP");
    send_key_until_needlematch("samba-server-configuration", 'alt-n', 10, 2);
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
    send_key "alt-y";
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
    my $ip   = shift;

    my $testuser = $apparmortest::testuser;
    my $testdir  = $apparmortest::testdir;
    my $pw       = $apparmortest::pw;

    # Start "nautilus" to access the shares by "Windows Shares"
    select_console 'x11';
    x11_start_program("nautilus", target_match => "nautilus-other-locations", match_timeout => 200);

    # Connect to samba server
    send_key_until_needlematch("nautilus-other-locations-selected", 'pgdn', 10, 2);
    send_key "ret";
    send_key_until_needlematch("nautilus-connect-to-server", 'tab', 10, 2);
    type_string("smb://$ip");
    send_key "ret";

    # Search the shared dir
    send_key_until_needlematch("nautilus-sharedir-search", 'ctrl-f', 5, 2);
    type_string("$testdir");
    assert_screen("nautilus-sharedir-selected");
    send_key "ret";

    # Input password for samb user
    assert_screen("nautilus-selected-sharedir-access-passwd");
    send_key_until_needlematch("nautilus-registered-user-login", 'down', 5, 2);
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
    send_key "shift-ctrl-n";
    wait_still_screen(2);
    type_string("sub-testdir", wait_screen_changes => 10);
    send_key "ret";
    send_key_until_needlematch("nautilus-sharedir-delete", "delete", 5, 2);
    send_key "ret";
    assert_screen("nautilus-sharedir-deleted");

    # Exit x11 and turn to console
    send_key("alt-f4");
    assert_screen("generic-desktop");
    select_console("root-console");
}

sub run {
    my ($self)        = shift;
    my $audit_log     = $apparmortest::audit_log;
    my $prof_dir      = $apparmortest::prof_dir;
    my $profile_name  = "usr.sbin.smbd";
    my $named_profile = "";
    my $testuser      = $apparmortest::testuser;
    my $testdir       = $apparmortest::testdir;
    my $pw            = $apparmortest::pw;
    my $ip            = "";

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

    # Restart apparmor, smb
    systemctl("restart apparmor");
    systemctl("restart smb");
    validate_script_output("systemctl is-active apparmor", sub { m/active/ });

    # Cleanup audit log
    assert_script_run("echo > $audit_log");

    # Access the shared folder by "Windows Share"
    $self->samba_client_access("$ip");

    # Verify audit log contains no "DENIED" "samba" operations
    my $script_output = script_output("cat $audit_log");
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* profile=.*smbd.*/sx) {
        record_info("ERROR", "There are denied change_hat records found in $audit_log", result => 'fail');
        $self->result('fail');
    }

    # Upload logs for reference
    upload_logs("/var/log/samba/log.smbd");
    upload_logs("$audit_log");
}

1;
