# SUSE's openQA tests
#
# Copyright © 2017-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: openvpn dhcp-server wicked git
# Summary: Do basic checks to make sure system is ready for wicked testing
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use base 'wickedbase';
use strict;
use warnings;
use testapi;
use utils qw(zypper_call systemctl file_content_replace zypper_ar ensure_ca_certificates_suse_installed);
use version_utils 'is_sle';
use network_utils qw(iface setup_static_network);
use serial_terminal;
use main_common 'is_updates_tests';
use repo_tools 'generate_version';

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal;
    my @ifaces = split(' ', iface(2));
    die("Missing at least one interface") unless (@ifaces);
    $ctx->iface($ifaces[0]);
    $ctx->iface2($ifaces[1]) if (@ifaces > 1);

    my $enable_command_logging = 'export PROMPT_COMMAND=\'logger -t openQA_CMD "$(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//")"\'';
    my $escaped                = $enable_command_logging =~ s/'/'"'"'/gr;
    assert_script_run("echo '$escaped' >> /root/.bashrc");
    assert_script_run($enable_command_logging);
    # image which we using for sle15 don't have firewall running.
    # QAM need another way to figure out firewall state due to wider set of images
    if (is_sle('<15') || (is_updates_tests() && !script_run('systemctl is-active -q ' . opensusebasetest::firewall))) {
        systemctl("stop " . opensusebasetest::firewall);
        systemctl("disable " . opensusebasetest::firewall);
    }
    assert_script_run('[ -z "$(coredumpctl -1 --no-pager --no-legend)" ]');
    record_info('INFO', 'Setting debug level for wicked logs');
    file_content_replace('/etc/sysconfig/network/config', '--sed-modifier' => 'g', '^WICKED_DEBUG=.*' => 'WICKED_DEBUG="all"', '^WICKED_LOG_LEVEL=.*' => 'WICKED_LOG_LEVEL="debug2"');
    #preparing directories for holding config files
    assert_script_run('mkdir -p /data/{static_address,dynamic_address}');
    if (check_var('WICKED', 'ipv6')) {
        setup_static_network(ip => $self->get_ip(type => 'host', netmask => 1), silent => 1, ipv6 =>
              $self->get_ip(type => 'dhcp6', netmask => 1));
    } else {
        setup_static_network(ip => $self->get_ip(type => 'host', netmask => 1), silent => 1);
    }
    record_info('INFO', 'Checking that network service is up');
    systemctl('is-active network');
    systemctl('is-active wicked');

    $self->download_data_dir();

    my $package_list = 'openvpn';
    $package_list .= ' tcpdump' if get_var('WICKED_TCPDUMP');
    if (check_var('IS_WICKED_REF', '1')) {
        $package_list .= ' radvd' if (check_var('WICKED', 'ipv6'));
        # Common REF Configuration
        record_info('INFO', 'Setup DHCP server');
        $package_list .= ' dhcp-server';
        zypper_call("-q in $package_list", timeout => 400);
        $self->get_from_data('wicked/dhcp/dhcpd.conf', '/etc/dhcpd.conf');
        if (is_sle('<12-sp1')) {
            file_content_replace('/etc/dhcpd.conf', '^\s*ddns-update-style' => '# ddns-update-style', '^\s*dhcp-cache-threshold' => '# dhcp-cache-threshold');
        }
        file_content_replace('/etc/sysconfig/dhcpd', '--sed-modifier' => 'g', '^DHCPD_INTERFACE=.*' => 'DHCPD_INTERFACE="' . $ctx->iface() . '"');
        # avoid usage of --now as <=sle-sp1 doesn't support it
        systemctl 'enable dhcpd.service';
        systemctl 'start dhcpd.service';
        if (check_var('WICKED', 'ipv6')) {
            assert_script_run('sysctl -w net.ipv6.conf.all.forwarding=1');
            my $dhcp6_conf = '/etc/dhcpd6.conf';
            $self->get_from_data('wicked/dhcp/dhcpd6.conf', $dhcp6_conf);
            file_content_replace('/etc/sysconfig/dhcpd', '--sed-modifier' => 'g', '^DHCPD6_INTERFACE=.*' => 'DHCPD6_INTERFACE="' . $ctx->iface() . '"');
            file_content_replace($dhcp6_conf, dns_advice => $self->get_ip(type => 'dns_advice'));
            systemctl 'enable dhcpd6.service';
            systemctl 'start dhcpd6.service';
        }
    } else {
        # Common SUT Configuration
        if (my $wicked_sources = get_var('WICKED_SOURCES')) {
            record_info('SOURCE', $wicked_sources);
            zypper_call('--quiet in automake autoconf libtool libnl-devel libnl3-devel libiw-devel dbus-1-devel pkg-config libgcrypt-devel systemd-devel git make gcc');
            my $folderName = 'wicked.git';
            my ($repo_url, $branch) = split(/#/, $wicked_sources, 2);
            assert_script_run("git config --global http.sslVerify false");
            assert_script_run("git clone '$repo_url' '$folderName'");
            assert_script_run("cd ./$folderName");
            if ($branch) {
                assert_script_run("git checkout $branch");
            }
            assert_script_run('./autogen.sh ',       timeout => 600);
            assert_script_run('make ; make install', timeout => 600);
        } elsif (my $wicked_repo = get_var('WICKED_REPO')) {
            record_info('REPO', $wicked_repo);
            if ($wicked_repo =~ /suse\.de/ && script_run('rpm -qi ca-certificates-suse') == 1) {
                my $version = generate_version('_');
                zypper_call("ar --refresh http://download.suse.de/ibs/SUSE:/CA/$version/SUSE:CA.repo");
                zypper_call("in ca-certificates-suse");
            }
            zypper_ar($wicked_repo, params => '-n wicked_repo', no_gpg_check => 1);
            my ($resolv_options, $repo_id) = (' --allow-vendor-change  --allow-downgrade ', 'wicked_repo');
            $resolv_options = ' --oldpackage' if (is_sle('<15'));
            ($repo_id) = ($wicked_repo =~ m!(^.*/)!s) if (is_sle('<=12-sp1'));
            zypper_call("in --from $repo_id $resolv_options --force -y --force-resolution  wicked wicked-service", log => 'zypper_in_wicked.log');
            my ($zypper_in_output) = script_output('cat /tmp/zypper_in_wicked.log');
            my @installed_packages;
            for my $reg (('The following \d+ packages? (are|is) going to be upgraded:',
                    'The following NEW packages? (are|is) going to be installed:',
                    'The following \d+ packages? (are|is) going to be reinstalled:')) {
                push(@installed_packages, split(/\s+/, $+{packages})) if ($zypper_in_output =~ m/(?s)($reg(?<packages>.*?))(?:\r*\n){2}/);
            }
            record_info('INSTALLED', join("\n", @installed_packages));
            my @zypper_ps_progs = split(/\s+/, script_output('zypper ps  --print "%s"', qr/^\s*$/));
            for my $ps_prog (@zypper_ps_progs) {
                die("The following programm $ps_prog use deleted files") if grep { /$ps_prog/ } @installed_packages;
            }
            record_info("WARNING", "`zypper ps` return following programs:\n" . join("\n", @zypper_ps_progs), result => 'softfail') if @zypper_ps_progs;
            if (my $commit_sha = get_var('WICKED_COMMIT_SHA')) {
                validate_script_output(q(head -n 1 /usr/share/doc/packages/wicked/ChangeLog | awk '{print $2}'), qr/^$commit_sha$/);
                record_info('COMMIT', $commit_sha);
            }
        }
        if (check_var('WICKED', 'ipv6')) {
            my $repo_url = 'https://download.opensuse.org/repositories/home:/asmorodskyi/';
            $repo_url = 'http://download.suse.de/ibs/home:/wicked-maintainers:/openQA/' if (is_sle());
            zypper_ar($repo_url . generate_version('_') . '/', name => 'wicked_maintainers', no_gpg_check => 1, priority => 60);
            $package_list .= ' ndisc6';
        }
        if (check_var('WICKED', 'wlan')) {
            wicked::wlan::before_test();
        }
        $package_list .= ' openvswitch iputils';
        $package_list .= ' libteam-tools libteamdctl0 ' if check_var('WICKED', 'advanced') || check_var('WICKED', 'aggregate');
        $package_list .= ' gcc'                         if check_var('WICKED', 'advanced');
        zypper_call('-q in ' . $package_list, timeout => 400);
        $self->reset_wicked();
        record_info('PKG', script_output(q(rpm -qa 'wicked*' --qf '%{NAME}\n' | sort | uniq | xargs rpm -qi)));
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
