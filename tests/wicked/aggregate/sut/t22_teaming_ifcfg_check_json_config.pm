# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked teamd
# Summary: Teaming, ifcfg - check link_watch_policy
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use Mojo::JSON qw(decode_json);
use Mojo::JSON::Pointer;
use testapi;

has [qw(ipaddr4 remote_ipaddr4 iface1 iface2)];

sub write_default_cfg()
{
    my ($self) = @_;
    $self->write_cfg('/etc/sysconfig/network/ifcfg-team0', <<EOT);
STARTMODE='auto'
BOOTPROTO='static'
IPADDR='{{ipaddr4}}'

TEAM_RUNNER=activebackup
TEAM_PORT_DEVICE_0='{{iface1}}'
TEAM_PORT_DEVICE_1='{{iface2}}'

TEAM_LW_NAME="ethtool"
TEAM_LW_ETHTOOL_DELAY_UP="10"
TEAM_LW_ETHTOOL_DELAY_DOWN="10"
EOT
}

sub reload_cfg()
{
    my $self = shift;
    record_info('ifcfg-team0', script_output('cat /etc/sysconfig/network/ifcfg-team0'));

    # Note: if we use `wicked ifreload all` or `wicked ifreload team0` we get error messages in the journal like:
    #   wickedd-nanny[746]: device ens5: call to org.opensuse.Network.Interface.linkUp() failed: General failure
    #   wickedd[724]: ens5: unable to find requested master interface 'team0'
    # They are not considered as error, till now thus we don't test them explicitly.
    $self->wicked_command('ifdown', 'all');
    $self->wicked_command('ifup', 'all');
}

sub check_cfg_link_watch_policy()
{
    my ($self) = @_;
    record_info("link_watch_policy");

    $self->write_default_cfg();
    $self->wicked_command('ifup', 'team0');

    # 1) Test with TEAM_LINK_WATCH_POLICY not set, should behave like default and should not be in wicked-config,
    #    but it must be added to the generated teamd.conf file.
    assert_script_run('! (wicked show-config team0 | grep link_watch_policy)');
    assert_script_run('wicked show-xml team0 | grep "<link_watch_policy>any</link_watch_policy>"');

    my $lwp = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get('/link_watch_policy');
    die("Value of link_watch_policy is incorrect -- expect:any got:$lwp") if $lwp ne 'any';

    # 2) Test with TEAM_LINK_WATCH_POLICY=any which is default and should not be in wicked-config,
    #    but it must be added to the generated teamd.conf file.
    assert_script_run('echo "TEAM_LINK_WATCH_POLICY=any" >> /etc/sysconfig/network/ifcfg-team0');
    $self->reload_cfg();
    assert_script_run('! (wicked show-config team0 | grep link_watch_policy)');
    assert_script_run('wicked show-xml team0 | grep "<link_watch_policy>any</link_watch_policy>"');

    $lwp = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get('/link_watch_policy');
    die("Value of link_watch_policy is incorrect -- expect:any got:$lwp") if $lwp ne 'any';


    # 3) Test with TEAM_LINK_WATCH_POLICY=all, must be visible in wicked-config and teamd.conf file.
    assert_script_run("sed -i '/TEAM_LINK_WATCH_POLICY/cTEAM_LINK_WATCH_POLICY=all' /etc/sysconfig/network/ifcfg-team0");
    $self->reload_cfg();

    assert_script_run('wicked show-config team0 | grep "<link_watch_policy>all</link_watch_policy>"');
    assert_script_run('wicked show-xml team0 | grep "<link_watch_policy>all</link_watch_policy>"');
    $lwp = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get('/link_watch_policy');
    die("Value of link_watch_policy is incorrect -- expect:all got:$lwp") if $lwp ne 'all';

    # 4) Ifdown team0 (cleanup)
    $self->wicked_command('ifdown', 'all');
    assert_script_run('! teamdctl team0 config dump actual');
}

