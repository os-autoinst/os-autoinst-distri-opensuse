# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module installs and setup services and other things needed for
# networking part of the LTP (Linux Test Project).
# Maintainer: Petr Vorel <pvorel@suse.cz>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;

sub install {
    my ($rsh_client_packages, $rsh_service_packages, $rsh_services);
    if (check_var('VERSION', 'Tumbleweed')) {
        $rsh_client_packages = 'mrsh-rsh-compat';
        $rsh_service_packages = 'mrsh-server munge';
        $rsh_services = 'mrlogind.socket mrshd.socket munge';
    } else {
        $rsh_client_packages = 'rsh';
        $rsh_service_packages = 'rsh-server';
        $rsh_services = '';
    }

    # utils
    zypper_call("in expect iputils psmisc tcpdump", log => 'utils.log');

    # clients
    zypper_call("in $rsh_client_packages dhcp-client finger telnet", log => 'clients.log');

    # services
    zypper_call("in $rsh_service_packages dhcp-server dnsmasq finger-server nfs-kernel-server rdist rpcbind rsync tcpd telnet-server vsftpd xinetd",
        log => 'services.log');

    my $services = "$rsh_services dnsmasq nfsserver rpcbind vsftpd xinetd";
    assert_script_run "systemctl enable $services";
    assert_script_run "systemctl start $services";
}

sub setup {
    my $content;

    $content = <<EOF;
# ltp specific setup
mrsh
mrlogin
rsh
rlogin
pts/1
pts/2
pts/3
pts/4
pts/5
pts/6
pts/7
pts/8
pts/9
EOF
    assert_script_run "echo \"$content\" >> '/etc/securetty'";

    # xinetd
    my @list = qw(echo finger telnet);
    if (!check_var('VERSION', 'Tumbleweed')) {
        push(@list, qw(rlogin rsh));
    }
    foreach my $xinetd_conf (@list) {
        assert_script_run 'sed -i \'s/\(disable\s*=\s\)yes/\1no/\' /etc/xinetd.d/' . $xinetd_conf;
    }
    assert_script_run 'sed -i \'s/^#\(\s*bind\s*=\)\s*$/\1 0.0.0.0/\' /etc/xinetd.conf';

    # rlogin
    assert_script_run 'echo "+" > /root/.rhosts';

    # ftp
    assert_script_run 'sed -i \'s/^\s*\(root\)\s*$/# \1/\' /etc/ftpusers';

    # getaddrinfo_01: missing hostname in /etc/hosts
    assert_script_run 'h=`hostname`; grep -q $h /etc/hosts || printf "# ltp\n127.0.0.1\t$h\n::1\t$h\n" >> /etc/hosts';

    # boo#1017616: missing link to ping6 in iputils >= s20150815
    assert_script_run 'which ping6 >/dev/null 2>&1 || ln -s `which ping` /usr/local/bin/ping6';

    # dhcpd
    assert_script_run 'touch /var/lib/dhcp/db/dhcpd.leases /var/lib/dhcp6/db/dhcpd6.leases';

    # echo/echoes, getaddrinfo_01
    assert_script_run 'sed -i \'s/^\(hosts:\s+files\s\+dns$\)/\1 myhostname/\' /etc/nsswitch.conf';
}

# poo#14402
sub run {
    select_console(get_var('VIRTIO_CONSOLE') ? 'root-virtio-terminal' : 'root-console');
    install;
    setup;
}

sub test_flags {
    return {
        fatal     => 1,
        milestone => 1
    };
}

1;

# vim: set sw=4 et:
