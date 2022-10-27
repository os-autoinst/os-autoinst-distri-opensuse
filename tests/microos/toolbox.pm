# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run simple toolbox tests
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use containers::common;
use version_utils 'is_sle_micro';

our $user = $testapi::username;
our $password = $testapi::password;

sub cleanup {
    record_info 'Cleanup';
    clean_container_host(runtime => 'podman');
    script_run "userdel -rf $user";    # script_run in case user has not been created yet
}

sub create_user {
    if (script_run("getent passwd $user") != 0) {
        assert_script_run "useradd -m $user";
        assert_script_run "echo '$user:$password' | chpasswd";
    }

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

    my $toolbox_image_to_test = get_var('CONTAINER_IMAGE_TO_TEST');

    if ($toolbox_image_to_test) {
        # We need to extract the registry from the full image uri, e.g.
        # From registry.suse.de/suse/sle-15-sp3/update/products/microos51/update/cr/images/suse/sle-micro/5.1/toolbox:latest
        # registry = registry.suse.de
        # $image = suse/sle-15-sp3/update/products/microos51/update/cr/images/suse/sle-micro/5.1/toolbox:latest
        (my $registry = $toolbox_image_to_test) =~ s/\/.*//;
        (my $image = $toolbox_image_to_test) =~ s/^[^\/]*\///;
        assert_script_run "echo REGISTRY=$registry > /etc/toolboxrc";
        assert_script_run "echo IMAGE=$image >> /etc/toolboxrc";
        record_info('toolboxrc', script_output('cat /etc/toolboxrc'));
    }

    # Display help
    assert_script_run 'toolbox -h';

    record_info 'Test', "Run toolbox without flags";
    assert_script_run 'toolbox -r id', timeout => 300;
    validate_script_output 'podman ps -a', sub { m/toolbox-root/ };
    assert_script_run 'podman rm toolbox-root';

    record_info 'Test', "Run toolbox with a given tag";
    assert_script_run 'toolbox -t test_tag id', timeout => 180;
    validate_script_output 'podman ps -a', sub { m/toolbox-root-test_tag/ };
    assert_script_run 'podman rm toolbox-root-test_tag';

    record_info 'Test', "Run toolbox with a given name";
    assert_script_run('toolbox -c test_name id');
    validate_script_output 'podman ps -a', sub { m/test_name/ };
    assert_script_run 'podman rm test_name';


    record_info 'Test', "Rootless toolbox as $user";
    my $console = select_console 'user-console';
    my $uid = script_output 'id -u';
    validate_script_output 'toolbox -u id', sub { m/uid=${uid}\(${user}\)/ }, timeout => 180;
    die "$user shouldn't have access to /etc/passwd!" if (script_run('toolbox -u touch /etc/passwd') == 0);

    record_info 'Test', "Rootfull toolbox as $user";
    validate_script_output 'toolbox -r id', sub { m/uid=0\(root\)/ };
    assert_script_run 'toolbox -r touch /etc/passwd', fail_message => 'Root should have access to /etc/passwd!';
    assert_script_run 'podman ps -a';
    clean_container_host(runtime => 'podman');

    enter_cmd "exit";
    $console->reset;

    # Back to root
    select_console 'root-console';

    unless ($toolbox_image_to_test) {
        # This test doesn't make sense if we are testing a specific image
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
    }

    record_info 'Test', 'Zypper tests';
    assert_script_run 'toolbox create -r -c devel';
    if (!validate_script_output 'toolbox list', sub { m/devel/ }, timeout => 180, proceed_on_failure => 1) {
        record_info('ISSUE', 'https://github.com/kubic-project/microos-toolbox/issues/23');
    }
    assert_script_run 'toolbox run -c devel -- zypper lr';
    assert_script_run 'toolbox run -c devel -- zypper -n in python3', timeout => 180 unless is_sle_micro;
    assert_script_run 'podman rm devel';

    cleanup;
}

sub clean_container_host {
    my %args = @_;
    my $runtime = $args{runtime};
    die "You must define the runtime!" unless $runtime;
    assert_script_run("$runtime ps -q | xargs -r $runtime stop", 180);
    assert_script_run("$runtime system prune -a -f", 300);
}

sub post_fail_hook {
    cleanup;
}

1;
