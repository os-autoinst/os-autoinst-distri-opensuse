# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes kirk testing framework
# Maintainer: Kernel QE <kernel-qa@suse.de>

package LTP::kirk;

use strict;
use warnings;
use Exporter;
use utils;
use testapi;
use testapi qw(get_var get_required_var);
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_transactional);
use transactional 'trup_install';
use LTP::utils;

sub _kirk_from_git
{
    my ($cmd, $timeout) = @_;
    my $repo = get_var('KIRK_REPO', 'https://github.com/acerv/kirk.git');
    my $branch = get_var('KIRK_BRANCH', 'master');

    zypper_call("ref");

    is_transactional ? trup_install("git") : zypper_call("in -y git");
    assert_script_run("git clone -q --single-branch -b $branch --depth 1 $repo");

    $cmd = "python3 kirk/$cmd ";

    assert_script_run($cmd, timeout => $timeout);
}

sub _kirk_from_repo
{
    my ($cmd, $timeout) = @_;

    add_ltp_repo();
    zypper_call("ref");

    is_transactional ? trup_install("kirk") : zypper_call("in -y kirk");

    assert_script_run($cmd, timeout => $timeout);
}

sub _kirk_from_container
{
    my ($cmd, $timeout, $volumes_ref) = @_;
    my $container_engine = get_var('KIRK_CONTAINER', 'podman');
    my $container_repo = get_var('KIRK_CONTAINER_REPO', 'registry.opensuse.org/benchmark/ltp/devel/containers/opensuse/kirk:latest');

    if ($container_engine ne "docker" and $container_engine ne "podman") {
        die("'$container_engine' platform is not supported");
    }

    if (script_run("rpm -qi $container_engine") == 1) {
        is_transactional ? trup_install($container_engine) : zypper_call("in -y $container_engine");
    }

    assert_script_run("$container_engine pull $container_repo");

    my $engine_command = "$container_engine run --name kirk_image -it --privileged --security-opt=unmask=ALL ";
    foreach my $volume_ref (@$volumes_ref) {
        $engine_command .= "--volume $volume_ref->{src}:$volume_ref->{dst} ";
    }

    $engine_command .= "$container_repo $cmd";

    assert_script_run($engine_command, timeout => $timeout);
}

sub _kirk_upload_logs
{
    assert_script_run("test -f /tmp/kirk.\$USER/latest/debug.log || echo No debug log");
    upload_logs("/tmp/kirk.\$USER/latest/debug.log", failok => 1);

    assert_script_run("test -f /tmp/kirk.\$USER/latest/results.json || echo No results file");
    parse_extra_log('LTP', "/tmp/kirk.\$USER/latest/results.json");
}

sub run
{
    my ($self, %args) = @_;
    my $install_from = get_var('KIRK_INSTALL', 'repo');

    die "Missing mandatory argument 'framework'" unless defined $args{framework};

    $args{sut} //= 'host';
    $args{timeout} //= '5400';

    select_serial_terminal;

    my $cmd = 'kirk ';
    $cmd .= "--verbose ";
    $cmd .= "--suite-timeout $args{timeout} ";
    $cmd .= "--framework $args{framework} " if $args{framework};
    $cmd .= "--sut $args{sut} " if $args{sut};
    $cmd .= "--skip-tests $args{skip} " if $args{skip};
    $cmd .= "--env $args{envs} " if $args{envs};
    $cmd .= "--run-suite $args{suite} " if $args{suite};
    $cmd .= "$args{opts} " if $args{opts};

    if ($install_from =~ /git/i) {
        _kirk_from_git($cmd, $args{timeout});
    } elsif ($install_from =~ /repo/i) {
        _kirk_from_repo($cmd, $args{timeout});
    } elsif ($install_from =~ /container/i) {
        _kirk_from_container($cmd, $args{timeout}, $args{container_volumes});
    } else {
        die("Installation can't be done via '$install_from'");
    }

    _kirk_upload_logs;
}

1;
