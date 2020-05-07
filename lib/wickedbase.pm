# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base module for all wicked scenarios
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

package wickedbase;

use base 'opensusebasetest';
use utils qw(systemctl file_content_replace zypper_call);
use network_utils;
use lockapi;
use testapi qw(is_serial_terminal :DEFAULT);
use serial_terminal;
use Carp;
use Mojo::File 'path';
use Regexp::Common 'net';

use strict;
use warnings;

use constant WICKED_DATA_DIR => '/tmp/wicked/data';

=head2 wicked_command

  wicked_command($action => [ifup|ifdown|ifreaload], $iface)

Executes wicked command given the action on the corresponding interface.

The mandatory parameter C<action> specifies the action [ifup|ifdown|ifreaload].
The mandatory parameter C<iface> specifies the interface which action will be executed on.
This function saves the command and the stdout and stderr to a file to be uploaded later.

=cut
sub wicked_command {
    my ($self, $action, $iface) = @_;
    my $cmd = '/usr/sbin/wicked --log-target syslog ' . $action . ' ' . $iface;
    assert_script_run(q(echo -e "\n# ") . $cmd . ' >> /tmp/wicked_serial.log');
    record_info('wicked cmd', $cmd);
    assert_script_run($cmd . ' 2>&1 | tee -a /tmp/wicked_serial.log');
    assert_script_run(q(echo -e "\n# ip addr" >> /tmp/wicked_serial.log));
    assert_script_run('ip addr 2>&1 | tee -a /tmp/wicked_serial.log');
}

=head2 assert_wicked_state

  assert_wicked_state([wicked_client_down => 0, interfaces_down => 0,
                       wicked_daemon_down => 0, $ping_ip, $iface])

Check that wicked processes are as expected by input arguments. 'Up' by default.

The optional parameters C<wicked_client_down> is given normally with C<interfaces_down> => 1
to verify that wicked.service process is down.
The optional argument C<wicked_daemon_down> is given to verify that wickedd.service is down.
The optional argument C<ping_ip> checks that the IP is reachable.
The optinal argument C<iface> allows to print the output of the command 'ip address show'.
With no arguments, it will check that wicked.service and wickedd.service are up.

=cut
sub assert_wicked_state {
    my ($self, %args) = @_;
    systemctl('is-active wicked.service',  expect_false => $args{wicked_client_down});
    systemctl('is-active wickedd.service', expect_false => $args{wicked_daemon_down});
    assert_script_run(sprintf("grep -q \"%s\" /sys/class/net/%s/operstate", $args{interfaces_down} ? 'down' : 'up', $args{iface}));
    $self->ping_with_timeout(ip => $args{ping_ip}) if $args{ping_ip};
}


sub reset_wicked {
    my $self = @_;
    # Remove any config file and leave the system clean to start tests
    script_run('find /etc/sysconfig/network/ -name "ifcfg-*" | grep -v "ifcfg-lo" | xargs rm');
    script_run('rm -f route');

    # Remove any previous manual ip configuration
    my $iface = iface();
    script_run("ip a flush dev $iface");
    script_run('ip r flush all');
    script_run("ip link set dev $iface down");

    file_content_replace("/etc/sysconfig/network/config", "^NETCONFIG_DNS_STATIC_SERVERS=.*" => " ");
    assert_script_run("netconfig -f update");

    # Restart services
    script_run('rcwickedd restart');
    script_run('rcwicked restart');
}


=head2 get_remote_ip

  get_remote_ip(type => $type [, netmask => 0])

Calls internally C<get_ip()> and retrieves the corresponding IP of the remote site.

=cut

sub get_remote_ip {
    my ($self, %args) = @_;
    $args{is_wicked_ref} = !check_var('IS_WICKED_REF', '1');
    return $self->get_ip(%args);
}

=head2 get_ip

  get_ip(type => [host|gre1|sit1|tunl1|tun1|br0|vlan|vlan_changed] [, is_wicked_ref => check_var('IS_WICKED_REF', '1'), netmask => 0])

Retrives IP address as C<string> in IPv4 or IPv6 format and netmask prefix if C<netmask> is set.

The mandatory parameter C<type> specify the interfaces type.
If parameter C<netmask> is set, the IP address contains the C</xx> netmask prefix, if specified.
With C<is_wicked_ref> you can specify which IP address you like to retrives. If C<is_wicked_ref> isn't
set the job variable C<IS_WICKED_REF> will be used. See also C<get_remote_ip()>.