sub check_cfg_lw_vlanid()
{
    my ($self) = @_;
    record_info("link_watch.vlanid");

    $self->write_cfg('/etc/sysconfig/network/ifcfg-team0', <<EOT);
STARTMODE='auto'
BOOTPROTO='static'
IPADDR='{{ipaddr4}}'

TEAM_RUNNER=activebackup
TEAM_PORT_DEVICE_0='{{iface1}}'
TEAM_PORT_DEVICE_1='{{iface2}}'

TEAM_LW_NAME_1="arp_ping"
TEAM_LW_ARP_PING_TARGET_HOST_1={{remote_ipaddr4}}
TEAM_LW_ARP_PING_INTERVAL_1=1000
EOT

    $self->wicked_command('ifup', 'team0');

    # 1) Test with TEAM_LINK_ARP_PING_VLANID not set
    assert_script_run('! (wicked show-config team0 | grep vlanid)');
    assert_script_run('! (wicked show-xml team0 | grep vlanid)');
    my $vlanid = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get('/link_watch/0/vlanid');
    die("VLANID should not be set ") if defined($vlanid);

    # 2) Added TEAM_LW_ARP_PING_VLANID
    assert_script_run('echo "TEAM_LW_ARP_PING_VLANID_1=100" >> /etc/sysconfig/network/ifcfg-team0');
    $self->reload_cfg();
    assert_script_run('wicked show-config team0 | grep "<vlanid>100</vlanid>"');
    assert_script_run('wicked show-xml team0 | grep "<vlanid>100</vlanid>"');

    $vlanid = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get('/link_watch/vlanid');
    die("Value of vlanid is incorrect -- expect:100 got:$vlanid") if $vlanid != 100;


    # 3) Changed TEAM_LW_ARP_PING_VLANID
    assert_script_run("sed -i '/TEAM_LW_ARP_PING_VLANID/cTEAM_LW_ARP_PING_VLANID_1=300' /etc/sysconfig/network/ifcfg-team0");
    $self->reload_cfg();
    assert_script_run('wicked show-config team0 | grep "<vlanid>300</vlanid>"');
    assert_script_run('wicked show-xml team0 | grep "<vlanid>300</vlanid>"');

    $vlanid = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get('/link_watch/vlanid');
    die("Value of vlanid is incorrect -- expect:300 got:$vlanid") if $vlanid != 300;

    # 4) Deleted TEAM_LINK_ARP_PING_VLANID
    assert_script_run("sed -i '/TEAM_LW_ARP_PING_VLANID/d' /etc/sysconfig/network/ifcfg-team0");
    $self->reload_cfg();
    assert_script_run('! (wicked show-config team0 | grep vlanid)');
    assert_script_run('! (wicked show-xml team0 | grep vlanid)');
    $vlanid = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get('/link_watch/vlanid');
    die("VLANID should not be set ") if defined($vlanid);


    # 5) Ifdown team0
    $self->wicked_command('ifdown', 'all');
    assert_script_run('! teamdctl team0 config dump actual');
}

sub check_cfg_burst_cfg()
{
    my ($self, $type) = @_;

    record_info($type);

    $self->write_cfg('/etc/sysconfig/network/ifcfg-team0', <<EOT);
STARTMODE='auto'
BOOTPROTO='static'
IPADDR='{{ipaddr4}}'

TEAM_RUNNER=broadcast
TEAM_PORT_DEVICE_0='{{iface1}}'
TEAM_PORT_DEVICE_1='{{iface2}}'

TEAM_LW_NAME="ethtool"
TEAM_LW_ETHTOOL_DELAY_UP="10"
TEAM_LW_ETHTOOL_DELAY_DOWN="10"
EOT

    $self->wicked_command('ifup', 'team0');

    # 1) Not set
    assert_script_run("! (wicked show-config team0 | grep $type)");
    assert_script_run("! (wicked show-xml team0 | grep $type)");
    my $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type");
    die("$type should not be set ") if defined($value);

    # 2) Set Count
    assert_script_run('echo TEAM_' . uc($type) . '_COUNT=4 >> /etc/sysconfig/network/ifcfg-team0');
    $self->reload_cfg();
    validate_script_output('wicked show-config team0', qr((?s)<$type>.*<count>4</count>.*</$type>));
    validate_script_output('wicked show-xml team0', qr((?s)<$type>.*<count>4</count>.*</$type>));
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type/count");
    die("Unexpected value in $type/count (exp:4 got:$value") unless $value eq 4;

    # 3) Set interval
    assert_script_run('echo TEAM_' . uc($type) . '_INTERVAL=500 >> /etc/sysconfig/network/ifcfg-team0');
    $self->reload_cfg();
    validate_script_output('wicked show-config team0', qr((?s)<$type>.*<interval>500</interval>.*</$type>));
    validate_script_output('wicked show-xml team0', qr((?s)<$type>.*<interval>500</interval>.*</$type>));
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type/interval");
    die("Unexpected value in $type/count (exp:500 got:$value") unless $value eq 500;

    # 4) Delete count
    assert_script_run("sed -i '/TEAM_" . uc($type) . "_COUNT/d' /etc/sysconfig/network/ifcfg-team0");
    $self->reload_cfg();
    validate_script_output('wicked show-config team0', qr((?s)<$type>.*<interval>500</interval>.*</$type>));
    validate_script_output('wicked show-config team0', sub { $_ !~ qr((?s)<$type>.*<count>.*</$type>) });
    validate_script_output('wicked show-xml team0', qr((?s)<$type>.*<interval>500</interval>.*</$type>));
    validate_script_output('wicked show-xml team0', sub { $_ !~ qr((?s)<$type>.*<count>.*</$type>) });
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type/interval");
    die("Unexpected value in $type/count (exp:500 got:$value") unless $value eq 500;
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type/count");
    die("$type/count should not be set ") if defined($value);

    # 5) Teamd has a special default for activebackup, here we should see count==1 if there is nothing in the wicked config
    assert_script_run("sed -i '/TEAM_RUNNER/cTEAM_RUNNER=activebackup' /etc/sysconfig/network/ifcfg-team0");
    $self->reload_cfg();
    assert_script_run("! (wicked show-config team0 | grep -A 4 '<$type>' | grep '<count>')");
    validate_script_output('wicked show-config team0', qr((?s)<$type>.*<interval>500</interval>.*</$type>));
    validate_script_output('wicked show-xml team0', qr((?s)<$type>.*<interval>500</interval>.*</$type>));
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type/interval");
    die("Unexpected value in $type/count (exp:500 got:$value") unless $value eq 500;
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type/count");
    die("Unexpected value in $type/count (exp:1 got:$value") unless $value eq 1;


    # 6) Delete interval and keep only special default
    assert_script_run("sed -i '/TEAM_" . uc($type) . "_INTERVAL/d' /etc/sysconfig/network/ifcfg-team0");
    $self->reload_cfg();
    validate_script_output('wicked show-config team0', sub { $_ !~ qr((?s)<$type>.*<interval>.*</$type>) });
    validate_script_output('wicked show-config team0', sub { $_ !~ qr((?s)<$type>.*<count>1</count>.*</$type>) });
    validate_script_output('wicked show-xml team0', sub { $_ !~ qr((?s)<$type>.*<interval>.*</$type>) });
    validate_script_output('wicked show-xml team0', qr((?s)<$type>.*<count>1</count>.*</$type>));
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type/interval");
    die("$type/interval should not be set ") if defined($value);
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type/count");
    die("Unexpected value in $type/count (exp:1 got:$value") unless $value eq 1;

    # 7) overwrite special default for runner==activebackup
    assert_script_run('echo TEAM_' . uc($type) . '_COUNT=4 >> /etc/sysconfig/network/ifcfg-team0');
    $self->reload_cfg();
    validate_script_output('wicked show-config team0', qr((?s)<$type>.*<count>4</count>.*</$type>));
    validate_script_output('wicked show-xml team0', qr((?s)<$type>.*<count>4</count>.*</$type>));
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/$type/count");
    die("Unexpected value in $type/count (exp:4 got:$value") unless $value eq 4;

    # 8) ifdown team0
    $self->wicked_command('ifdown', 'all');
    assert_script_run('! teamdctl team0 config dump actual');
}

