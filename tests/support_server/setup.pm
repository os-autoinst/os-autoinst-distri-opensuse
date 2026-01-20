# Copyright 2015-2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: support server and support server generator implementation
# - Configure a static network at "10.0.2.1" and check if it is working
# - Configure network and enable NAT
# - Setup DHCP server if necessary
# - Setup PXE server if necessary
# - Setup TFTP server if necessary
# - Setup HTTP server if necessary
# - Setup DNS server if necessary
# - Setup autoyast tests if necessary
# - Setup NTP server if necessary
# - Setup XVNC server if necessary
# - Setup SSH server if necessary
# - Setup XDMCP server if necessary
# - Setup iSCSI LIO server if necessary
# - Setup iSCSI tgtd server if necessary
# - Setup stunnel server if necessary
# - Setup MariaDB server if necessary
# - Setup NFS server if necessary
# - Create locks for each server created
# Maintainer: Pavel Sladek <psladek@suse.com>
#             Jan Kohoutek <jkohoutek@suse.com>

use base 'basetest';
use lockapi;
use testapi;
use Utils::Architectures;
use utils;
use mm_network;
use mm_tests;
use opensusebasetest 'firewall';
use registration 'scc_version';
use iscsi;
use y2_module_basetest;
use version_utils qw(is_opensuse check_os_release);
use virt_autotest::utils qw(is_vmware_virtualization is_hyperv_virtualization);

my $pxe_server_set = 0;
my $http_server_set = 0;
my $ftp_server_set = 0;
my $tftp_server_set = 0;
my $dns_server_set = 0;
my $dhcp_server_set = 0;
my $ntp_server_set = 0;
my $xvnc_server_set = 0;
my $ssh_server_set = 0;
my $xdmcp_server_set = 0;
my $iscsi_lio_server_set = 0;
my $iscsi_tgt_server_set = 0;
my $aytests_set = 0;
my $stunnel_server_set = 0;
my $mariadb_server_set = 0;
my $nfs_server_set = 0;

my $disable_firewall = 0;


sub chk_req_pkgs {
    # Install provided list of required packages if any of them is not present on the system
    zypper_install_available(@_) if script_run('rpm -q --quiet ' . join(' ', @_));
}

sub turnoff_gnome_screensaver_and_suspend {
    assert_script_run "gsettings set org.gnome.desktop.session idle-delay 0";
    assert_script_run "gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'";
}

sub setup_pxe_server {
    return if $pxe_server_set;
    my $setup_script;
    chk_req_pkgs('dhcpd tftp');

    $setup_script .= "curl -f -v " . autoinst_url . "/data/supportserver/pxe/setup_pxe.sh  > setup_pxe.sh\n";
    my $ckrnl;
    if ($ckrnl = get_var('SUPPORT_SERVER_PXE_CUSTOMKERNEL')) {
        # -C option value: normalize possible default settings "1" "yes" "YES"
        $ckrnl = "" if ($ckrnl =~ /^(yes|1)$/i);
        # other settings constitute explicit command line parts (device, kernel etc.)
        $setup_script .= "/bin/bash -ex setup_pxe.sh -C $ckrnl\n";

        # For later. pxe_customkrnl.sh to be executed only when the custom kernel
        # actually becomes available. See custom_pxeboot.pm
        $setup_script .= "curl -f -v " . autoinst_url . "/data/supportserver/pxe/pxe_customkrnl.sh > pxe_customkrnl.sh\n";
    }
    else {
        $setup_script .= "/bin/bash -ex setup_pxe.sh\n";
    }

    bmwqemu::log_call(setup_script => $setup_script);
    script_output($setup_script, 300);

    $pxe_server_set = 1;
}

sub setup_http_server {
    return if $http_server_set;
    record_info 'HTTP server setup';
    chk_req_pkgs('apache2');

    systemctl('stop apache2');
    assert_script_run('curl -f -v ' . autoinst_url . '/data/supportserver/http/apache2  >/etc/sysconfig/apache2');
    systemctl('start apache2');

    $http_server_set = 1;
}

sub setup_ftp_server {
    return if $ftp_server_set;
    record_info 'FTP server setup';

    $ftp_server_set = 1;
}

