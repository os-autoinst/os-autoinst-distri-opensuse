# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: docker-compose
# Summary: Upstream docker-compose tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils;
use power_action_utils 'power_action';
use containers::common qw(install_packages);
use containers::bats;

my $docker_compose = "/usr/lib/docker/cli-plugins/docker-compose";

sub setup {
    my @pkgs = qw(docker docker-compose go1.24 make);
    install_packages(@pkgs);
    install_git;

    systemctl "enable docker";
    systemctl "restart docker";
    record_info("docker info", script_output("docker info"));

    # Some tests need this file
    run_command "mkdir /root/.docker";
    run_command "touch /root/.docker/config.json";

    my $version = script_output "$docker_compose version | awk '{ print \$4 }'";
    record_info("version", $version);

    patch_sources "compose", "v$version", "pkg/e2e";
}


sub test ($target) {
    my %env = (
        COMPOSE_E2E_BIN_PATH => $docker_compose,
        # This test fails on v2.39.2 at least
        EXCLUDE_E2E_TESTS => 'TestWatchMultiServices',
    );
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;

    run_command "$env make $target |& tee $target.txt || true", timeout => 3600;

    # Patch the test name in the first line of the JUnit XML file so each target is parsed independently
    assert_script_run qq{sed -ri '0,/name=/s/name="[^"]*"/name="$target"/' /tmp/report/report.xml};
    assert_script_run "mv /tmp/report/report.xml $target.xml";
    parse_extra_log(XUnit => "$target.xml");
    upload_logs("$target.txt");
}

sub run {
    my ($self, $args) = @_;

    select_serial_terminal;
    setup;

    # Bind-mount /tmp to /var/tmp
    mount_tmp_vartmp;
    power_action('reboot', textmode => 1);
    $self->wait_boot();
    select_serial_terminal;

    assert_script_run "cd /var/tmp/compose";
    run_command 'PATH=$PATH:/var/tmp/compose/bin/build';

    my @targets = split('\s+', get_var("DOCKER_COMPOSE_TARGETS", "e2e-compose e2e-compose-standalone"));
    test $_ foreach (@targets);
}

sub post_fail_hook {
    my ($self) = @_;
    bats_post_hook;
}

sub post_run_hook {
    my ($self) = @_;
    bats_post_hook;
}

1;
