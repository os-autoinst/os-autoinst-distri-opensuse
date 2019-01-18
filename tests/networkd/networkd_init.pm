# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup Networkd test env
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'networkdbase';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    select_console 'root-console';

    zypper_call("in systemd-container");

    if (script_run("test -d /var/lib/machines/") != 0) {
        record_info('workaround', "/var/lib/machines/ wasn't created by systemd-container RPM\nCreating it now.");
        assert_script_run("mkdir -p /var/lib/machines/");
    }

    assert_script_run("ip li add name br0 type bridge");
    assert_script_run("ip li set br0 up");

    $self->setup_nspawn_unit();

    my $pkg_repo        = "dvd:/?devices=/dev/sr0";
    my $pkgs_to_install = "systemd shadow zypper openSUSE-release vim iproute2 iputils";

    $self->setup_nspawn_container("node1", $pkg_repo, $pkgs_to_install);
    $self->setup_nspawn_container("node2", $pkg_repo, $pkgs_to_install);

    $self->start_nspawn_container("node1");
    $self->start_nspawn_container("node2");

    assert_script_run("bridge link");

    $self->assert_script_run_container("node1", "zypper lr -u");
    $self->assert_script_run_container("node1", "ip a");

    # create networkd config folder
    $self->assert_script_run_container("node1", "mkdir -p /etc/systemd/network");
    $self->assert_script_run_container("node2", "mkdir -p /etc/systemd/network");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}


1;