sub setup_tftp_server {
    return if $tftp_server_set;
    record_info 'TFTP server setup';
    chk_req_pkgs('tftp');
    # atftpd is available only on older products (e.g.: present on SLE-12, gone on SLE-15)
    # FIXME: other options besides RPMs atftp, tftp not considered. For SLE-15 this is enough.
    my $tftp_service = script_output("rpm --quiet -q atftp && echo atftpd || echo tftp", type_command => 1);
    systemctl('restart ' . $tftp_service);


    $tftp_server_set = 1;
}

sub setup_networks {
    my ($mtu) = @_;
    my $net_conf = parse_network_configuration();
    my $setup_script;

    for my $network (keys %$net_conf) {
        my $server_ip = ip_in_subnet($net_conf->{$network}, 1);
        $setup_script .= "NIC=`grep $net_conf->{$network}->{mac} /sys/class/net/*/address |cut -d / -f 5`\n";
        $setup_script .= "cat > /etc/sysconfig/network/ifcfg-\$NIC <<EOT\n";
        $setup_script .= "IPADDR=$server_ip\n";
        $setup_script .= "NETMASK=$net_conf->{$network}->{subnet_mask}\n";
        $setup_script .= "STARTMODE='auto'\n";
        # TCP cannot pass GRE tunnel with default MTU value 1500 in combination of DF flag set in L3 for ovs bridge
        $setup_script .= "MTU='$mtu'\n";
        $setup_script .= "EOT\n";
    }
    bmwqemu::log_call(setup_script => $setup_script);
    record_info('NETWORK setup', script_output($setup_script, 300));
    systemctl('restart network');

    # Firewall setup to allow forward
    $setup_script = "FIXED_NIC=`grep $net_conf->{fixed}->{mac} /sys/class/net/*/address |cut -d / -f 5`\n";
    $setup_script .= "iptables -F\n";
    $setup_script .= "iptables -A INPUT -i \$FIXED_NIC -j ACCEPT\n";
    $setup_script .= "iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT\n";
    $setup_script .= "iptables -t nat -A POSTROUTING -o \$FIXED_NIC -j MASQUERADE\n";
    for my $network (keys %$net_conf) {
        next if $network eq 'fixed';
        next unless $net_conf->{$network}->{gateway};
        $setup_script .= "NIC=`grep $net_conf->{$network}->{mac} /sys/class/net/*/address |cut -d / -f 5`\n";
        $setup_script .= "iptables -A FORWARD -i \$FIXED_NIC -o \$NIC -m state  --state RELATED,ESTABLISHED -j ACCEPT\n";
        $setup_script .= "iptables -A FORWARD -i \$NIC -o \$FIXED_NIC -j ACCEPT\n";
    }
    # Enable IP forwarding
    $setup_script .= "echo 1 > /proc/sys/net/ipv4/ip_forward\n";

    bmwqemu::log_call(setup_script => $setup_script);
    record_info('Forward setup', script_output($setup_script, 300));

    record_info('IP route status', script_output('ip route'));
    record_info('IP addr status', script_output('ip addr'));
    record_info('IPTABLES status', script_output('iptables -v -L'));
}

sub setup_dns_server {
    return if $dns_server_set;
    my $setup_script;
    chk_req_pkgs('bind bind-utils');

    my $named_url = autoinst_url . '/data/supportserver/named';
    $setup_script .= qq@
        sed -i -e '/^NETCONFIG_DNS_FORWARDER=/ s/=.*/="bind"/' \\
               -e '/^NETCONFIG_DNS_FORWARDER_FALLBACK=/ s/yes/no/' /etc/sysconfig/network/config
        sed -i 's|#forwarders.*;|include "/etc/named.d/forwarders.conf";|' /etc/named.conf
        sed -i 's|#dnssec-validation .*;|dnssec-validation no;|' /etc/named.conf

        echo -e '\ninclude "/etc/named.d/openqa.zones";' >> /etc/named.conf
        curl -f -v $named_url/openqa.zones > /etc/named.d/openqa.zones
        chown :named /etc/named.d/openqa.zones

        curl -f -v $named_url/openqa.test.zone > /var/lib/named/master/openqa.test.zone
        curl -f -v $named_url/2.0.10.in-addr.arpa.zone > /var/lib/named/master/2.0.10.in-addr.arpa.zone
        chown -R named:named /var/lib/named/master
    @;

    # Allow RPZ overrides - poo#32290
    # FIXME: Is this still really needed?

    if (lc(get_var('SUPPORT_SERVER_ROLES')) =~ /\brpz\b/) {
        record_info 'Netfix', 'Go through Europe Microfocus info-bloxx';
        $setup_script .= qq@
            curl -f -v $named_url/db.rpz > /var/lib/named/db.rpz
            echo 'zone "rpz" {type master; file "db.rpz"; allow-query {none;}; };' >> /etc/named.conf
            sed -i '/^options/a\\   response-policy { zone "rpz"; };' /etc/named.conf
        @;
    }
    if (check_os_release('15', 'VERSION_ID')) {
        $setup_script .= qq@
            sed -i -e '/^NAMED_ARGS=/ s/=.*/="-4"/' /etc/sysconfig/named
        @;
        $setup_script .= qq@
            firewall-cmd --add-service=dns --permanent
            firewall-cmd --reload
        @ if (script_run('systemctl is-active -q ' . opensusebasetest::firewall) == 0);
    }
    $setup_script .= "netconfig update -f";
    bmwqemu::log_call(setup_script => $setup_script);
    record_info('DNS server setup', script_output($setup_script, 300));
    # Start services
    systemctl('start named');
    record_info('DNS status', script_output('systemctl status named'));
    systemctl('restart dhcpd');

    $dns_server_set = 1;
}