=cut

sub get_ip {
    my ($self, %args) = @_;
    die '$args{type} is required' unless $args{type};

    $args{is_wicked_ref} //= check_var('IS_WICKED_REF', '1');
    $args{netmask}       //= 0;

    my $ips_hash =
      {
        #                       SUT                       REF
        host         => ['10.0.2.11/15',              '10.0.2.10/15'],
        host6        => ['fd00:deca:fbad:50::11/64',  'fd00:deca:fbad:50::10/64'],
        gre1         => ['192.168.1.2',               '192.168.1.1'],
        sit1         => ['2001:0db8:1234::000f',      '2001:0db8:1234::000e'],
        tunl1        => ['3.3.3.11',                  '3.3.3.10'],
        tun1         => ['192.168.2.11',              '192.168.2.10'],
        tap1         => ['192.168.2.11',              '192.168.2.10'],
        br0          => ['10.0.2.11',                 '10.0.2.10'],
        vlan         => ['192.0.2.11/24',             '192.0.2.10/24'],
        vlan_changed => ['192.0.2.111/24',            '192.0.2.110/24'],
        macvtap      => ['10.0.2.18/15',              '10.0.2.17/15'],
        bond         => ['10.0.2.18',                 '10.0.2.17'],
        dhcp_2nic    => ['10.20.30.',                 '10.20.30.12'],                 # dhcp_2nic in SUT, we don't know the last octect
        second_card  => ['10.0.3.11',                 '10.0.3.12'],
        gateway      => ['10.0.2.2',                  '10.0.2.2'],
        ipv6         => ['fd00:dead:beef:',           'fd00:dead:beef:'],
        dhcp6        => ['fd00:dead:beef:6021:d::11', 'fd00:dead:beef:6021:d::10'],
        dns_advice   => ['fd00:dead:beef:6021::42',   'fd00:dead:beef:6021::42'],
      };
    my $ip = $ips_hash->{$args{type}}->[$args{is_wicked_ref}];
    die "$args{type} not exists" unless $ip;

    if (!$args{netmask}) {
        $ip =~ s'/\d+$'';
    }
    return $ip;
}

=head2 get_current_ip

  get_current_ip(ifc => $interface [, ip_version => 'v4'])

Gets the IP of a given interface by C<ifc>.

The parameter C<ip_version> chould be one of the values 'v4' or 'v6'.

=cut
sub get_current_ip {
    my ($self, $ifc, %args) = @_;
    $args{ip_version} //= 'v4';
    die("Missing mandatory parameter ifc") unless ($ifc);

    my $out = script_output('ip -o ' . ($args{ip_version} eq 'v6' ? '-6' : '-4') . ' addr list ' . $ifc . ' | awk \'{print $4}\' | cut -d/ -f1');
    my @ips = split('\r?\n', $out);

    return $ips[0] if (@ips);
    return;
}

=head2 download_data_dir

Download all files from data/wicked into WICKED_DATA_DIR.
This method is used by before_test.pm.
=cut
sub download_data_dir {
    assert_script_run("mkdir -p '" . WICKED_DATA_DIR . "'");
    assert_script_run("(cd '" . WICKED_DATA_DIR . "'; curl -L -v " . autoinst_url . "/data/wicked > wicked.data && cpio -id < wicked.data && mv data wicked && rm wicked.data)");
}

=head2 get_from_data

  get_from_data($source, $target [, executable => 0, add_suffix => 0])

Downloads to the current VM a file from the data directory given by C<source> and stores it in C<target>.

If the parameter C<add_suffix> is set to 1, it will append 'ref' or 'sut' at the end of the filename.
If the parameter C<executable> is set to 1, it will grant execution permissions to the file.

=cut
sub get_from_data {
    my ($self, $source, $target, %args) = @_;

    $source .= check_var('IS_WICKED_REF', '1') ? 'ref' : 'sut' if $args{add_suffix};
    # we know we fail on other directories than data/wicked
    assert_script_run("cp '" . WICKED_DATA_DIR . '/' . $source . "' '$target'");
    assert_script_run("chmod +x '$target'") if $args{executable};
}

