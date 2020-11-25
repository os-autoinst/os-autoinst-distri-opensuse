# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base class for all WLAN related tests
# Maintainer: cfamullaconrad@suse.com


package wicked::wlan;

use Mojo::Base 'wickedbase';
use utils qw(random_string);
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product);
use utils qw(zypper_call zypper_ar);
use Mojo::File 'path';
use File::Basename;
use testapi;

has dhcp_enabled => 0;
has eap_user     => 'tester';
has eap_password => 'test1234';

has netns_name => 'wifi_ref';
has ref_ifc    => 'wlan0';
has ref_phy    => 'phy0';

sub ref_ip {
    my $self = shift;
    my $type = $self->dhcp_enabled ? 'wlan_dhcp' : 'wlan';
    return $self->get_ip(type => $type, is_wicked_ref => 1);
}

has sut_ifc => 'wlan1';
has sut_phy => 'phy1';

sub sut_ip {
    my $self = shift;
    my $type = $self->dhcp_enabled ? 'wlan_dhcp' : 'wlan';
    return $self->get_ip(type => $type, is_wicked_ref => 0);
}

# Test config, needed because of code duplication checks
has hostapd_conf => "";
has ifcfg_wlan   => "";
has use_dhcp     => 1;
has use_radius   => 0;

sub sut_hw_addr {
    my $self = shift;
    $self->{sut_hw_addr} //= $self->get_hw_address($self->sut_ifc);
    return $self->{sut_hw_addr};
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

sub restart_DHCP_server {
    my $self = shift;
    $self->stop_DHCP_server();
    $self->dhcp_enabled(1);
    $self->netns_exec(sprintf('dnsmasq --no-resolv --interface=%s --dhcp-range=%s,static --dhcp-host=%s,%s',
            $self->ref_ifc, $self->sut_ip, $self->sut_hw_addr, $self->sut_ip));
}

sub stop_DHCP_server {
    my $self = shift;
    $self->dhcp_enabled(0);
    assert_script_run('test -e /var/run/dnsmasq.pid && kill $(cat /var/run/dnsmasq.pid) || true');
}

sub before_test {
    my $self = shift // wicked::wlan->new();
    $self->prepare_packages();
    $self->prepare_phys();
    $self->prepare_freeradius_server();
}

sub prepare_packages {
    my $self = shift;
    if (is_sle('<12-sp5')) {
        die("Wicked WLAN testsuite not supported for SLE <12-sp5");
    } elsif (is_sle('=12-sp5')) {
        # PackageHub doesn't have hostapd for SLE-12-SP5
        zypper_ar('https://download.opensuse.org/repositories/Base:/System/SLE_12_SP5/Base:System.repo', no_gpg_check => 1);
    } elsif (is_sle()) {
        add_suseconnect_product('PackageHub');    # needed for hopstapd
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
    assert_script_run('(cd /etc/raddb/certs && ./bootstrap)', timeout => 300);
    assert_script_run(q(openssl rsa -in /etc/raddb/certs/client.key -out /etc/raddb/certs/client_no_pass.key -passin pass:'whatever'));
}

# Candidate for wickedbase.pm
sub get_hw_address {
    my ($self, $ifc) = @_;
    my $path   = "/sys/class/net/$ifc/address";
    my $output = script_output("test -e '$path' && cat '$path'");
    die("Interface $ifc doesn't exists") if ($output eq "");
    return $output;
}

sub lookup {
    my ($self, $name, $env) = @_;
    if (exists $env->{$name}) {
        return $env->{$name};
    } elsif (my $v = eval { return $self->$name }) {
        return $v;
    }
    die("Failed to lookup '{{$name}}' variable");
}

=head2 write_cfg

  write_cfg($filename, $content[, $env]);

Write all data at once to the file. Replace all ocurance of C<{{name}}>.
First lookup is the given c<$env> hash and if it doesn't exists
it try to lookup a member function with the given c<name> and replace the string
with return value

=cut
sub write_cfg {
    my ($self, $filename, $content, $env) = @_;
    $env //= {};
    my $rand = random_string;
    # replace variables
    $content =~ s/\{\{(\w+)\}\}/$self->lookup($1, $env)/eg;
    # unwrap content
    my ($indent) = $content =~ /^\r?\n?([ ]*)/m;
    $content =~ s/^$indent//mg;
    script_output(qq(cat > '$filename' << 'END_OF_CONTENT_$rand'
$content
END_OF_CONTENT_$rand
));
    system('test -d ulogs/ || mkdir ulogs/');
    path('ulogs/' . $self->{name} . '-' . basename($filename))->spurt($content);
}

sub assert_sta_connected {
    my ($self, $sta) = @_;
    $sta //= $self->sut_hw_addr;

    my $output = $self->netns_output(sprintf(q(hostapd_cli -i '%s' sta '%s'), $self->ref_ifc, $sta));
    die("STA($sta) isn't found on that hostapd") if ($output =~ /FAIL/);
    my %opts = $output =~ /^(\S+)=(.*)$/gm;
    die 'Missing "flags" in hostapd_cli sta output' unless exists $opts{flags};
    for my $flag (qw([AUTH] [ASSOC] [AUTHORIZED])) {
        die("STA($sta) missing flag $flag") if (index($opts{flags}, $flag) == -1);
    }

    return 1;
}

sub assert_connection {
    my $self = shift;

    assert_script_run('ping -c 1 -I ' . $self->sut_ifc . ' ' . $self->ref_ip);
    $self->netns_exec('ping -c 1 -I ' . $self->ref_ifc . ' ' . $self->sut_ip);
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Setup ref
    $self->netns_exec('ip addr add dev wlan0 ' . $self->ref_ip . '/24');
    $self->restart_DHCP_server()                if ($self->use_dhcp());
    $self->netns_exec('radiusd -d /etc/raddb/') if ($self->use_radius());

    $self->write_cfg('hostapd.conf', $self->hostapd_conf());
    $self->netns_exec('hostapd -B hostapd.conf');

    # Setup sut
    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $self->ifcfg_wlan());
    $self->wicked_command('ifup', $self->sut_ifc);

    # Check
    $self->assert_sta_connected();
    $self->assert_connection();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
