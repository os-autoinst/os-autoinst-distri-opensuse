=head1 network_utils

Functional methods to operate on network

=cut
# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Functional methods to operate on network
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
package network_utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use mm_network;

our @EXPORT = qw(setup_static_network recover_network can_upload_logs iface ifc_exists ifc_is_up fix_missing_nic_config);

=head2 setup_static_network

 setup_static_network(ip => '10.0.2.15', gw => '10.0.2.1');

Configure static IP on SUT with setting up default GW.
Also doing test ping to 10.0.2.2 to check that network is alive
Set DNS server defined via required variable C<STATIC_DNS_SERVER>

=cut
sub setup_static_network {
    my (%args) = @_;
    # Set default values
    $args{ip} ||= '10.0.2.15';
    $args{gw} ||= testapi::host_ip();
    configure_static_dns(get_host_resolv_conf());
    assert_script_run('echo default ' . $args{gw} . ' - - > /etc/sysconfig/network/routes');
    my $iface = iface();
    assert_script_run qq(echo -e "\\nSTARTMODE='auto'\\nBOOTPROTO='static'\\nIPADDR='$args{ip}'">/etc/sysconfig/network/ifcfg-$iface);
    assert_script_run 'rcnetwork restart';
    assert_script_run 'ip addr';
    assert_script_run 'ping -c 1 ' . $args{gw} . '|| journalctl -b --no-pager > /dev/' . $serialdev;
}

=head2 iface

 iface([$quantity]);

Return first NIC which is not loopback

=cut
sub iface {
    my ($quantity) = @_;
    $quantity ||= 1;
    return script_output('ls /sys/class/net/ | grep -v lo | head -' . $quantity);
}

=head2 can_upload_logs

 can_upload_logs([$gw]);

Returns if can ping worker host gateway
=cut
sub can_upload_logs {
    my ($gw) = @_;
    $gw ||= testapi::host_ip();
    return (script_run('ping -c 1 ' . $gw) == 0);
}


=head2 recover_network

 recover_network([ip => $ip] [, gw => $gw]);

Recover network with static config if is feasible, returns if can ping GW.
Main use case is post_fail_hook, to be able to upload logs.

Accepts following parameters :

C<ip> => allowing to specify certain IP which would be used for recovery
in case skiped '10.0.2.15/24' will be used as fallback.

C<gw> => allowing to specify default gateway. Fallback to worker IP in case nothing specified.
=cut
sub recover_network {
    my (%args) = @_;

    # We set static setup just to upload logs, so no permament setup
    # Set default values
    $args{ip} //= '10.0.2.15/24';
    $args{gw} //= testapi::host_ip();
    my $iface = iface();
    # Clean routes and ip address settings
    script_run "ip a flush dev $iface";
    script_run 'ip r flush all';
    # Set expected ip and routes and set interface up
    script_run "ip a a $args{ip} dev $iface";
    script_run "ip r a default via $args{gw} dev $iface";
    script_run "ip link set dev $iface up";
    # Display settings
    script_run 'ip a s';
    script_run 'ip r s';

    return can_upload_logs();
}

=head2 ifc_exists

 ifc_exists([$ifc]);

Return if ifconfig exists.

=cut
sub ifc_exists {
    my ($ifc) = @_;
    return !script_run('ip link show dev ' . $ifc);
}

=head2 ifc_is_up

 ifc_is_up([$ifc]);

Return only if network status is UP.

=cut
sub ifc_is_up {
    my ($ifc) = @_;
    return !script_run("ip link show dev $ifc | grep 'state UP'");
}

sub fix_missing_nic_config {
    # poo#60245, bsc#1157896 (originally poo#18762): workaround for missing NIC configuration.
    my $conf_nic_script = << 'EOF';
dir=/sys/class/net
ifaces="`basename -a $dir/* | grep -v -e ^lo -e ^tun -e ^virbr -e ^vnet`"
CREATED_NIC=
ip link; ip addr
for iface in $ifaces; do
    config=/etc/sysconfig/network/ifcfg-$iface
    if [ "`cat $dir/$iface/operstate`" = "down" ] && [ ! -e $config ]; then
        echo "WARNING: create config '$config'" >&2
        printf "BOOTPROTO='dhcp'\nSTARTMODE='auto'\nDHCLIENT_SET_DEFAULT_ROUTE='yes'\n" > $config
        CREATED_NIC="$CREATED_NIC $iface"
        systemctl restart network
        sleep 1
    fi
done
export CREATED_NIC
echo "created NIC: '$CREATED_NIC'"
ip link; ip addr
EOF
    script_output($conf_nic_script, proceed_on_failure => 1);

    my $created_nic = script_output('echo $CREATED_NIC');
    bmwqemu::fctinfo("created NIC: '$created_nic'");
    if ($created_nic) {
        record_soft_failure("bsc#1157896, poo#60245: Added missing config for NIC: '$created_nic', restarted network");
    }
}

1;