sub dhcpd_conf_generation {
    my ($dns, $pxe, $net_conf, $mtu) = @_;
    my $setup_script;

    $setup_script .= "cat  >/etc/dhcpd.conf <<EOT\n";
    $setup_script .= "default-lease-time 14400;\n";
    if ($dns) {
        $setup_script .= "ddns-update-style standard;\n";
        $setup_script .= "ddns-updates on;\n";
        $setup_script .= "update-conflict-detection false;\n";
        $setup_script .= "
        zone openqa.test. {
            primary 127.0.0.1;
        }
        zone 2.0.10.in-addr.arpa. {
            primary 127.0.0.1;
        }
        ";
    }
    else {
        $setup_script .= "ddns-update-style none;\n";
    }
    $setup_script .= "dhcp-cache-threshold 0;\n";
    $setup_script .= "\n";
    for my $network (keys %$net_conf) {
        next unless $net_conf->{$network}->{dhcp};
        my $server_ip = ip_in_subnet($net_conf->{$network}, 1);
        $setup_script .= "subnet $net_conf->{$network}->{subnet_ip} netmask $net_conf->{$network}->{subnet_mask} {\n";
        $setup_script .= "  range  " . ip_in_subnet($net_conf->{$network}, 15) . "  " . ip_in_subnet($net_conf->{$network}, 100) . ";\n";
        $setup_script .= "  default-lease-time 14400;\n";
        $setup_script .= "  max-lease-time 172800;\n";
        # DHCP clients have to use MTU 1380 to be able pass GRE Tunnel
        $setup_script .= "  option interface-mtu $mtu;\n";
        $setup_script .= "  option domain-name \"openqa.test\";\n";
        if ($dns) {
            $setup_script .= "  option domain-name-servers  $server_ip,  $server_ip;\n";
        }
        if ($net_conf->{$network}->{gateway}) {
            if ($network eq 'fixed') {
                $setup_script .= "  option routers 10.0.2.2;\n";
            }
            else {
                $setup_script .= "  option routers $server_ip;\n";
            }
        }
        if ($pxe) {
            # Only atftpd can handle subdirs, TFTP (>= SLE-15) cannot.
            # setup_pxe.sh (see sub setup_pxe_server() above) will take care
            # to actually install pxelinux.0 correctly.
            #
            # FIXME: again, other TFTP servers besides atftpd, TFTP not considered.
            my $pxe_loader = script_output(
                "rpm --quiet -q atftp && echo '/boot/pxelinux.0' || echo 'pxelinux.0'",
                type_command => 1);
            $setup_script .= "  filename \"$pxe_loader\";\n";
            $setup_script .= "  next-server $server_ip;\n";
        }
        $setup_script .= "}\n";
    }
    $setup_script .= "EOT\n";
    bmwqemu::log_call(setup_script => $setup_script);
    record_info('DHCP configured', script_output($setup_script, 300));
}

