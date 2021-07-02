# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run simple toolbox tests
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use containers::common;
use version_utils 'is_sle_micro';

our $user     = $testapi::username;
our $password = $testapi::password;

sub cleanup {
    record_info 'Cleanup';
    clean_container_host(runtime => 'podman');
    script_run "userdel -rf $user";    # script_run in case user has not been created yet
}

sub create_user {
    assert_script_run "useradd -m $user ";
    assert_script_run "echo '$user:$password' | chpasswd";

    # Make sure user has access to tty group
    my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
    assert_script_run "grep '^${serial_group}:.*:${user}\$' /etc/group || (chown $user /dev/$testapi::serialdev && gpasswd -a $user $serial_group)";

    # Don't ask password for sudo commands
    assert_script_run "echo \"$user ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers";
}

sub run {
    my ($self) = @_;
    select_console 'root-console';
    $self->create_user;

    # Display help
    assert_script_run 'toolbox -h';

    record_info 'Test',                    "Run toolbox without flags";
    assert_script_run 'toolbox -r id',     timeout => 180;
    validate_script_output 'podman ps -a', sub { m/toolbox-root/ };
    assert_script_run 'podman rm toolbox-root';

    record_info 'Test',                         "Run toolbox with a given tag";
    assert_script_run 'toolbox -t test_tag id', timeout => 180;
    validate_script_output 'podman ps -a',      sub { m/toolbox-root-test_tag/ };
    assert_script_run 'podman rm toolbox-root-test_tag';

    record_info 'Test', "Run toolbox with a given name";
    assert_script_run('toolbox -c test_name id');
    validate_script_output 'podman ps -a', sub { m/test_name/ };
    assert_script_run 'podman rm test_name';


    record_info 'Test', "Rootless toolbox as $user";
    select_console 'user-console';
    my $uid = script_output 'id -u';
    validate_script_output 'toolbox -u id', sub { m/uid=${uid}\(${user}\)/ }, timeout => 180;
    die "$user shouldn't have access to /etc/passwd!" if (script_run('toolbox -u touch /etc/passwd') == 0);

    record_info 'Test',                               "Rootfull toolbox as $user";
    validate_script_output 'toolbox -r id',           sub { m/uid=0\(root\)/ };
    assert_script_run 'toolbox -r touch /etc/passwd', fail_message => 'Root should have access to /etc/passwd!';
    assert_script_run 'podman ps -a';
    clean_container_host(runtime => 'podman');

    # Back to root
    select_console 'root-console';

    record_info 'Test', 'Pulling toolbox image from different registry';
    # Switch default registries for openSUSE MicroOS and SLE Micro
    if (is_sle_micro) {
        assert_script_run 'echo -e "REGISTRY=registry.opensuse.org\nIMAGE=opensuse/toolbox" > ~/.toolboxrc';
        validate_script_output 'toolbox -r cat /etc/os-release', sub { m/opensuse/ }, timeout => 180;
    } else {
        assert_script_run 'echo -e "REGISTRY=registry.suse.com\nIMAGE=suse/sle-micro/5.0/toolbox" > ~/.toolboxrc';
        validate_script_output 'toolbox -r cat /etc/os-release', sub { m/sles/ }, timeout => 180;
    }
    assert_script_run 'podman rm toolbox-root';
    assert_script_run 'rm ~/.toolboxrc';

    record_info 'Test', 'Zypper tests';
    assert_script_run 'toolbox create -r -c devel';
    if (!validate_script_output 'toolbox list', sub { m/devel/ }, timeout => 180, proceed_on_failure => 1) {
        record_info('ISSUE', 'https://github.com/kubic-project/microos-toolbox/issues/23');
    }
    script_run 'toolbox run -c devel -- zypper lr';    # this command will fail in SLE Micro toolbox as there are no repos
    assert_script_run 'toolbox run -c devel -- zypper -n in python3', timeout => 180 unless is_sle_micro;
    assert_script_run 'podman rm devel';

    cleanup;
}

sub post_fail_hook {
    cleanup;
}

1;
