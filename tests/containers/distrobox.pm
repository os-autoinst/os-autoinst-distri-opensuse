# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Smoke test for distrobox
# Packages: distrobox
# Maintainer: Jose Lausuch, QE-C team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal qw(select_serial_terminal select_user_serial_terminal);
use package_utils 'install_package';
use utils qw(script_retry);

our $user = $testapi::username;
our $password = $testapi::password;

sub create_user {
    if (script_run("getent passwd $user") != 0) {
        assert_script_run "useradd -m $user";
        assert_script_run "echo '$user:$password' | chpasswd";
    }
    # Make sure user has access to tty group
    my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
    assert_script_run "grep '^${serial_group}:.*:${user}\$' /etc/group || (chown $user /dev/$testapi::serialdev && gpasswd -a $user $serial_group)";
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    $self->create_user;

    install_package('distrobox', trup_reboot => 1) if script_run 'rpm -q distrobox';

    record_info 'Version', script_output('distrobox version');
    record_info 'Config', script_output('cat /usr/etc/distrobox/distrobox.conf');

    assert_script_run 'distrobox help';

    record_info 'Test', 'Create distrobox tests as root and list it';
    assert_script_run 'distrobox create -n box-root', timeout => 300;
    validate_script_output 'distrobox list', sub { m/box-root/ };

    record_info 'Test', 'Execute a command in an existing distrobox container';
    assert_script_run 'distrobox enter -v box-root -- whoami';
    validate_script_output 'distrobox list', sub { !m/whoami/ };

    record_info 'Test', 'Stop and remove the distrobox container:';
    assert_script_run 'distrobox stop box-root';
    assert_script_run 'distrobox rm box-root';
    validate_script_output 'distrobox list', sub { !m/box-root/ };

    record_info 'Test', 'Test ephemeral function, which removes the container after execution';
    assert_script_run 'distrobox ephemeral -n box-root -- whoami';
    validate_script_output 'distrobox list', sub { !m/box-root/ };

    record_info 'Test', 'Test upgrade function';
    script_retry('distrobox create --pull -n box-root', delay => 60, retry => 3, timeout => 300);
    assert_script_run 'distrobox upgrade box-root', timeout => 300;
    assert_script_run 'distrobox rm box-root';

    select_user_serial_terminal;
    my $uid = script_output 'id -u';

    record_info 'Rootless', 'Run tests as rootless user';
    assert_script_run 'distrobox create -n box-user', timeout => 300;
    validate_script_output 'distrobox list', sub { m/box-user/ };
    validate_script_output 'distrobox enter box-user -- whoami', sub { m/${user}/ };
    validate_script_output 'distrobox enter box-user -- id', sub { m/uid=${uid}\(${user}\)/ };
    assert_script_run '! distrobox enter box-user -- touch /etc/passwd', fail_message => "$user shouldn't have access to /etc/passwd";
    assert_script_run 'distrobox upgrade box-user', timeout => 300;
    assert_script_run 'distrobox stop box-user';
    assert_script_run 'distrobox rm box-user';
}

sub test_flags {
    return {fatal => 0};
}
1;