sub setup_dhcp_server {
    my ($dns, $pxe, $mtu) = @_;
    return if $dhcp_server_set;
    my $setup_script;
    chk_req_pkgs('dhcp-server');
    my $net_conf = parse_network_configuration();

    $setup_script .= "systemctl stop dhcpd\n";
    if (get_var('SUPPORT_SERVER_DHPCD_CONFIG')) {
        $setup_script .= "curl -f -v " . autoinst_url . "/data" . get_var('SUPPORT_SERVER_DHPCD_CONFIG') . " >/etc/dhcpd.conf \n";
    }
    else {
        dhcpd_conf_generation($dns, $pxe, $net_conf, $mtu);
    }

    $setup_script .= "curl -f -v " . autoinst_url . "/data/supportserver/dhcp/sysconfig/dhcpd  >/etc/sysconfig/dhcpd \n";
    $setup_script .= "NIC_LIST=\"";
    for my $network (keys %$net_conf) {
        next unless $net_conf->{$network}->{dhcp};
        $setup_script .= "`grep $net_conf->{$network}->{mac} /sys/class/net/*/address |cut -d / -f 5` ";
    }
    $setup_script .= "\"\n";
    $setup_script .= 'sed -i -e "s|^DHCPD_INTERFACE=.*|DHCPD_INTERFACE=\"$NIC_LIST\"|" /etc/sysconfig/dhcpd' . "\n";

    bmwqemu::log_call(setup_script => $setup_script);
    record_info('DHCP server', script_output($setup_script, 300));
    systemctl('start dhcpd');
    $dhcp_server_set = 1;
}

sub setup_ssh_server {
    return if $ssh_server_set;
    record_info 'SSH server setup';
    if (script_run('systemctl is-active -q ' . opensusebasetest::firewall) == 0) {
        my $firewall_cmd
          = check_os_release('12', 'VERSION_ID')
          ? 'yast2 firewall services add zone=EXT service=service:sshd'
          : 'firewall-cmd --add-service=ssh --permanent; firewall-cmd --reload';
        assert_script_run($firewall_cmd, timeout => 200);
    }
    systemctl('restart sshd');
    record_info('SSHD status', script_output('systemctl status sshd'));

    $ssh_server_set = 1;
}

sub setup_ntp_server {
    return if $ntp_server_set;
    record_info 'NTP setup';
    if (check_os_release('12', 'VERSION_ID')) {
        assert_script_run('yast2 firewall services add zone=EXT service=service:ntp')
          if (script_run('systemctl is-active -q ' . opensusebasetest::firewall) == 0);
        assert_script_run('echo \'server pool.ntp.org\' >> /etc/ntp.conf');
        systemctl('restart ntpd');
    }
    else {
        chk_req_pkgs('chrony');
        assert_script_run('firewall-cmd --add-service=ntp --permanent; firewall-cmd --reload')
          if (script_run('systemctl is-active -q ' . opensusebasetest::firewall) == 0);
        assert_script_run('echo \'server pool.ntp.org\' >> /etc/chrony.conf');
        systemctl('restart chronyd');
    }

    $ntp_server_set = 1;
}

sub setup_xvnc_server {
    return if $xvnc_server_set;
    record_info 'XVNC server setup';


    if (check_var('REMOTE_DESKTOP_TYPE', 'persistent_vnc') && check_os_release('12.3', 'VERSION_ID')) {
        zypper_call('ar http://openqa.suse.de/assets/repo/fixed/SLE-12-SP3-Server-DVD-x86_64-GM-DVD1/ sles12sp3dvd1_repo');
        zypper_call('ref');
    }
    script_run("yast remote; echo yast-remote-status-\$? > /dev/$serialdev", 0);
    assert_screen 'xvnc_server_configuration';
    if (check_var('REMOTE_DESKTOP_TYPE', 'one_time_vnc')) {
        send_key 'alt-l';
    }
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'persistent_vnc')) {
        send_key 'alt-a';
    }
    wait_still_screen 3;
    send_key 'alt-o';
    if (check_var('REMOTE_DESKTOP_TYPE', 'persistent_vnc')) {
        assert_screen 'xvnc-vncmanager-required';
        send_key 'alt-i';
    }
    assert_screen 'xvnc_dmrestart_warning';
    send_key 'ret';
    wait_serial('yast-remote-status-0', 90) || die "'yast remote' didn't finish";
    wait_still_screen 3;
    assert_script_run 'yast2 firewall services add zone=EXT service=service:vnc-server';
    systemctl('restart display-manager');
    assert_screen 'displaymanager';
    select_console 'root-console';

    $xvnc_server_set = 1;
}

