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
use Utils::Architectures qw(is_x86_64 is_aarch64);
use agnosticTestRunner;

sub run {
    select_serial_terminal;
    if (!is_tumbleweed() && !is_sle()) {
        record_info('SKIP', 'xrdp is only tested on Tumbleweed and SLE');
        return;
    }

    my %available;
    my $has = sub {
        my $pkg = shift;
        return $available{$pkg} if exists $available{$pkg};
        return $available{$pkg} = script_run("zypper -n info $pkg", quiet => 1) == 0;
    };
    my $freerdp = $has->('freerdp') ? 'freerdp' : 'freerdp2';
    my @required = ('xrdp', 'xorg-x11-Xvnc', 'xterm', $freerdp, 'xvfb-run', 'xorg-x11-server-Xvfb', 'iproute2', 'xauth');

    # The Xorg backend is optional; the test gates on its presence.
    push @required, grep { $has->($_) } qw(xorgxrdp xorg-x11-server) if is_x86_64 || is_aarch64;

    my @missing = grep { !$has->($_) } @required;
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

sub post_fail_hook {
    my ($self) = @_;
    # Only undo state this test created; never touch a pre-existing rdptest.
    if (script_run('test -f /home/rdptest/.xrdp-agnostic-test') == 0) {
        script_run('pkill -9 -u rdptest');
        script_run('systemctl stop xrdp xrdp-sesman');
        script_run('cp -a /tmp/xrdp-agnostic-backup/xrdp.ini /etc/xrdp/xrdp.ini 2>/dev/null');
        script_run('cp -a /tmp/xrdp-agnostic-backup/sesman.ini /etc/xrdp/sesman.ini 2>/dev/null');
        script_run('userdel -r rdptest');
    }
    upload_logs('/var/log/xrdp.log', failok => 1);
    upload_logs('/var/log/xrdp-sesman.log', failok => 1);
    upload_logs('/tmp/testXrdp_output.log', failok => 1);
    $self->SUPER::post_fail_hook;
}

1;
