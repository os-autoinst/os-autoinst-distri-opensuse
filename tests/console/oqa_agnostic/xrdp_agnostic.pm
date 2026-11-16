# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: xrdp server and xfreerdp client loopback session
#   Run the openQA-agnostic xrdp/xfreerdp loopback test from
#   data/console/openqa_agnostic/python/testXrdp. It starts the packaged
#   xrdp and connects to it with the packaged xfreerdp over localhost.
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use version_utils qw(is_tumbleweed is_sle);
use Utils::Architectures 'is_x86_64';
use agnosticTestRunner;

sub run {
    select_serial_terminal;
    if (!is_tumbleweed() && !is_sle()) {
        record_info('SKIP', 'xrdp is only tested on Tumbleweed and SLE');
        return;
    }

    my $freerdp = script_run('zypper -n info freerdp', quiet => 1) == 0 ? 'freerdp' : 'freerdp2';
    my @required = ('xrdp', 'xorg-x11-Xvnc', 'xterm', $freerdp, 'xvfb-run', 'xorg-x11-server-Xvfb', 'iproute2', 'xauth');

    # The Xorg backend is optional and only meaningful on x86_64.
    if (is_x86_64) {
        for my $pkg (qw(xorgxrdp xorg-x11-server)) {
            push @required, $pkg if script_run("zypper -n info $pkg", quiet => 1) == 0;
        }
    }

    my @missing = grep { script_run("zypper -n info $_", quiet => 1) != 0 } @required;
    if (@missing) {
        record_info('SKIP', 'not available in the configured repositories: ' . join(', ', @missing));
        return;
    }

    install_package(join(' ', @required), trup_continue => 1, trup_reboot => 1);

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testXrdp',
            domain => 'console',
            run_timeout => 900,
            skip_phub => 1,
        });
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;
