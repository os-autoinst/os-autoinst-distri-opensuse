# SUSE's Samba test
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: samba, samba-winbind
# Summary: Test samba server, users, rpcclient and smbcontrol
# Maintainer: qe-core@suse.de

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils;
use version_utils;
use registration;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    zypper_call "in samba samba-winbind";

    record_info 'start services';
    systemctl 'start smb nmb winbind';
    systemctl 'status smb nmb winbind';

    record_info 'smbcontrol ping';
    assert_script_run 'smbcontrol -t 2 smbd ping';
    assert_script_run 'smbcontrol -t 2 nmbd ping';
    assert_script_run 'smbcontrol -t 2 winbind ping';

    record_info 'access unexisting user';
    assert_script_run "(rpcclient -U '$username%$password' -c srvinfo localhost || true) |& grep NT_STATUS_ACCESS_DENIED";

    record_info 'create user';
    assert_script_run "(echo '$password';echo '$password') | smbpasswd -a -s $username";

    record_info 'wrong pass';
    assert_script_run "(rpcclient -U '$username%WRONGPASS' -c srvinfo localhost || true) |& grep NT_STATUS_LOGON_FAILURE";

    record_info 'access';
    assert_script_run "rpcclient -U '$username%$password' -c srvinfo localhost";
    validate_script_output "net share -S localhost -U '$username%$password'", sub { $_ =~ m/profiles/ && $_ =~ m/users/ && $_ =~ m/groups/ };

    record_info 'delete user';
    assert_script_run "smbpasswd -x $username";
}

1;