sub setup_xdmcp_server {
    return if $xdmcp_server_set;
    record_info 'XDMCP server setup';
    chk_req_pkgs('xrdp');

    if (check_var('REMOTE_DESKTOP_TYPE', 'xdmcp_xdm')) {
        assert_script_run "sed -i -e 's|^DISPLAYMANAGER=.*|DISPLAYMANAGER=\"xdm\"|' /etc/sysconfig/displaymanager";
        assert_script_run "sed -i -e 's|^DEFAULT_WM=.*|DEFAULT_WM=\"icewm\"|' /etc/sysconfig/windowmanager";
    }
    assert_script_run 'yast2 firewall services add zone=EXT service=service:xdmcp';
    assert_script_run "sed -i -e 's|^DISPLAYMANAGER_REMOTE_ACCESS=.*|DISPLAYMANAGER_REMOTE_ACCESS=\"yes\"|' /etc/sysconfig/displaymanager";
    assert_script_run "sed -i -e 's|^\\[xdmcp\\]|\\[xdmcp\\]\\nMaxSessions=2|' /etc/gdm/custom.conf";
    systemctl('restart display-manager');
    assert_screen 'displaymanager';
    select_console 'root-console';

    $xdmcp_server_set = 1;
}

sub setup_iscsi_lio_server {
    # Setup of the iSCSI LIO server by 'targercli' from lib/iscsi.pm
    return if $iscsi_lio_server_set;
    record_info 'iSCSI LIO server setup';
    # Add the targetcli package now used for the iSCSI server configuration
    # but name is different on SLE 12.x and 15.x+
    my $lio_pkg = check_os_release('12', 'VERSION_ID')
      ? 'targetcli' : 'python3-targetcli-fb';
    chk_req_pkgs($lio_pkg);

    # Get the iSCSI server settings
    my $iscsi_iqn = get_var('ISCSI_IQN', 'iqn.2016-02.de.openqa');
    my $iscsi_identifier = get_var('ISCSI_IDENTIFIER', '132');
    my $iscsi_ip = get_var('ISCSI_PORTAL_IP', '10.0.2.1');
    my $iscsi_port = get_var('ISCSI_PORT', '3260');

    # If no LUN number is specified we must die!
    my $num_luns = get_required_var('NUMLUNS');

    # A second disk for iSCSI LUN is mandatory
    my $hdd_lun_size = get_required_var('HDDSIZEGB_2');

    # Integer part of the LUN size is keep and can't be lesser than 1GB
    my $lun_size = int($hdd_lun_size / $num_luns);
    die 'iSCSI LUN cannot be less than 1GB!' if ($lun_size < 1);

    # Are we using virtio or virtio-scsi?
    my $hdd_lun = script_output "ls /dev/[sv]db";
    die 'detection of disk for iSCSI LUN failed' unless $hdd_lun;

    # Needed if a firewall is configured
    # FIXME: remove the `yast` dependency
    if (script_run('systemctl is-active -q ' . opensusebasetest::firewall) == 0) {
        my $firewall_cmd
          = check_os_release('12', 'VERSION_ID')
          ? 'yast2 firewall services add zone=EXT service=service:target'
          : 'firewall-cmd --add-port=3260/tcp --permanent;firewall-cmd --reload';
        assert_script_run($firewall_cmd, timeout => 200);
    }
    # Create partitions on devices for the iSCSI LUNs
    script_run "parted --align optimal --wipesignatures --script $hdd_lun mklabel gpt";
    my $start = 0;
    my $size = 0;
    for (my $num_lun = 1; $num_lun <= $num_luns; $num_lun++) {
        $start = $size + 1;
        # Last partition size in percentage to ensure it is not larger that device size.
        $size = $num_lun eq $num_luns ? '100%' : $num_lun * $lun_size * 1024 . 'MiB';
        script_run "parted --script $hdd_lun mkpart primary ${start}MiB ${size}";
    }

    # Disable auto portal creation
    lio_global_set('auto_add_default_portal', 'false');

    # Creation of the iSCSI target
    lio_target_create($iscsi_identifier, $iscsi_iqn);

    # Add LUNs
    for (my $num_lun = 1; $num_lun <= $num_luns; $num_lun++) {
        lio_lun_create($iscsi_identifier, $iscsi_iqn, $hdd_lun . $num_lun);
    }

    # Add the Portal IP
    lio_portal_create($iscsi_identifier, $iscsi_iqn, $iscsi_ip, $iscsi_port);

    # Now we need to enable iSCSI Demo Mode
    # With this mode, we don't need to manage iSCSI initiators
    # It's OK for a test/QA system, but of course not for a production one!
    lio_auth_all($iscsi_identifier, $iscsi_iqn);

    # Start and enable iSCSI Target in systemctl
    systemctl('enable --now target');

    # Print iSCSI Target configuration to the console
    record_info('iSCSI targets', lio_show_target);

    $iscsi_lio_server_set = 1;
}