=head2 ping_with_timeout

  ping_with_timeout(type => $type[, ip => $ip, timeout => 60, ip_version => 'v4', proceed_on_failure => 0])

Pings a given IP with a given C<timeout>.
C<ip_version> defines the ping command to be used, 'ping' by default and 'ping6' for 'v6'.
IP could be specified directly via C<ip> or using C<type> variable. In case of C<type> variable
it will be bypassed to C<get_remote_ip> function to get IP by label.
If ping fails, command die unless you specify C<proceed_on_failure>.
=cut
sub ping_with_timeout {
    my ($self, %args) = @_;
    $args{ip_version}         //= 'v4';
    $args{timeout}            //= '60';
    $args{proceed_on_failure} //= 0;
    $args{count_success}      //= 1;
    $args{ip} = $self->get_remote_ip(%args) if $args{type};
    $args{threshold} //= 50;
    my $timeout      = $args{timeout};
    my $ping_command = ($args{ip_version} eq "v6") ? "ping6" : "ping";
    $ping_command .= " -c 1 $args{ip}";
    $ping_command .= " -I $args{interface}" if $args{interface};
    while ($timeout > 0) {
        if (script_run($ping_command) == 0) {
            if ($args{count_success} > 1) {
                my $cnt = $args{count_success} - 1;
                $ping_command =~ s/\s-c\s1\s+/ -c $cnt /;
                my $ping_out = script_output($ping_command, proceed_on_failure => 1);
                $ping_out =~ /, (\d{1,3})% packet loss/;
                #we treat interface in workable state if it manage to echo more than half packets
                if ($1 > $args{threshold}) {
                    die('PING EXCEED THRESHOLD ' . $args{threshold} . '%\n' . $ping_out);
                }
                elsif ($1) {
                    record_info('WARNING', sprintf('PING with %d%% packet loss. Threshold is %d%% \n %s', $1, $args{threshold}, $ping_out));
                }
            }
            return 1;
        }
        $timeout -= 1;
        sleep 5;
    }
    if (!$args{proceed_on_failure}) {
        die('PING failed: ' . $ping_command);
    }
    return 0;
}


=head2 setup_tuntap

  setup_tuntap($config, $type => [tun1|tap1])

Setups a TUN or TAP interface from a C<config> file with the keywords 'local_ip' and 'remote_ip' which
will be replaced with the corresponding IPs.
The mandatory parameter C<type> determines if it will configure a TUN device or a TAP device.
The interface will be brought up using a wicked command.

=cut
sub setup_tuntap {
    my ($self, $config, $type, $iface) = @_;
    my $local_ip  = $self->get_ip(type => $type);
    my $remote_ip = $self->get_remote_ip(type => $type);
    my $host_ip   = $self->get_ip(type => 'host');
    file_content_replace($config, local_ip => $local_ip, remote_ip => $remote_ip, host_ip => $host_ip, iface => $iface);
    $self->wicked_command('ifup', 'all');
}

=head2 setup_tunnel

  setup_tunnel($config, $type => [gre1|sit1|tunl1|tun1])

Setups a tunnel interface from a C<config> file with the keywords 'local_ip', 'remote_ip' and 'tunnel_ip' which
will be replaced with the corresponding IPs. The mandatory parameter C<type> should determine the interface to be configured.
The interface will be brought up using a wicked command.

=cut
sub setup_tunnel {
    my ($self, $config, $type, $iface) = @_;
    my $local_ip  = $self->get_ip(type => 'host');
    my $remote_ip = $self->get_remote_ip(type => 'host');
    my $tunnel_ip = $self->get_ip(type => $type);
    file_content_replace($config, local_ip => $local_ip, remote_ip => $remote_ip, tunnel_ip => $tunnel_ip, iface => $iface);
    $self->wicked_command('ifup', 'all');
}

=head2 create_tunnel_with_commands

  create_tunnel_with_commands($type => [gre1|sit1|tunl1|tun1], $mode => [gre|sit|ipip|tun], $sub_mask)

Setups a TUNL interface with IP commands (no wicked commands!).
The parameter C<type> determines the interface to be configured and C<mode> the type of tunnel.
Supported tunnels in this function are GRE, SIT, IPIP, TUN.