sub check_cfg_debug_level()
{
    my ($self) = @_;

    record_info("debug_level");

    $self->write_default_cfg();
    $self->wicked_command('ifup', 'team0');

    # 1) Test with TEAM_DEBUG_LEVEL not set
    assert_script_run('! (wicked show-config team0 | grep debug_level)');
    assert_script_run('wicked show-xml team0 | grep "<debug_level>0</debug_level>"');
    my $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get('/debug_level');
    die("debug_level should not be set ") if defined($value);

    # 2) Add TEAM_DEBUG_LEVEL
    assert_script_run('echo TEAM_DEBUG_LEVEL=2 >> /etc/sysconfig/network/ifcfg-team0');
    $self->reload_cfg();
    assert_script_run("wicked show-config team0 | grep '<debug_level>2</debug_level>'");
    assert_script_run("wicked show-xml team0 | grep '<debug_level>2</debug_level>'");
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/debug_level");
    die("Unexpected value in debug_level (exp:2 got:$value") unless $value eq 2;

    # 3) Change TEAM_DEBUG_LEVEL
    assert_script_run("sed -i '/TEAM_DEBUG_LEVEL/cTEAM_DEBUG_LEVEL=3' /etc/sysconfig/network/ifcfg-team0");
    $self->reload_cfg();
    assert_script_run("wicked show-config team0 | grep '<debug_level>3</debug_level>'");
    assert_script_run("wicked show-xml team0 | grep '<debug_level>3</debug_level>'");
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get("/debug_level");
    die("Unexpected value in debug_level (exp:2 got:$value") unless $value eq 3;

    # 4) Delete TEAM_DEBUG_LEVEL
    assert_script_run("sed -i '/TEAM_DEBUG_LEVEL/d' /etc/sysconfig/network/ifcfg-team0");
    $self->reload_cfg();
    assert_script_run('! (wicked show-config team0 | grep debug_level)');
    assert_script_run('wicked show-xml team0 | grep "<debug_level>0</debug_level>"');
    $value = Mojo::JSON::Pointer->new(decode_json(script_output('teamdctl team0 config dump actual')))->get('/debug_level');
    die("debug_level should not be set ") if defined($value);

    # 5) ifdown team0
    $self->wicked_command('ifdown', 'all');
    assert_script_run('! teamdctl team0 config dump actual');
}

sub run {
    my ($self, $ctx) = @_;
    return if $self->skip_by_wicked_version('>=0.6.74');

    record_info('INFO', 'Teaming, ifcfg - check link_watch_policy');

    $self->ipaddr4($self->get_ip(type => 'host', netmask => 1));
    $self->remote_ipaddr4($self->get_remote_ip(type => 'host', netmask => 0));
    $self->iface1($ctx->iface());
    $self->iface2($ctx->iface2());

    $self->check_cfg_link_watch_policy();

    $self->check_cfg_lw_vlanid();

    $self->check_cfg_burst_cfg('notify_peers');
    $self->check_cfg_burst_cfg('mcast_rejoin');

    $self->check_cfg_debug_level();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