sub setup_iscsi_tgt_server {
    # Setup of the iSCSI server by 'tgtadm' from lib/iscsi.pm
    # Support multipath iSCSI setup if ISCSI_MULTIPATH is set
    return if $iscsi_tgt_server_set;
    record_info 'iSCSI TGT server setup';

    systemctl 'start tgtd';

    # Configure default iSCSI IQN
    my $iscsi_iqn = get_var("ISCSI_IQN", "iqn.2016-02.de.openqa");

    # Get device for iSCSI export
    my $device = script_output "ls /dev/[sv]db";
    die "detection of disk for iSCSI LUN failed" unless $device;

    # Create new IQN target with target id 1
    tgt_new_target(1, $iscsi_iqn);
    # Add device LUN 1 to target with id 1
    tgt_new_lun(1, 1, "$device");
    # Export same device three times with same scsi_id for multipath test
    if (get_var('ISCSI_MULTIPATH')) {
        tgt_new_lun(1, 2, "$device");
        tgt_new_lun(1, 3, "$device");
        tgt_update_lun_params(1, 1, "scsi_id=\"mpatha\"");
        tgt_update_lun_params(1, 2, "scsi_id=\"mpatha\"");
        tgt_update_lun_params(1, 3, "scsi_id=\"mpatha\"");
        # Download and prepare LUN disturber for later use (flaky_mp_iscsi.pm)
        assert_script_run('curl -f -v ' . autoinst_url
              . '/data/supportserver/iscsi/multipath_flaky_luns.sh >/usr/local/bin/multipath_flaky_luns.sh ;'
              . 'chmod +x /usr/local/bin/multipath_flaky_luns.sh');
    }
    # Authorize all clients
    tgt_auth_all(1);
    # Show details about configured iSCSI server
    tgt_show;
    $iscsi_tgt_server_set = 1;
}