=cut
sub create_tunnel_with_commands {
    my ($self, $type, $mode, $sub_mask) = @_;
    my $local_ip  = $self->get_ip(type => 'host');
    my $remote_ip = $self->get_remote_ip(type => 'host');
    my $tunnel_ip = $self->get_ip(type => $type);
    assert_script_run("ip tunnel add $type mode $mode remote $remote_ip local $local_ip");
    assert_script_run("ip link set $type up");
    assert_script_run("ip addr add $tunnel_ip/$sub_mask dev $type");
    assert_script_run("ip addr");
}

=head2 setup_bridge

  setup_bridge($config, $command => [ifup, ifdown, ifreload] [, $dummy])

Setups a bridge interface from a C<config> file with the keywords 'local_ip' which
will be replaced with the corresponding IP. If C<dummy> is given, it will also configure the
dummy interface using the config file given by this parameter.
C<command> determines the wicked command to bring up/down the interface

=cut
sub setup_bridge {
    my ($self, $config, $dummy, $command) = @_;
    my $local_ip = $self->get_ip(type => 'host');
    my $iface    = iface();
    file_content_replace($config, ip_address => $local_ip, iface => $iface);
    $self->wicked_command($command, 'all');
    if ($dummy ne '') {
        assert_script_run("cat $dummy");
        $self->wicked_command($command, 'dummy0');
    }
}

=head2 setup_openvpn_client

  setup_openvpn_client($device => [tun1, tap1])

Setups the openvpn client using the interface given by C<device>

=cut
sub setup_openvpn_client {
    my ($self, $device) = @_;
    my $openvpn_client = '/etc/openvpn/client.conf';
    my $remote_ip      = $self->get_remote_ip(type => 'host');
    $self->get_from_data('wicked/openvpn/client.conf', $openvpn_client);
    file_content_replace($openvpn_client, remote_ip => $remote_ip, device => $device);
}

=head2 get_test_result

  get_test_result($type, $ip_version => v4)

It returns FAILED or PASSED if the ping to the remote IP of a certain interface type given by C<type> is reachable or not.
The parameter C<ip_version> chould be one of the values 'v4' or 'v6'.

=cut
sub get_test_result {
    my ($self, $type, $ip_version) = @_;
    my $timeout = "60";
    my $ip      = $self->get_remote_ip(type => $type);
    my $ret     = $self->ping_with_timeout(ip => "$ip", timeout => "$timeout", ip_version => $ip_version);
    if (!$ret) {
        record_info("PING FAILED", "Can't ping IP $ip", result => 'fail');
        return "FAILED";
    }
    else {
        return "PASSED";
    }
}

=head2 upload_wicked_logs

  upload_wicked_logs($prefix => [pre|post])

Gathers all the needed wicked information and compiles a compressed file that get's uploaded to the openqa instance.
This function is normally called before and after a test is executed, the parameter C<prefix> is used to to be appended
to the file name to be uploaded. Normally 'pre' or 'post', but could be any string.

=cut
sub upload_wicked_logs {
    my ($self, $prefix) = @_;
    my $dir_name = $self->{name} . '_' . $prefix;
    my $logs_dir = "/tmp/$dir_name";
    # because all later commands ignoring any error we need to prove
    # that there is sense to do something at all
    assert_script_run('echo "CHECK CONSOLE"', fail_message => 'Console not usable. Failed to collect logs');
    record_info('Logs', "Collecting logs in $logs_dir");
    script_run("mkdir -p $logs_dir");
    script_run("date +'%Y-%m-%d %T.%6N' > $logs_dir/date");
    script_run("journalctl -b -o short-precise|tail -n +2 > $logs_dir/journalctl.log");
    script_run("wicked ifstatus --verbose all > $logs_dir/wicked_ifstatus.log 2>&1");
    script_run("wicked show-config > $logs_dir/wicked_config.log 2>&1");
    script_run("wicked show-xml > $logs_dir/wicked_xml.log 2>&1");
    script_run("ip addr show > $logs_dir/ip_addr.log 2>&1");
    script_run("ip route show table all > $logs_dir/ip_route.log 2>&1");
    script_run("cat /etc/resolv.conf > $logs_dir/resolv.conf 2>&1");
    script_run("cp /tmp/wicked_serial.log $logs_dir/") if $prefix eq 'post';
    script_run("tar -C /tmp/ -cvzf $dir_name.tar.gz $dir_name");
    eval {
        select_console('root-virtio-terminal1') if (get_var('VIRTIO_CONSOLE_NUM', 1) > 1);
        upload_file("$dir_name.tar.gz", "$dir_name.tar.gz");
    };
    record_info('Failed to upload logs', $@, result => 'fail') if ($@);
    $self->select_serial_terminal;
}

