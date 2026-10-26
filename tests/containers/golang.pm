# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that container tooling binaries were built with a current Go release
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use containers::common qw(install_packages);
use registration qw(add_suseconnect_product get_addon_fullname);
use version_utils qw(is_sle);

sub run {
    select_serial_terminal;

    if (is_sle("<16")) {
        add_suseconnect_product(get_addon_fullname('desktop'));
        add_suseconnect_product(get_addon_fullname('sdk'));
    }

    my @packages = qw(buildah docker docker-buildx docker-rootless-extras go1.27 jq podman podman-remote runc skopeo umoci);
    push @packages, "docker-compose" unless is_sle("<16");
    install_packages(@packages);

    # Fetch last 2 Golang versions
    my $versions = script_output(q(curl -s 'https://go.dev/dl/?mode=json' | jq -r '.[].version'));
    record_info('Go releases', $versions);
    my @versions = split(/\n/, $versions);

    my @paths = qw(/usr/bin /usr/sbin /usr/lib/docker/cli-plugins);
    # SLES 16.0+ & Tumbleweed are /usr-merged
    if (is_sle("<16")) {
        push @paths, qw(/bin /sbin /usr/lib/podman);
    } else {
        push @paths, qw(/usr/libexec/podman);
    }

    my $grep_opts = join(' ', map { "-e $_" } @versions[0, 1]);
    my $output = script_output(
        "find @paths -type f -exec go version {} + 2>/dev/null | grep -vF $grep_opts | sort",
        proceed_on_failure => 1
    );

    record_soft_failure("bsc#1282661 - Binaries built with an outdated Go toolchain:\n$output") if $output;
}

sub test_flags {
    return {fatal => 0};
}

1;
