# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wrap runltp-ng, should be run on baremetal workers
#
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use File::Basename;

sub ipmitool {
    my ($cmd) = @_;

    my @cmd = ('ipmitool', '-I', 'lanplus', '-H', $bmwqemu::vars{IPMI_HOSTNAME}, '-U', $bmwqemu::vars{IPMI_USER}, '-P', $bmwqemu::vars{IPMI_PASSWORD});
    push(@cmd, split(/ /, $cmd));

    my ($stdin, $stdout, $stderr, $ret);
    print @cmd;
    $ret = IPC::Run::run(\@cmd, \$stdin, \$stdout, \$stderr);
    chomp $stdout;
    chomp $stderr;

    die join(' ', @cmd) . ": $stderr" unless ($ret);
    bmwqemu::diag("IPMI: $stdout");
    return $stdout;
}

sub poweroff_host {
    ipmitool("chassis power off");
    while (1) {
        sleep(3);
        my $stdout = ipmitool('chassis power status');
        last if $stdout =~ m/is off/;
        ipmitool('chassis power off');
    }
}

sub poweron_host {
    ipmitool("chassis power on");
    while (1) {
        sleep(3);
        my $stdout = ipmitool('chassis power status');
        last if $stdout =~ m/is on/;
        ipmitool('chassis power on');
    }
}

sub run {
    my $self = shift;
    my $iso = basename(get_var('ISO'));
    my $scc = get_var('SCC_REGCODE');

    poweron_host;
    select_console 'sol', await_console => 0;
    assert_screen('linux-login', 1800);
    $self->select_serial_terminal;

    zypper_call('in git-core');

    assert_script_run('mount /dev/nvme0n1p2 /mnt && cd /mnt/var/tmp');
    script_run('git clone --recurse-submodules https://gitlab.suse.de/kernel-qa/runltp-support.git');
    assert_script_run('cd runltp-support && git pull --recurse-submodules && ./host-install.sh');
    assert_script_run("./install-setup-run-syzkaller.sh $scc $iso", timeout => 3600);
    assert_script_run('./tar-up-results.sh');
    upload_logs('runltp-ng/results.tar.xz');

    power_action('poweroff');
}

1;