=head2 do_barrier

  do_barrier(<barrier_postfix>)

Used to syncronize the wicked tests for SUT and REF creating the corresponding mutex locks.

=cut
sub do_barrier {
    my ($self, $type) = @_;
    my $barrier_name = 'test_' . $self->{name} . '_' . $type;
    barrier_wait($barrier_name);
}

=head2 setup_vlan

    setup_vlan($ip_type)

Creating VLAN using only ip commands. Getting ip alias name for wickedbase::get_ip
function

=cut
sub setup_vlan {
    my ($self, $ip_type) = @_;
    my $iface    = iface();
    my $local_ip = $self->get_ip(type => $ip_type, netmask => 1);
    assert_script_run("ip link add link $iface name $iface.42 type vlan id 42");
    assert_script_run('ip link');
    assert_script_run("ip -d link show $iface.42");
    assert_script_run("ip addr add $local_ip dev $iface.42");
    assert_script_run("ip link set dev $iface.42 up");
}

sub prepare_check_macvtap {
    my ($self, $config, $iface, $ip_address) = @_;
    $self->get_from_data('wicked/check_macvtap.c', 'check_macvtap.c', executable => 1);
    assert_script_run('gcc ./check_macvtap.c -o check_macvtap');
    script_run('chmod +x ./check_macvtap');
    file_content_replace($config, iface => $iface, ip_address => $ip_address);
}

sub validate_macvtap {
    my ($self, $macvtap_log) = @_;
    my $ref_ip     = $self->get_ip(type => 'host',    netmask => 0, is_wicked_ref => 1);
    my $ip_address = $self->get_ip(type => 'macvtap', netmask => 0);
    script_run("./check_macvtap $ref_ip $ip_address > $macvtap_log 2>&1 & export CHECK_MACVTAP_PID=\$!");
    sleep(30);    # OVS on a worker is slow sometimes to change and we haven't found better way how to handle it

    # arping not getting packet back it is expected because check_macvtap
    # executable is consume it from tap device before it actually reaches arping
    script_run("arping -c 1 -I macvtap1 $ref_ip");
    assert_script_run('time wait ${CHECK_MACVTAP_PID}', timeout => 90);
    validate_script_output("cat $macvtap_log", sub { m/Success listening to tap device/ });
}

sub setup_bond {
    my ($self, $mode, $iface0, $iface1) = @_;

    my $cfg_bond0 = '/etc/sysconfig/network/ifcfg-bond0';
    my $cfg_ifc0  = '/etc/sysconfig/network/ifcfg-' . $iface0;
    my $cfg_ifc1  = '/etc/sysconfig/network/ifcfg-' . $iface1;
    $self->get_from_data('wicked/ifcfg/ifcfg-eth0-hotplug',     $cfg_ifc0);
    $self->get_from_data('wicked/ifcfg/ifcfg-eth0-hotplug',     $cfg_ifc1);
    $self->get_from_data('wicked/bonding/ifcfg-bond0-' . $mode, $cfg_bond0);

    my $ipaddr4   = $self->get_ip(type => 'host',        netmask       => 1);
    my $ipaddr6   = $self->get_ip(type => 'host6',       netmask       => 1);
    my $ping_ip_1 = $self->get_ip(type => 'host',        is_wicked_ref => 1);
    my $ping_ip_2 = $self->get_ip(type => 'second_card', is_wicked_ref => 1);

    file_content_replace($cfg_bond0, ipaddr4 => $ipaddr4, ipaddr6 => $ipaddr6, iface0 => $iface0, iface1 => $iface1, ping_ip_1 => $ping_ip_1, ping_ip_2 => $ping_ip_2, '--sed-modifier' => 'g');

    $self->wicked_command('ifup', 'all');
}

