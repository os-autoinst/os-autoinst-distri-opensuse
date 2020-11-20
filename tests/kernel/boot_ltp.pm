# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Waits for the guest to boot, sets some variables for LTP then
#          dynamically loads the test modules based on the runtest file
#          contents.
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use LTP::WhiteList 'download_whitelist';
use LTP::utils;
use version_utils 'is_jeos';
use utils 'assert_secureboot_status';

sub run {
    my ($self) = @_;
    my $cmd_file = get_var('LTP_COMMAND_FILE') || '';
    my $is_network = $cmd_file =~ m/^\s*(net|net_stress)\./;
    my $is_ima     = $cmd_file =~ m/^ima$/i;

    if (check_var('BACKEND', 'ipmi')) {
        record_info('INFO', 'IPMI boot');
        select_console 'sol', await_console => 0;
        assert_screen('linux-login', 1800);
    }
    elsif (is_jeos) {
        record_info('Loaded JeOS image', 'nothing to do...');
    }
    else {
        record_info('INFO', 'normal boot or boot with params');
        # during install_ltp, the second boot may take longer than usual
        $self->wait_boot(ready_time => 1800);
    }

    $self->select_serial_terminal;
    assert_secureboot_status(1) if (get_var('SECUREBOOT'));

    download_whitelist if get_var('LTP_KNOWN_ISSUES');

    # check kGraft patch if KGRAFT=1
    if (check_var('KGRAFT', '1') && !check_var('REMOVE_KGRAFT', '1')) {
        assert_script_run("uname -v| grep -E '(/kGraft-|/lp-)'");
    }

    prepare_ltp_env();
    script_run('env');
    upload_logs('/boot/config-$(uname -r)', failok => 1);

    my $kernel_pkg_log = '/tmp/kernel-pkg.txt';
    script_run('rpm -qi ' . ((is_jeos) ? 'kernel-default-base' : 'kernel-default') . " > $kernel_pkg_log 2>&1");
    upload_logs($kernel_pkg_log, failok => 1);

    my $ver_linux_log = '/tmp/ver_linux_before.txt';
    script_run("\$LTPROOT/ver_linux > $ver_linux_log 2>&1");
    upload_logs($ver_linux_log, failok => 1);

    script_run('ps axf') if ($is_network || $is_ima);

    script_run('aa-enabled; aa-status');

    if ($is_network) {
        # emulate $LTPROOT/testscripts/network.sh
        assert_script_run('curl ' . data_url("ltp/net.sh") . ' -o net.sh', 60);
        assert_script_run('chmod 755 net.sh');
        assert_script_run('. ./net.sh');

        script_run('env');

        # Disable IPv4 and IPv6 iptables.
        # Disabling IPv4 is needed for iptables tests (net.tcp_cmds).
        # Disabling IPv6 is needed for ICMPv6 tests (net.ipv6).
        # This must be done after stopping network service and loading
        # test_net.sh script.
        my $disable_iptables_script = << 'EOF';
iptables -P INPUT ACCEPT;
iptables -P OUTPUT ACCEPT;
iptables -P FORWARD ACCEPT;
iptables -t nat -F;
iptables -t mangle -F;
iptables -F;
iptables -X;

ip6tables -P INPUT ACCEPT;
ip6tables -P OUTPUT ACCEPT;
ip6tables -P FORWARD ACCEPT;
ip6tables -t nat -F;
ip6tables -t mangle -F;
ip6tables -F;
ip6tables -X;
EOF
        script_output($disable_iptables_script);
        # display resulting iptables
        script_run('iptables -L');
        script_run('iptables -S');
        script_run('ip6tables -L');
        script_run('ip6tables -S');

        # display various network configuration
        script_run('netstat -nap');

        script_run('cat /etc/resolv.conf');
        script_run('f=/etc/nsswitch.conf; [ ! -f $f ] && f=/usr$f; cat $f');
        script_run('cat /etc/hosts');

        # hostname (getaddrinfo_01)
        script_run('hostnamectl');
        script_run('cat /etc/hostname');

        script_run('ip addr');
        script_run('ip netns exec ltp_ns ip addr');
        script_run('ip route');
        script_run('ip -6 route');

        script_run('ping -c 2 $IPV4_LNETWORK.$LHOST_IPV4_HOST');
        script_run('ping -c 2 $IPV4_RNETWORK.$RHOST_IPV4_HOST');
        script_run('ping6 -c 2 $IPV6_LNETWORK:$LHOST_IPV6_HOST');
        script_run('ping6 -c 2 $IPV6_RNETWORK:$RHOST_IPV6_HOST');
    }

    # Check and activate hugepages before test execution
    script_run 'grep -e Huge -e PageTables /proc/meminfo';
    script_run 'echo 1 > /proc/sys/vm/nr_hugepages';
    script_run 'grep -e Huge -e PageTables /proc/meminfo';

    # If the command file (runtest file) is set then we dynamically schedule
    # the test and shutdown modules.
    schedule_tests($cmd_file) if $cmd_file;
}

sub test_flags {
    return {
        fatal     => 1,
        milestone => 1,
    };
}

1;

=head1 Configuration

See run_ltp.pm.

=cut
