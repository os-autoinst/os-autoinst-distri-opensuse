# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Waits for the guest to boot and sets some variables for LTP
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use bootloader_setup 'boot_grub_item';
use Utils::Backends 'use_ssh_serial_console';

sub run {
    my ($self, $tinfo) = @_;
    my $ltp_env    = get_var('LTP_ENV');
    my $cmd_file   = get_var('LTP_COMMAND_FILE') || '';
    my $is_network = $cmd_file =~ m/^\s*(net|net_stress)\./;
    my $is_ima     = $cmd_file =~ m/^ima$/i;

    if ($is_ima) {
        # boot kernel with IMA parameters
        boot_grub_item();
    }
    else {
        # during install_ltp, the second boot may take longer than usual
        $self->wait_boot(ready_time => 500);
    }

    if (check_var('BACKEND', 'ipmi')) {
        use_ssh_serial_console;
    }
    else {
        $self->select_serial_terminal;
    }

    assert_script_run('export LTPROOT=/opt/ltp; export LTP_COLORIZE_OUTPUT=n TMPDIR=/tmp PATH=$LTPROOT/testcases/bin:$PATH');

    # setup for LTP networking tests
    assert_script_run("export PASSWD='$testapi::password'");

    my $block_dev = get_var('LTP_BIG_DEV');
    if ($block_dev && get_var('NUMDISKS') > 1) {
        assert_script_run("lsblk -la; export LTP_BIG_DEV=$block_dev");
    }

    # check kGraft patch if KGRAFT=1
    if (check_var('KGRAFT', '1')) {
        assert_script_run("uname -v| grep -E '(/kGraft-|/lp-)'");
    }

    if ($ltp_env) {
        $ltp_env =~ s/,/ /g;
        script_run("export $ltp_env");
    }
    script_run('env');
    upload_logs('/boot/config-$(uname -r)', failok => 1);

    my $ver_linux_log = '/tmp/ver_linux_before.txt';
    script_run("\$LTPROOT/ver_linux > $ver_linux_log 2>&1");
    upload_logs($ver_linux_log, failok => 1);
    my $ver_linux_out = script_output("cat $ver_linux_log");

    if (defined $tinfo) {
        my $environment = {
            product     => get_var('DISTRI') . ':' . get_var('VERSION'),
            revision    => get_var('BUILD'),
            arch        => get_var('ARCH'),
            kernel      => '',
            libc        => '',
            gcc         => '',
            harness     => 'SUSE OpenQA',
            ltp_version => ''
        };
        if ($ver_linux_out =~ qr'^Linux\s+(.*?)\s*$'m) {
            $environment->{kernel} = $1;
        }
        if ($ver_linux_out =~ qr'^Linux C Library\s*>?\s*(.*?)\s*$'m) {
            $environment->{libc} = $1;
        }
        if ($ver_linux_out =~ qr'^Gnu C\s*(.*?)\s*$'m) {
            $environment->{gcc} = $1;
        }
        $environment->{ltp_version} = script_output('touch /opt/ltp_version; cat /opt/ltp_version');
        $tinfo->test_result_export->{environment} = $environment;
    }

    script_run('ps axf') if ($is_network || $is_ima);

    script_run('aa-enabled; aa-status');

    if ($is_network) {
        # poo#18762: Sometimes there is physical NIC which is not configured.
        # One of the reasons can be renaming by udev rule in
        # /etc/udev/rules.d/70-persistent-net.rules. This breaks some tests
        # (even net namespace based ones).
        # Workaround: configure physical NIS (if needed).
        my $conf_nic_script = << 'EOF';
dir=/sys/class/net
ifaces="`basename -a $dir/* | grep -v -e ^lo -e ^tun -e ^virbr -e ^vnet`"
for iface in $ifaces; do
    config=/etc/sysconfig/network/ifcfg-$iface
    if [ "`cat $dir/$iface/operstate`" = "down" ] && [ ! -e $config ]; then
        echo "WARNING: create config '$config'"
        printf "BOOTPROTO='dhcp'\nSTARTMODE='auto'\nDHCLIENT_SET_DEFAULT_ROUTE='yes'\n" > $config
        systemctl restart network
        sleep 1
    fi
done
EOF
        script_output($conf_nic_script);

        # dhclient requires no wicked service not only running but also disabled
        script_run(
            'systemctl --no-pager -p Id show network.service | grep -q Id=wicked.service &&
{ export ENABLE_WICKED=1; systemctl disable wicked; }'
        );

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
        script_run('cat /etc/nsswitch.conf');
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

    assert_script_run('cd $LTPROOT/testcases/bin');
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