sub setup_team {
    my ($self, $mode, $iface0, $iface1) = @_;

    my $cfg_team0 = '/etc/sysconfig/network/ifcfg-team0';
    my $cfg_ifc0  = '/etc/sysconfig/network/ifcfg-' . $iface0;
    my $cfg_ifc1  = '/etc/sysconfig/network/ifcfg-' . $iface1;

    my $data_ifcfg = 'wicked/ifcfg/ifcfg-eth0-hotplug';
    $data_ifcfg .= '-static' if ($mode eq 'ab-nsna_ping');

    $self->get_from_data($data_ifcfg,                           $cfg_ifc0);
    $self->get_from_data($data_ifcfg,                           $cfg_ifc1);
    $self->get_from_data('wicked/teaming/ifcfg-team0-' . $mode, $cfg_team0);

    my $ipaddr4  = $self->get_ip(type => 'host',  netmask       => 1);
    my $ipaddr6  = $self->get_ip(type => 'host6', netmask       => 1);
    my $ping_ip4 = $self->get_ip(type => 'host',  is_wicked_ref => 1);
    my $ping_ip6 = $self->get_ip(type => 'host6', is_wicked_ref => 1);
    file_content_replace($cfg_team0, ipaddr4 => $ipaddr4, ipaddr6 => $ipaddr6, iface0 => $iface0, iface1 => $iface1, ping_ip4 => $ping_ip4, ping_ip6 => $ping_ip6);

    $self->wicked_command('ifup', 'all');
}

sub get_active_link {
    my ($self, $link) = @_;
    if ($link =~ /bond/) {
        return $1 if (script_output("cat /proc/net/bonding/$link") =~ m/Active Slave: (\w+)/);
    }
    elsif ($link =~ /team/) {
        return $1 if (script_output("teamdctl $link state view") =~ m/active port: (\w+)/);
    }
    return;
}

sub validate_interfaces {
    my ($self, $interface, $iface0, $iface1, $ping) = @_;
    $ping //= 1;
    if (!ifc_is_up($interface)) {
        record_info('ip addr', script_output('ip addr'));
        die("Interface $interface does not exist or is not UP");
    }
    validate_script_output('ip a s dev ' . $iface0, sub { /master $interface/ }) if $iface0;
    validate_script_output('ip a s dev ' . $iface1, sub { /master $interface/ }) if $iface1;
    $self->ping_with_timeout(type => 'host', interface => $interface, count_success => 30, timeout => 4) if ($ping);
}

sub check_fail_over {
    my ($self, $interface, $timeout) = @_;
    $timeout //= get_var('FAILOVER_TIMEOUT', 60);
    my $active_link = undef;
    $active_link = $self->get_active_link($interface);
    $self->ifbind('unbind', $active_link);

    while ($timeout >= 0) {
        return 1 if ($self->get_active_link($interface) ne $active_link);
        $timeout -= 1;
        sleep 1;
    }
    die('Active Link is the same after interface cut');
}

=head2 sync_start_of

  sync_start_of($service, $mutex, [,$timeout])

Start C<$service> within defined $timeout ( default is 60).
After succesfully service start will create mutex with C<$mutex>
which can be used by parallel test to catch this event

=cut
sub sync_start_of {
    my ($self, $service, $mutex, $tries) = @_;
    $tries //= 12;
    if (script_run("systemctl start $service.service") == 0) {
        while ($tries > 0) {
            if (script_run("systemctl is-active $service.service") == 0) {
                record_info($service, $service . ' is active');
                die("Create mutex failed") unless mutex_create($mutex);
                return 0;
            }
            $tries -= 1;
            sleep 5;
        }
    }
    # if we get here means that service failed to start
    script_run("journalctl -u $service -o short-precise");
    # we creating this mutex anyway even so we know that we fail to start service
    # to not cause dead-lock
    die("Create mutex failed") unless mutex_create($mutex);
    die("Failed to start $service");
}

sub ifbind {
    my ($self, $action, $interface) = @_;
    my $cmd = 'bash ' . WICKED_DATA_DIR . "/wicked/ifbind.sh $action $interface";
    record_info('ifbind', $cmd . "\n" . script_output($cmd));
}

