# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
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
    # utils
    zypper_call('in wget iptables psmisc tcpdump ethtool', log => 'utils.log');

    # clients
    zypper_call('in dhcp-client telnet', log => 'clients.log');

    # services
    zypper_call('in dhcp-server dnsmasq nfs-kernel-server rpcbind rsync vsftpd', log => 'services.log');
}

sub setup {
    my $content;

    $content = <<EOF;
# ltp specific setup
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
    assert_script_run("echo \"$content\" >> '/etc/securetty'");

    # ftp
    assert_script_run('sed -i \'s/^\s*\(root\)\s*$/# \1/\' /etc/ftpusers');

    # getaddrinfo_01: missing hostname in /etc/hosts
    assert_script_run('h=`hostname`; grep -q $h /etc/hosts || printf "# ltp\n127.0.0.1\t$h\n::1\t$h\n" >> /etc/hosts');

    # boo#1017616: missing link to ping6 in iputils >= s20150815
    assert_script_run('which ping6 >/dev/null 2>&1 || ln -s `which ping` /usr/local/bin/ping6');

    # dhcpd
    assert_script_run('touch /var/lib/dhcp/db/dhcpd.leases /var/lib/dhcp6/db/dhcpd6.leases');

    # echo/echoes, getaddrinfo_01
    assert_script_run('sed -i \'s/^\(hosts:\s+files\s\+dns$\)/\1 myhostname/\' /etc/nsswitch.conf');

    # SLE12GA uses too many old style services
    my $action = check_var('VERSION', '12') ? "enable" : "reenable";

    foreach my $service (qw(dnsmasq nfsserver rpcbind vsftpd)) {
        systemctl($action . " " . $service);
        assert_script_run("systemctl start $service || { systemctl status --no-pager $service; journalctl -xe --no-pager; false; }");
    }
}

# poo#14402
sub run {
    select_console(get_var('VIRTIO_CONSOLE') ? 'root-virtio-terminal' : 'root-console');
    install;
    setup;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Discussion

See poo#16648 for disabled LTP networking related tests.

=cut

# vim: set sw=4 et:
