# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for all WLAN related tests
# Maintainer: cfamullaconrad@suse.com


package wicked::wlan;

use Mojo::Base 'wickedbase';
use version_utils qw(is_sle);
use repo_tools qw(add_qa_head_repo generate_version);
use utils qw(zypper_call);
use testapi;

has wicked_version => undef;
has need_key_mgmt => undef;
has eap_user => 'tester';
has eap_password => 'test1234';
has ca_cert => '/etc/raddb/certs/ca.pem';
has client_cert => '/etc/raddb/certs/client.crt';
has client_key => '/etc/raddb/certs/client.key';
has client_key_no_pass => '/etc/raddb/certs/client_no_pass.key';
has client_key_password => 'whatever';

has netns_name => 'wifi_ref';
has ref_ifc => 'wlan0';
has ref_phy => 'phy0';
sub ref_ip {
    return shift->get_ip(is_wicked_ref => 1, @_);
}

has sut_ifc => 'wlan1';
has sut_phy => 'phy1';
sub sut_ip {
    return shift->get_ip(is_wicked_ref => 0, @_);
}

# Test config, needed because of code duplication checks
has hostapd_conf => "";
has ifcfg_wlan => "";
has use_dhcp => 1;
has use_radius => 0;

sub sut_hw_addr {
    my $self = shift;
    $self->{sut_hw_addr} //= $self->get_hw_address($self->sut_ifc);
    return $self->{sut_hw_addr};
}

# Get the ref_ifc for a specific bss subinterface
sub ref_bss {
    my ($self, %args) = @_;
    my $nr = extract_bss_nr($args{bss});

    if ($nr > 0) {
        return $self->ref_ifc . "_$nr";
    }
    return $self->ref_ifc;
}

sub ref_bss1 { return shift->ref_bss(bss => 1); }
sub ref_bss2 { return shift->ref_bss(bss => 2); }
sub ref_bss3 { return shift->ref_bss(bss => 3); }

sub get_ip {
    my ($self, %args) = @_;
    my $bss_nr = extract_bss_nr($args{bss});

    my $suffix = $bss_nr > 0 ? "_bss$bss_nr" : "";
    my $type = $self->use_dhcp ? "wlan_dhcp$suffix" : "wlan$suffix";
    return $self->SUPER::get_ip(type => $type, is_wicked_ref => $args{is_wicked_ref}, netmask => $args{netmask});
}

sub extract_bss_nr {
    my ($self, $nr) = @_;
    $nr = $self unless (ref($self));    # allow as static function
    $nr //= 0;
    $nr = $1 if $nr =~ /_(\d+)$/;    # extract number, e.g. `bss_1` would result in `1`
    return $nr;
}

sub recover_console {
    if (testapi::is_serial_terminal()) {
        type_string(qq(\c\\));    # Send QUIT signal
    }
    else {
        send_key('ctrl-\\');    # Send QUIT signal
    }
    assert_script_run('echo CHECK_CONSOLE');
}

sub retry {
    my ($self, $code, %args) = @_;
    $args{max_tries} //= 3;
    $args{sleep_duration} //= 5;
    $args{cleanup} //= sub { $self->recover_console };
    $args{name} //= Carp::shortmess("retry()");

    my $ret;
    my $try_cnt = 0;

    while ($try_cnt++ < $args{max_tries}) {
        eval { $ret = $code->() };
        return $ret unless ($@);
        my $errmsg = $@;
        eval { $args{cleanup}->($errmsg) } or
          bmwqemu::fctwarn($args{name} . ' -- cleanup failed with: ' . $@);

        sleep $args{sleep_duration};
    }
    die($args{name} . ' call failed after ' . $args{max_tries} . ' attempts -- ' . $@);
}

sub netns_exec {
    my ($self, $cmd, @args) = @_;
    $cmd = 'ip netns exec ' . $self->netns_name . ' ' . $cmd;
    assert_script_run($cmd, @args);
}

sub netns_output {
    my ($self, $cmd, @args) = @_;
    $cmd = 'ip netns exec ' . $self->netns_name . ' ' . $cmd;
    return script_output($cmd, @args);
}

sub netns_run {
    my ($self, $cmd, @args) = @_;
    $cmd = 'ip netns exec ' . $self->netns_name . ' ' . $cmd;
    my $ret = script_run($cmd, @args);
    die("Timeout on script_run($cmd)") unless defined($ret);
    return $ret;
}

sub dhcp_pidfile {
    my ($self, %args) = @_;
    $args{ref_ifc} //= $self->ref_bss(bss => $args{bss});
    return "/var/run/dnsmasq_$args{ref_ifc}.pid";
}

sub dhcp_logfile {
    my ($self, %args) = @_;
    $args{ref_ifc} //= $self->ref_bss(bss => $args{bss});
    return "/var/log/dnsmasq_$args{ref_ifc}.log";
}

sub restart_dhcp_server {
    my ($self, %args) = @_;

    $args{ref_ifc} //= $self->ref_bss(bss => $args{bss});
    $args{sut_ip} //= $self->sut_ip(bss => $args{bss});

    $self->stop_dhcp_server(%args);
    $self->netns_exec(sprintf('dnsmasq --no-resolv --pid-file=%s --log-facility=%s --log-dhcp --interface=%s --except-interface=lo --bind-interfaces --dhcp-range=%s,static --dhcp-host=%s,%s',
            $self->dhcp_pidfile(%args), $self->dhcp_logfile(%args), $args{ref_ifc}, $args{sut_ip}, $self->sut_hw_addr, $args{sut_ip}));
    $self->add_post_log_file($self->dhcp_logfile(%args));
}

sub stop_dhcp_server {
    my ($self, %args) = @_;

    my $pidfile = $self->dhcp_pidfile(%args);
    assert_script_run(sprintf('test -e %s && kill $(cat %s) || true', $pidfile, $pidfile));
}

sub prepare_sut {
    my $self = shift // wicked::wlan->new();
    $self->prepare_phys();
    $self->prepare_freeradius_server();
    $self->adopt_apparmor();
}

sub prepare_packages {
    if (is_sle()) {
        set_var('QA_HEAD_REPO', 'http://download.suse.de/ibs/QA:/Head/' . generate_version('-')) unless (get_var('QA_HEAD_REPO'));
        add_qa_head_repo();
    }
    zypper_call('-q in iw hostapd wpa_supplicant dnsmasq freeradius-server freeradius-server-utils vim');
    # make sure, we do not run these deamons, as we need to run them in network namespace
    assert_script_run('systemctl disable --now dnsmasq');
    assert_script_run('systemctl disable --now radiusd');
}

sub prepare_phys {
    my $self = shift;
    assert_script_run('modprobe mac80211_hwsim radios=2');
    assert_script_run('ip netns add ' . $self->netns_name);
    assert_script_run('ip netns list');
    assert_script_run('iw dev');

    my $cmd_set_netns = 'iw phy ' . $self->ref_phy . ' set netns name ' . $self->netns_name;
    if (is_sle('<15')) {
        my $output = script_output(sprintf(q(ip netns exec %s perl -MPOSIX -e '$0="netns_%s_dummy_process"; pause' & echo "BACKGROUND_PROCESS:-$!-"), $self->netns_name, $self->netns_name));
        die("Failed to get netns dummy pid") unless ($output =~ m/BACKGROUND_PROCESS:-(\d+)-/);
        $cmd_set_netns = 'iw phy ' . $self->ref_phy . ' set netns ' . $1;
    }
    # Delay namespace setup of wlan device to avoid wickedd-nanny error message
    assert_script_run('sleep 3');
    assert_script_run($cmd_set_netns);

    assert_script_run('iw dev');
    $self->netns_exec('iw dev');
    $self->netns_exec('ip link set dev lo up');
}

sub prepare_freeradius_server {
    my $self = shift;
    # The default installation of freeradius-server gives us a config where
    # we can authenticate with PEAP+MSCHAPv2, TLS and TTLS/PAP
    assert_script_run(sprintf(q(echo '%s ClearText-Password := "%s"' >> /etc/raddb/users),
            $self->eap_user, $self->eap_password));
    assert_script_run('time (cd /etc/raddb/certs && ./bootstrap)', timeout => 600);
    assert_script_run(sprintf(q(openssl rsa -in '%s' -out '%s' -passin pass:'%s'),
            $self->client_key, $self->client_key_no_pass, $self->client_key_password));
}