sub check_ipv6 {
    my ($self, $ctx) = @_;
    my $gateway             = $self->get_ip(type => 'gateway');
    my $ipv6_network_prefix = $self->get_ip(type => 'ipv6');
    my $ipv6_dns            = $self->get_ip(type => 'dns_advice');
    $self->get_from_data('wicked/ifcfg/ipv6', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->wicked_command('ifup', $ctx->iface());
    assert_script_run('rdisc6 ' . $ctx->iface());
    $self->wicked_command('ifdown', $ctx->iface());
    $self->wicked_command('ifup',   $ctx->iface());
    my $errors = 0;
    my $tries  = 12;
    my $no_ip  = 1;
    my $output = '';
    while ($tries > 0 && $no_ip) {
        $no_ip  = 0;
        $output = script_output('ip a s dev ' . $ctx->iface());
        unless ($output =~ /inet $RE{net}{IPv4}/) {
            record_info('Waiting for IPv4');
            $no_ip = 1;
        }
        unless ($output =~ /inet6 $RE{net}{IPv6}/) {
            record_info('Waiting for IPv6');
            $no_ip = 1;
        }
        $tries -= 1;
        sleep(5);
    }
    $errors = $no_ip;

    unless ($output !~ /tentative/) {
        record_info('FAIL', 'tentative word presented', result => 'fail');
        $errors = 1;
    }
    unless ($output =~ /inet6 $ipv6_network_prefix/m) {
        record_info('FAIL', 'no prefix for local network route', result => 'fail');
        $errors = 1;
    }

    $output = script_output('ip -6 r s');

    unless ($output =~ /^default/m) {
        record_info('FAIL', 'no default route presented', result => 'fail');
        $errors = 1;
    }

    $output = script_output('ip -6 -o r s');

    unless ($output =~ /^default.*proto ra/m) {
        record_info('FAIL', 'IPv6 default route comes not from RA', result => 'fail');
        $errors = 1;
    }

    $tries = 12;
    my $dns_failure = 1;
    while ($tries > 0 && $dns_failure) {
        $dns_failure = 0;
        $output      = script_output('cat /etc/resolv.conf');

        unless ($output =~ /^nameserver $gateway/m) {
            record_info('IPv4 DNS', 'IPv4 DNS is missing in resolv.conf');
            $dns_failure = 1;
        }

        unless ($output =~ /^nameserver $ipv6_dns/m) {
            record_info('IPv6 DNS', 'IPv6 DNS is missing in resolv.conf');
            $dns_failure = 1;
        }
        $tries -= 1;
        sleep(5);
    }

    die "There were errors during test" if $errors || $dns_failure;
}

sub post_run {
    my ($self) = @_;
    $self->{wicked_post_run} = 1;

    $self->do_barrier('post_run');
    if ($self->{name} ne 'before_test' && get_var('WICKED_TCPDUMP')) {
        script_run('kill ' . get_var('WICKED_TCPDUMP_PID'));
        eval {
            select_console('root-virtio-terminal1') if (get_var('VIRTIO_CONSOLE_NUM', 1) > 1);
            upload_file('/tmp/tcpdump' . $self->{name} . '.pcap', 'tcpdump' . $self->{name} . '.pcap');
        };
        record_info('Failed to upload tcp', $@, result => 'fail') if ($@);
        $self->select_serial_terminal();
    }
    $self->upload_wicked_logs('post');
}

sub pre_run_hook {
    my ($self) = @_;
    $self->select_serial_terminal();
    my $coninfo = '## START: ' . $self->{name};
    wait_serial(serial_term_prompt(), undef, 0, no_regex => 1);
    type_string($coninfo);
    wait_serial($coninfo, undef, 0, no_regex => 1);
    type_string("\n");
    if ($self->{name} eq 'before_test' && get_var('VIRTIO_CONSOLE_NUM', 1) > 1) {
        my $serial_terminal = check_var('ARCH', 'ppc64le') ? 'hvc2' : 'hvc1';
        add_serial_console($serial_terminal);
    }
    if ($self->{name} ne 'before_test' && get_var('WICKED_TCPDUMP')) {
        script_run('tcpdump -s0 -U -w /tmp/tcpdump' . $self->{name} . '.pcap >& /dev/null & export CHECK_TCPDUMP_PID=$!');
        set_var('WICKED_TCPDUMP_PID', script_output('echo $CHECK_TCPDUMP_PID'));
    }
    $self->upload_wicked_logs('pre');
    $self->do_barrier('pre_run');
}

sub post_fail_hook {
    my ($self) = @_;
    $self->post_run() unless $self->{wicked_post_run};
}

sub post_run_hook {
    my ($self) = @_;
    $self->post_run() unless $self->{wicked_post_run};
}

1;
