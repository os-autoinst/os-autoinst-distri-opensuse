# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: salt-master salt-minion
# Summary: Test installation of salt-master as well as salt-minion on same
#  machine. Test simple operation with loopback.
# - Add suse connect product according to distribution in test
# - Stop packagekit service
# - Install salt-master salt-minion
# - Start salt-master service, check its status
# - Configure and start salt-minion, check its status
# - Run "salt-run state.event tagmatch="salt/auth" quiet=True count=1"
# - Run "salt-key --accept-all -y"
# - Ping the minion. If fails, try again 7 times.
# - Stop both minion and master
# Maintainer: QE Core <qe-core@suse.de>
# Tags: fate#318875, fate#320919

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call quit_packagekit systemctl);
use version_utils qw(is_jeos is_opensuse);
use registration 'add_suseconnect_product';

sub run {
    select_serial_terminal;
    if (is_jeos && !is_opensuse) {
        my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
        if ($version == '12') {
            add_suseconnect_product('sle-module-adv-systems-management', $version);
        }
        elsif ($version == '15') {
            $version = get_required_var('VERSION') =~ s/([0-9]+)-SP([0-9]+)/$1.$2/r;
            add_suseconnect_product('sle-module-server-applications', "$version");
        }
    }

    quit_packagekit;
    zypper_call('in salt-master salt-minion');
    my $cmd = <<'EOF';
systemctl start salt-master
systemctl status --no-pager salt-master
sed -i -e "s/#master: salt/master: localhost/" /etc/salt/minion
systemctl start salt-minion
systemctl status --no-pager salt-minion
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
    # before accepting the key, wait until the minion is fully started (systemd might be not reliable)
    assert_script_run('salt-run state.event tagmatch="salt/auth" quiet=True count=1', timeout => 300);
    assert_script_run("salt-key --accept-all -y");
    # try to ping the minion. If it does not respond on the first try the ping
    # might have gone lost so try more often. Also see bsc#1069711
    assert_script_run 'for i in {1..7}; do echo "try $i" && salt \'*\' test.ping -t30 && break; done', timeout => 300;

    systemctl 'stop salt-master salt-minion', timeout => 120;
}

1;