sub setup_aytests {
    return if $aytests_set;
    my $setup_script;
    record_info 'AYTESTS server setup';
    chk_req_pkgs('apache2 git-core');

    # install the aytests-tests package and export the tests over http
    my $aytests_repo = get_var("AYTESTS_REPO_BRANCH", 'master');
    # Get profiles
    assert_script_run('git clone --single-branch -b ' . $aytests_repo . ' https://github.com/yast/aytests-tests.git /tmp/ay');
    assert_script_run('mv -f /tmp/ay/aytests /srv/www/htdocs/');
    # Download apache configuration and cgi script used for dynamically set paramaters expansion
    assert_script_run('curl -f -v ' . autoinst_url . '/data/supportserver/aytests/aytests.conf >/etc/apache2/vhosts.d/aytests.conf');
    assert_script_run('curl -f -v ' . autoinst_url . '/data/supportserver/aytests/aytests.cgi >/srv/www/cgi-bin/aytests');
    assert_script_run('chmod 755 /srv/www/cgi-bin/aytests');
    $setup_script .= "
    # Expand variables
    sed -i -e 's|{{SCC_REGCODE}}|" . get_var('SCC_REGCODE') . "|g' \\
           -e 's|{{SCC_URL}}|" . get_var('SCC_URL') . "|g' \\
           -e 's|{{VERSION}}|" . scc_version . "|g' \\
           -e 's|{{ARCH}}|" . get_var('ARCH') . "|g' \\
           -e 's|{{MSG_TIMEOUT}}|0|g' \\
           -e 's|{{REPO1_URL}}|http://10.0.2.1/aytests/files/repos/sles12|g' \\
           -e 's|{{POST_SCRIPT_URL}}|http://10.0.2.1/aytests/files/scripts/post_script.sh|g' \\
           -e 's|{{INIT_SCRIPT_URL}}|http://10.0.2.1/aytests/files/scripts/init_script.sh|g' \\
           /srv/www/htdocs/aytests/*.xml;
    ";
    bmwqemu::log_call(setup_script => $setup_script);
    script_output($setup_script, 300);

    systemctl('restart apache2');
    $aytests_set = 1;
}

sub setup_stunnel_server {
    return if $stunnel_server_set;
    record_info 'STUNNEL server setup';
    chk_req_pkgs('stunnel');
    configure_stunnel(1);
    assert_script_run 'mkdir -p ~/.vnc/';
    assert_script_run "vncpasswd -f <<<$password > ~/.vnc/passwd";
    assert_script_run 'chmod 0600 ~/.vnc/passwd';
    assert_script_run 'vncserver :5';
    assert_script_run 'netstat -nal | grep 5905';
    if (get_var('FIPS_ENABLED') || get_var('FIPS')) {
        assert_script_run "grep 'stunnel:.*FIPS mode enabled' /var/log/messages";
    }
    $disable_firewall = 1;
    $stunnel_server_set = 1;
}

sub setup_mariadb_server {
    return if $mariadb_server_set;
    record_info 'MariaDB server setup';
    my $ip = '10.0.2.%';
    my $passwd = 'suse';

    chk_req_pkgs('mariadb');
    systemctl('start mysql');

    # Enter MySQL command to grant the access privileges to root
    enter_cmd_slow "mysql";
    assert_screen 'mariadb-monitor-opened';
    enter_cmd_slow "SELECT User, Host FROM mysql.user WHERE Host <> \'localhost\';";
    assert_screen 'mariadb-user-host';
    enter_cmd_slow "GRANT ALL PRIVILEGES ON *.* TO \'root\'@\'$ip\' IDENTIFIED BY \'$passwd\' WITH GRANT OPTION;";
    assert_screen 'mariadb-grant-ok';
    enter_cmd_slow "quit";
    wait_still_screen 2;
    systemctl('restart mysql');
    $disable_firewall = 1;
    $mariadb_server_set = 1;
}

sub setup_nfs_server {
    return if $nfs_server_set;
    record_info 'NFS server setup';
    chk_req_pkgs('rpcbind nfs-kernel-server');
    my $nfs_mount = "/nfs/shared";
    my $nfs_permissions = "rw,sync,no_root_squash";

    # Added as the client test code might want to change the default
    # values
    if (get_var("CONFIGURE_NFS_SERVER")) {
        $nfs_mount = get_required_var("NFS_MOUNT");
        $nfs_permissions = get_required_var("NFS_PERMISSIONS");
    }

    systemctl("start rpcbind");
    systemctl("start nfs-server");
    assert_script_run("nfsstat –s");
    assert_script_run("mkdir -p $nfs_mount");
    assert_script_run("chmod 777 $nfs_mount");
    assert_script_run("echo $nfs_mount 10.0.2.2/24\\($nfs_permissions\\) >> /etc/exports");
    assert_script_run("exportfs -r");
    systemctl("restart nfs-server");
    systemctl("restart rpcbind");
    systemctl("is-active nfs-server -a rpcbind");
    $nfs_server_set = 1;
}

sub run {

    # Persist DHCP configuration for VMware & HyperV virtualisation smoke tests
    unless (is_vmware_virtualization || is_hyperv_virtualization) {
        configure_static_network('10.0.2.1/24');
    }

    my @server_roles = split(',|;', lc(get_var("SUPPORT_SERVER_ROLES")));
    my %server_roles = map { $_ => 1 } @server_roles;
    my $mtu = get_var('MM_MTU', 1380);

    # -----> BEGIN OF THE ORIGINAL SLE 12 SP3 SUPPORT SERVER BACKWARD COMPATIBILITY BLOCK
    # This is backward compatibility workaround to override the past when probably
    # someone mess up directly with QCOW images instead of regeneration of them
    # and could be removed when this ancient 12SP3 image is no longer used

    if (check_os_release('12.3', 'VERSION_ID')) {

        # Get the Support server architecture
        my $cpu_arch = get_var('ARCH');

        # So messed up, that someone add x86_64 repo to the AARCH64 image
        zypper_call('removerepo 1') if $cpu_arch eq 'aarch64';

        # Adding back the pool and updates repositories which should be registered
        zypper_ar("http://download.suse.de/ibs/SUSE/Products/SLE-SERVER/12-SP3/$cpu_arch/product", name => 'sles12sp3-pool');
        zypper_ar("http://download.suse.de/ibs/SUSE/Updates/SLE-SERVER/12-SP3/$cpu_arch/update", name => 'sles12sp3-update');
        zypper_call('lr -u');

    }
    # -----> END OF SLE 12 SP3 BACKWARD COMPATIBILITY BLOCK

    # Networks setup
    setup_networks($mtu);
    # Wait until all nodes boot first
    if (get_var 'SLENKINS_CONTROL') {
        barrier_wait 'HOSTNAMES_CONFIGURED';
    }

    if (exists $server_roles{pxe}) {
        # PXE server cannot be configured on other ARCH than x86_64
        # because 'syslinux' package only exists on it
        die "PXE server is only supported on x86_64 architecture" unless is_x86_64;

        setup_dhcp_server((exists $server_roles{dns}), 1, $mtu);
        setup_pxe_server();
        setup_tftp_server();
    }
    if (exists $server_roles{tftp}) {
        setup_tftp_server();
    }

    if (exists $server_roles{dhcp}) {
        setup_dhcp_server((exists $server_roles{dns}), 0, $mtu);
    }
    if (exists $server_roles{qemuproxy}) {
        setup_http_server();
        assert_script_run('curl -f -v '
              . autoinst_url
              . '/data/supportserver/proxy.conf | sed -e \'s|#AUTOINST_URL#|'
              . autoinst_url
              . '|g\' >/etc/apache2/vhosts.d/proxy.conf');
        systemctl('restart apache2');
    }
    if (exists $server_roles{dns}) {
        setup_dns_server();
    }

    if (exists $server_roles{aytests}) {
        setup_aytests();
    }

    if (exists $server_roles{ntp}) {
        setup_ntp_server();
    }

    if (exists $server_roles{xvnc}) {
        setup_xvnc_server();
    }

    if (exists $server_roles{ssh}) {
        setup_ssh_server();
    }

    if (exists $server_roles{xdmcp}) {
        setup_xdmcp_server();
    }

    if (exists $server_roles{iscsi}) {
        setup_iscsi_lio_server();
    }
    if (exists $server_roles{iscsi_tgt}) {
        setup_iscsi_tgt_server();
    }
    if (exists $server_roles{stunnel}) {
        setup_stunnel_server;
    }
    if (exists $server_roles{mariadb}) {
        setup_mariadb_server;
    }
    if (exists $server_roles{nfs}) {
        setup_nfs_server();
    }

    die "no services configured, SUPPORT_SERVER_ROLES variable missing?" unless %server_roles;

    assert_script_run opensusebasetest::firewall . ' stop' if $disable_firewall;

    # Create mutexes for running services
    mutex_create($_) foreach (keys %server_roles);

    # Create a *last* mutex to signal that support_server initialization is done
    mutex_create('support_server_ready');
}

sub pre_run_hook {
    my ($self) = @_;

    # Comment /etc/named.conf.include inclusion from /etc/named.conf in those
    # cases this module runs on support servers which were configured in a
    # previous job (for example, on migration scenarios)
    my $openqa_zones_exists = !script_run 'test -f /etc/named.d/openqa.zones';
    my $openqa_zones_in_include = !script_run q|grep -q -E "^include \"/etc/named.d/openqa.zones\";" /etc/named.conf.include|;
    my $named_conf_include = !script_run q|grep -q -E "^include \"/etc/named.conf.include\";" /etc/named.conf|;
    if ($openqa_zones_exists && $openqa_zones_in_include && $named_conf_include) {
        # This is running in a support server which was configured on a previous job.
        # Comment line with 'include "/etc/named.conf.include";' from /etc/named.conf
        # as in some older versions, leaving the line causes /etc/named.d/openqa.zones
        # to be included twice, which prevents named from starting
        assert_script_run q|sed -i -e '/^include \"\/etc\/named.conf.include\";/ s/^/#/' /etc/named.conf|;
    }

    assert_script_run q|sed -i -e '/^include \"\/etc\/named.d\/openqa.zones\";/ s/^/#/' /etc/named.conf|
      unless (script_run q|grep -E "^include \"/etc/named.d/openqa.zones\";" /etc/named.conf|);

    # Disable gpg cheks in zypper globaly
    assert_script_run(q|sed -i -e '/^# repo_gpgcheck =/ i gpgcheck = off' /etc/zypp/zypp.conf|);

    # Disable GNOME screen saver and suspend
    turnoff_gnome_screensaver_and_suspend if check_var('DESKTOP', 'gnome');

    $self->SUPER::pre_run_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;
