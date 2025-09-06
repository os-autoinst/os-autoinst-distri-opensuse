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
use version_utils;
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
    my $branch = "v$version";
    my $github_org = "docker";

    # Support these cases for GIT_REPO: [<GITHUB_ORG>]#BRANCH
    # 1. As GITHUB_ORG#TAG: github_user#test-patch
    # 2. As TAG only: main, v1.2.3, etc
    # 3. Empty. Use defaults specified above for $github_org & $branch
    my $repo = get_var("GIT_REPO", "");
    if ($repo =~ /#/) {
        ($github_org, $branch) = split("#", $repo, 2);
    } elsif ($repo) {
        $branch = $repo;
    }

    run_command "cd ~";
    run_command "git clone --branch $branch https://github.com/$github_org/compose", timeout => 300;
    run_command "cd ~/compose";

    unless ($repo) {
        # https://github.com/docker/compose/pull/13214 - test: Set stop_signal to SIGTERM
        my @patches = qw(13214);
        foreach my $patch (@patches) {
            my $url = "https://github.com/docker/compose/pull/$patch";
            record_info("patch", $url);
            assert_script_run "curl -O " . data_url("containers/patches/compose/$patch.patch");
            run_command "git apply -3 --ours $patch.patch";
        }
    }
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

    assert_script_run "cd ~/compose";
    run_command 'PATH=$PATH:$HOME/compose/bin/build';

    my @targets = split('\s+', get_var("DOCKER_COMPOSE_TARGETS", "e2e-compose e2e-compose-standalone"));
    test $_ foreach (@targets);
}

sub cleanup() {
    script_run "cd / ; rm -rf /root/compose";
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup;
    bats_post_hook;
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup;
    bats_post_hook;
    $self->SUPER::post_run_hook;
}

1;