sub adopt_apparmor {
    if (script_output('systemctl is-active apparmor', proceed_on_failure => 1) eq 'active') {
        enter_cmd(q(test ! -e /etc/apparmor.d/usr.sbin.hostapd || sed -i -E 's/^}$/  \/tmp\/** rw,\n}/' /etc/apparmor.d/usr.sbin.hostapd));
        enter_cmd(q(test ! -e /etc/apparmor.d/usr.sbin.hostapd || sed -i -E 's/^}$/  \/etc\/raddb\/certs\/** r,\n}/' /etc/apparmor.d/usr.sbin.hostapd));
        assert_script_run('systemctl reload apparmor');
    }
}

sub get_hw_address {
    my ($self, $ifc) = @_;
    my $path = "/sys/class/net/$ifc/address";
    my $hw_addr;
    if ($self->netns_run("test -e '$path'") == 0) {
        $hw_addr = $self->netns_output("cat '$path'");
    } else {
        $hw_addr = script_output("test -e '$path' && cat '$path'");
    }
    die("Interface $ifc doesn't exists") if ($hw_addr eq "");
    return $hw_addr;
}

sub assert_sta_connected {
    my ($self, %args) = @_;
    $args{sta} //= $self->sut_hw_addr;
    $args{ref_ifc} //= $self->ref_bss(bss => $args{bss});
    $args{timeout} //= 0;
    $args{sleep} //= 1;
    my $endtime = time() + $args{timeout};

    while (1) {
        eval {
            my $output = $self->netns_output(sprintf(q(hostapd_cli -i '%s' sta '%s'), $args{ref_ifc}, $args{sta}));
            die("STA($args{sta}) isn't found on that hostapd") if ($output =~ /FAIL/);
            my %opts = $output =~ /^(\S+)=(.*)$/gm;
            die 'Missing "flags" in hostapd_cli sta output' unless exists $opts{flags};
            for my $flag (qw([AUTH] [ASSOC] [AUTHORIZED])) {
                die("STA($args{sta}) missing flag $flag") if (index($opts{flags}, $flag) == -1);
            }
        };
        return 1 unless ($@);    # no error
        die($@) if (time() > $endtime || $args{timeout} == 0);

        sleep($args{sleep});
    }

    die("This should never reached!");
}

sub hostapd_can_wep {
    my ($self) = @_;
    $self->write_cfg('/tmp/check_wep.conf', 'wep_key0=123456789a');
    my $s = script_output('hostapd /tmp/check_wep.conf', proceed_on_failure => 1);
    return $s !~ m/unknown configuration item 'wep_key0'/i;
}

sub is_hostapd_supporting_key_mgmt {
    my ($self, $key_mgmt) = @_;

    $self->write_cfg('/tmp/check_key_mgmt.conf', 'wpa_key_mgmt=' . $key_mgmt);
    my $s = script_output('hostapd /tmp/check_key_mgmt.conf', proceed_on_failure => 1);
    return $s !~ m/invalid key_mgmt/i;
}

sub is_wpa_supplicant_supporting_key_mgmt {
    my ($self, $key_mgmt) = @_;
    $self->write_cfg('/tmp/check_key_mgmt.conf', <<EOT);
        network={
            ssid=this-produce-a-ssid-parsing-error
            key_mgmt=$key_mgmt
        }
EOT
    my $s = script_output('wpa_supplicant -c/tmp/check_key_mgmt.conf -i ' . $self->sut_ifc, proceed_on_failure => 1);
    return $s !~ m/invalid key_mgmt/i;
}

sub skip_by_supported_key_mgmt {
    my ($self) = @_;
    return 0 unless $self->need_key_mgmt;

    if (!$self->is_hostapd_supporting_key_mgmt($self->need_key_mgmt)) {
        record_info('SKIP', 'Skip test - hostapd does not support wpa_key_mgmt=' . $self->need_key_mgmt,
            result => 'softfail');
        $self->result('skip');
        return 1;
    }
    if (!$self->is_wpa_supplicant_supporting_key_mgmt($self->need_key_mgmt)) {
        record_info('SKIP', 'Skip test - wpa_supplicant does not support key_mgmt=' . $self->need_key_mgmt,
            result => 'softfail');
        $self->result('skip');
        return 1;
    }

    return 0;
}

sub hostapd_start {
    my ($self, $config, %args) = @_;
    $args{name} //= 'hostapd';
    $config = $self->write_cfg("/tmp/$args{name}.conf", $config);
    $self->retry(
        sub {
            $self->netns_output("hostapd -P '/tmp/$args{name}.pid' -B '/tmp/$args{name}.conf'");
        },
        cleanup => sub {
            my ($err) = @_;
            $self->recover_console();
            record_info('HOSTAPD', $err, result => 'fail');
        }
    );

    ## Check for multi BSS setup
    my @bsss = $config =~ (/^bss=(.*)$/gm);
    for my $bss (@bsss) {
        $self->retry(sub {
                $self->netns_exec('ip addr add dev ' . $bss . ' ' . $self->ref_ip(bss => $bss, netmask => 1));
        });
        $self->restart_dhcp_server(bss => $bss) if ($self->use_dhcp());
    }
}

sub hostapd_kill {
    my ($self, %args) = @_;
    $args{name} //= 'hostapd';
    assert_script_run("kill \$(cat /tmp/$args{name}.pid)");
}

sub assert_connection {
    my ($self, %args) = @_;
    $args{timeout} //= 0;
    $args{sleep} //= 1;
    my $endtime = time() + $args{timeout};

    while (1) {
        eval {
            assert_script_run('ping -c 1 -I ' . $self->sut_ifc . ' ' . $self->ref_ip(bss => $args{bss}));
            $self->netns_exec('ping -c 1 -I ' . $self->ref_bss(bss => $args{bss}) . ' ' . $self->sut_ip(bss => $args{bss}));
        };
        return 1 unless ($@);    # no error
        die($@) if (time() > $endtime || $args{timeout} == 0);

        sleep($args{sleep});
    }
}

sub setup_ref {
    my $self = shift;

    $self->netns_exec('ip addr add dev ' . $self->ref_ifc() . ' ' . $self->ref_ip(netmask => 1));
    $self->restart_dhcp_server() if ($self->use_dhcp());
    $self->netns_exec('radiusd -d /etc/raddb/') if ($self->use_radius());
}

sub __as_array {
    my $ref = shift;

    if (ref($ref) eq 'ARRAY') {
        return @$ref;
    } elsif (ref($ref) eq 'HASH') {
        die("Unsupported config format");
    } else {
        return ($ref);
    }
}

sub __as_config_array {
    my $param = shift;
    my @ret;
    foreach my $in (__as_array($param)) {
        my $cfg = {config => '', wicked_version => '>=0.0.0'};
        if (ref($in) eq 'HASH') {
            $cfg = {%{$cfg}, %{$in}};
        } else {
            $cfg->{config} = $in;
        }
        push @ret, $cfg;
    }
    return @ret;
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    return if ($self->skip_by_wicked_version());
    return if ($self->skip_by_supported_key_mgmt());

    $self->setup_ref();

    for my $hostapd_conf (__as_config_array($self->hostapd_conf())) {

        if (!$self->check_wicked_version($hostapd_conf->{wicked_version})) {
            record_info("Skip cfg", $hostapd_conf->{config});
            next;
        }

        for my $ifcfg_wlan (__as_config_array($self->ifcfg_wlan())) {
            $self->hostapd_start($hostapd_conf->{config});

            if ($self->check_wicked_version($ifcfg_wlan->{wicked_version})) {
                # Setup sut
                $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $ifcfg_wlan->{config});
                $self->wicked_command('ifup', $self->sut_ifc);

                # Check
                $self->assert_sta_connected();
                $self->assert_connection();

                $self->wicked_command('ifstatus --verbose', $self->sut_ifc);
                $self->wicked_command('show-config', $self->sut_ifc);
                $self->wicked_command('show-xml', $self->sut_ifc);

            } else {
                record_info("Skip cfg", $ifcfg_wlan->{config});
            }

            # Cleanup
            $self->wicked_command('ifdown', $self->sut_ifc);
            $self->hostapd_kill();
        }

    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
