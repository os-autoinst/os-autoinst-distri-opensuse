# Copyright 2015-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: supportserver and supportserver generator implementation
# - Configure a static network at "10.0.2.1" and check if it is working
# - Configure network and enable nat
# - Setup dhcp server if necessary
# - Setup pxe server if necessary
# - Setup tftp server if necessary
# - Setup http server if necessary
# - Setup dns server if necessary
# - Setup autoyast tests if necessary
# - Setup ntp server if necessary
# - Setup xvnc server if necessary
# - Setup ssh server if necessary
# - Setup xdmcp server if necessary
# - Setup iscsi server if necessary
# - Setup iscsi target server if necessary
# - Setup stunnel server if necessary
# - Setup mariadb server if necessary
# - Setup nfs server if necessary
# - Create locks for each server created
# Maintainer: Pavel Sladek <psladek@suse.com>

use strict;
use warnings;
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
use version_utils 'is_opensuse';
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
my $iscsi_server_set = 0;
my $iscsi_tgt_server_set = 0;
my $nfs_server_set = 0;

my $setup_script;
my $disable_firewall = 0;

sub setup_pxe_server {
    return if $pxe_server_set;

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

    $pxe_server_set = 1;
}

sub setup_http_server {
    return if $http_server_set;

    $setup_script .= "systemctl stop apache2\n";
    $setup_script .= "curl -f -v " . autoinst_url . "/data/supportserver/http/apache2  >/etc/sysconfig/apache2\n";
    $setup_script .= "systemctl start apache2\n";

    $http_server_set = 1;
}

sub setup_ftp_server {
    return if $ftp_server_set;

    $ftp_server_set = 1;
}

sub setup_tftp_server {
    return if $tftp_server_set;
    # atftpd is available only on older products (e.g.: present on SLE-12, gone on SLE-15)
    # FIXME: other options besides RPMs atftp, tftp not considered. For SLE-15 this is enough.
    my $tftp_service = script_output("rpm --quiet -q atftp && echo atftpd || echo tftp", type_command => 1);
    $setup_script .= "systemctl restart $tftp_service\n";

    $tftp_server_set = 1;
}

sub setup_networks {
    my $net_conf = parse_network_configuration();

    for my $network (keys %$net_conf) {
        my $server_ip = ip_in_subnet($net_conf->{$network}, 1);
        $setup_script .= "NIC=`grep $net_conf->{$network}->{mac} /sys/class/net/*/address |cut -d / -f 5`\n";
        $setup_script .= "cat > /etc/sysconfig/network/ifcfg-\$NIC <<EOT\n";
        $setup_script .= "IPADDR=$server_ip\n";
        $setup_script .= "NETMASK=$net_conf->{$network}->{subnet_mask}\n";
        $setup_script .= "STARTMODE='auto'\n";
        # TCP cannot pass GRE tunnel with default MTU value 1500 in combination of DF flag set in L3 for ovs bridge
        $setup_script .= "MTU='1458'\n";
        $setup_script .= "EOT\n";
    }
    $setup_script .= "systemctl restart network\n";

    $setup_script .= "FIXED_NIC=`grep $net_conf->{fixed}->{mac} /sys/class/net/*/address |cut -d / -f 5`\n";
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
    $setup_script .= "echo 1 > /proc/sys/net/ipv4/ip_forward\n";
    $setup_script .= "ip route\n";
    $setup_script .= "ip addr\n";
    $setup_script .= "iptables -v -L\n";
}

sub setup_dns_server {
    return if $dns_server_set;

    my $named_url = autoinst_url . '/data/supportserver/named';
    $setup_script .= qq@
        sed -i -e '/^NETCONFIG_DNS_FORWARDER=/ s/=.*/="bind"/' \\
               -e '/^NETCONFIG_DNS_FORWARDER_FALLBACK=/ s/yes/no/' /etc/sysconfig/network/config
        sed -i '/^NAMED_CONF_INCLUDE_FILES=/ s/=.*/="openqa.zones"/' /etc/sysconfig/named
        sed -i 's|#forwarders.*;|include "/etc/named.d/forwarders.conf";|' /etc/named.conf
        sed -i 's|#dnssec-validation .*;|dnssec-validation no;|' /etc/named.conf
        curl -f -v $named_url/openqa.zones > /etc/named.d/openqa.zones
        curl -f -v $named_url/openqa.test.zone > /var/lib/named/master/openqa.test.zone
        curl -f -v $named_url/2.0.10.in-addr.arpa.zone > /var/lib/named/master/2.0.10.in-addr.arpa.zone
        chown named:named /var/lib/named/master
    @;

    # Allow RPZ overrides - poo#32290

    if (lc(get_var('SUPPORT_SERVER_ROLES')) =~ /\brpz\b/) {
        record_info 'Netfix', 'Go through Europe Microfocus info-bloxx';
        $setup_script .= qq@
            curl -f -v $named_url/db.rpz > /var/lib/named/db.rpz
            echo 'zone "rpz" {type master; file "db.rpz"; allow-query {none;}; };' >> /etc/named.conf
            sed -i '/^options/a\\   response-policy { zone "rpz"; };' /etc/named.conf
        @;
    }

    # Start services
    $setup_script .= "
        netconfig update -f
        systemctl start named
        systemctl status named
        systemctl restart dhcpd
    ";
    $dns_server_set = 1;
}

sub dhcpd_conf_generation {
    my ($dns, $pxe, $net_conf) = @_;
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
        # dhcp clients have to use MTU 1458 to be able pass GRE Tunnel
        $setup_script .= "  option interface-mtu 1458;\n";
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
            # Only atftpd can handle subdirs, tftp (>= SLE-15) cannot.
            # setup_pxe.sh (see sub setup_pxe_server() above) will take care
            # to actually install pxelinux.0 correctly.
            #
            # FIXME: again, other TFTP servers besides atftpd, tftp not considered.
            my $pxe_loader = script_output(
                "rpm --quiet -q atftp && echo '/boot/pxelinux.0' || echo 'pxelinux.0'",
                type_command => 1);
            $setup_script .= "  filename \"$pxe_loader\";\n";
            $setup_script .= "  next-server $server_ip;\n";
        }
        $setup_script .= "}\n";
    }
    $setup_script .= "EOT\n";
}

sub setup_dhcp_server {
    my ($dns, $pxe) = @_;
    return if $dhcp_server_set;
    my $net_conf = parse_network_configuration();

    $setup_script .= "systemctl stop dhcpd\n";
    if (get_var('SUPPORT_SERVER_DHPCD_CONFIG')) {
        $setup_script .= "curl -f -v " . autoinst_url . "/data" . get_var('SUPPORT_SERVER_DHPCD_CONFIG') . " >/etc/dhcpd.conf \n";
    }
    else {
        dhcpd_conf_generation($dns, $pxe, $net_conf);
    }

    $setup_script .= "curl -f -v " . autoinst_url . "/data/supportserver/dhcp/sysconfig/dhcpd  >/etc/sysconfig/dhcpd \n";
    $setup_script .= "NIC_LIST=\"";
    for my $network (keys %$net_conf) {
        next unless $net_conf->{$network}->{dhcp};
        $setup_script .= "`grep $net_conf->{$network}->{mac} /sys/class/net/*/address |cut -d / -f 5` ";
    }
    $setup_script .= "\"\n";
    $setup_script .= 'sed -i -e "s|^DHCPD_INTERFACE=.*|DHCPD_INTERFACE=\"$NIC_LIST\"|" /etc/sysconfig/dhcpd' . "\n";

    $setup_script .= "systemctl start dhcpd\n";

    $dhcp_server_set = 1;
}

sub setup_ssh_server {
    return if $ssh_server_set;

    $setup_script .= "yast2 firewall services add zone=EXT service=service:sshd\n";
    $setup_script .= "systemctl restart sshd\n";
    $setup_script .= "systemctl status sshd\n";

    $ssh_server_set = 1;
}

sub setup_ntp_server {
    return if $ntp_server_set;

    $setup_script .= "yast2 firewall services add zone=EXT service=service:ntp\n";
    $setup_script .= "echo 'server pool.ntp.org' >> /etc/ntp.conf\n";
    $setup_script .= "systemctl restart ntpd\n";

    $ntp_server_set = 1;
}

sub setup_xvnc_server {
    return if $xvnc_server_set;

    if (check_var('REMOTE_DESKTOP_TYPE', 'persistent_vnc')) {
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

sub setup_iscsi_server {
    return if $iscsi_server_set;

    # If no LUN number is specified we must die!
    my $num_luns = get_required_var('NUMLUNS');

    # A second disk for iSCSI LUN is mandatory
    my $hdd_lun_size = get_required_var('HDDSIZEGB_2');

    # Integer part of the LUN size is keep and can't be lesser than 1GB
    my $lun_size = int($hdd_lun_size / $num_luns);
    die "iSCSI LUN cannot be lesser than 1GB!" if ($lun_size < 1);

    # Are we using virtio or virtio-scsi?
    my $hdd_lun = script_output "ls /dev/[sv]db";
    die "detection of disk for iSCSI LUN failed" unless $hdd_lun;

    # Needed if a firewall is configured
    script_run 'yast2 firewall services add zone=EXT service=service:target', 200;

    # Create the iSCSI LUN
    script_run "parted --align optimal --wipesignatures --script $hdd_lun mklabel gpt";
    my $start = 0;
    my $size = 0;
    for (my $num_lun = 1; $num_lun <= $num_luns; $num_lun++) {
        $start = $size + 1;
        $size = $num_lun * $lun_size * 1024;
        script_run "parted --script $hdd_lun mkpart primary ${start}MiB ${size}MiB";
    }

    # The easiest way (really!?) to configure LIO is with YaST
    # Code grab and adapted from tests/iscsi/iscsi_server.pm
    script_run("yast2 iscsi-lio-server; echo yast2-iscsi-lio-server-status-\$? > /dev/$serialdev", 0);
    assert_screen 'iscsi-target-overview-service-tab', 60;
    send_key 'alt-t';    # go to target tab
    assert_screen 'iscsi-target-overview-empty-target-tab';
    send_key 'alt-a';    # add target
    assert_screen 'iscsi-target-overview-add-target-tab';

    # Wait for the Identifier field to change from 'test' value to the correct one
    # We could simply use a 'sleep' here but it's less good
    wait_screen_change(undef, 10);

    # Select Target field
    send_key 'alt-t';
    wait_still_screen 3;

    # Change Target value
    for (1 .. 40) { send_key 'backspace'; }
    type_string 'iqn.2016-02.de.openqa';
    wait_still_screen 3;

    # Select Identifier field
    send_key 'alt-f';
    wait_still_screen 3;

    # Change Identifier value
    for (1 .. 40) { send_key 'backspace'; }
    wait_still_screen 3;
    type_string '132';
    wait_still_screen 3;

    # Un-check Use Authentication
    send_key 'alt-u';
    wait_still_screen 3;

    # Add LUNs
    for (my $num_lun = 1; $num_lun <= $num_luns; $num_lun++) {
        send_key 'alt-a';

        # Send alt-p until LUN path is selected
        send_key_until_needlematch 'iscsi-target-LUN-path-selected', 'alt-p', 6, 5;
        type_string "$hdd_lun$num_lun";
        assert_screen 'iscsi-target-LUN-support-server';
        send_key 'alt-o';
        wait_still_screen 3;
    }
    assert_screen 'iscsi-target-overview';
    send_key 'alt-n';
    assert_screen('iscsi-target-client-setup', 120);
    send_key 'alt-n';
    wait_still_screen 3;

    # No client configured, it's "normal"
    send_key 'alt-y';
    assert_screen 'iscsi-target-overview-target-tab';

    # iSCSI LIO configuguration is finished
    send_key 'alt-f';
    wait_serial('yast2-iscsi-lio-server-status-0', 90) || die "'yast2 iscsi-lio-server' didn't finish";

    # Now we need to enable iSCSI Demo Mode
    # With this mode, we don't need to manage iSCSI initiators
    # It's OK for a test/QA system, but of course not for a production one!
    systemctl('stop target');
    script_run "sed -i -e '/\\/demo_mode_write_protect\$/s/^echo 1/echo 0/' \\
                       -e '/\\/cache_dynamic_acls\$/s/^echo 0/echo 1/'      \\
                       -e '/\\/generate_node_acls\$/s/^echo 0/echo 1/'      \\
                       -e '/\\/authentication\$/s/^echo 1/echo 0/' /etc/target/lio_setup.sh";
    systemctl('enable --now target');
    select_console 'root-console';

    $iscsi_server_set = 1;
}

sub setup_iscsi_tgt_server {
    return if $iscsi_tgt_server_set;

    systemctl 'start tgtd';

    # Configure default iscsi iqn
    my $iqn = get_var("ISCSI_IQN", "iqn.2016-02.de.openqa");

    # Get device for iscsi export
    my $device = script_output "ls /dev/[sv]db";
    die "detection of disk for iSCSI LUN failed" unless $device;

    # Create new iqn target with target id 1
    tgt_new_target(1, $iqn);
    # Add device lun 1 to target with id 1
    tgt_new_lun(1, 1, "$device");
    # Export same device three times with same scsi_id for multipath test
    if (get_var('ISCSI_MULTIPATH')) {
        tgt_new_lun(1, 2, "$device");
        tgt_new_lun(1, 3, "$device");
        tgt_update_lun_params(1, 1, "scsi_id=\"mpatha\"");
        tgt_update_lun_params(1, 2, "scsi_id=\"mpatha\"");
        tgt_update_lun_params(1, 3, "scsi_id=\"mpatha\"");
        # Download and prepare LUN disturber for later use (flaky_mp_iscsi.pm)
        $setup_script .= "curl -f -v " . autoinst_url
          . "/data/supportserver/iscsi/multipath_flaky_luns.sh >/usr/local/bin/multipath_flaky_luns.sh \n"
          . "chmod +x /usr/local/bin/multipath_flaky_luns.sh";
    }
    # Authorize all clients
    tgt_auth_all(1);
    # Show details about configured iscsi server
    tgt_show;
    $iscsi_tgt_server_set = 1;
}

sub setup_aytests {
    # install the aytests-tests package and export the tests over http
    my $aytests_repo = get_var("AYTESTS_REPO_BRANCH", 'master');
    $setup_script .= "
    # Install git if not already
    zypper -n --no-gpg-checks in git-core
    # Get profiles
    git clone --single-branch -b $aytests_repo https://github.com/yast/aytests-tests.git /tmp/ay
    mv -f /tmp/ay/aytests /srv/www/htdocs/
    # Download apache configuration and cgi script used for dynamically set paramaters expansion
    curl -f -v " . autoinst_url . "/data/supportserver/aytests/aytests.conf >/etc/apache2/vhosts.d/aytests.conf
    curl -f -v " . autoinst_url . "/data/supportserver/aytests/aytests.cgi >/srv/www/cgi-bin/aytests
    chmod 755 /srv/www/cgi-bin/aytests

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

    systemctl restart apache2;
    ";
}

sub setup_stunnel_server {
    zypper_call('in stunnel');
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
}

sub setup_mariadb_server {
    my $ip = '10.0.2.%';
    my $passwd = 'suse';

    zypper_call('in mariadb');
    systemctl('start mysql');

    # Enter mysql command to grant the access privileges to root
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
}

sub setup_nfs_server {
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
}

sub run {
    # Persist DHCP configuration for VMware & HyperV virtualization smoketests
    unless (is_vmware_virtualization || is_hyperv_virtualization) {
        configure_static_network('10.0.2.1/24');
    }

    my @server_roles = split(',|;', lc(get_var("SUPPORT_SERVER_ROLES")));
    my %server_roles = map { $_ => 1 } @server_roles;

    setup_networks();
    # Wait until all nodes boot first
    if (get_var 'SLENKINS_CONTROL') {
        barrier_wait 'HOSTNAMES_CONFIGURED';
    }

    if (exists $server_roles{pxe}) {
        # PXE server cannot be configured on other ARCH than x86_64
        # because 'syslinux' package only exists on it
        die "PXE server is only supported on x86_64 architecture" unless is_x86_64;
        setup_dhcp_server((exists $server_roles{dns}), 1);
        setup_pxe_server();
        setup_tftp_server();
    }
    if (exists $server_roles{tftp}) {
        setup_tftp_server();
    }

    if (exists $server_roles{dhcp}) {
        setup_dhcp_server((exists $server_roles{dns}), 0);
    }
    if (exists $server_roles{qemuproxy}) {
        setup_http_server();
        $setup_script
          .= "curl -f -v "
          . autoinst_url
          . "/data/supportserver/proxy.conf | sed -e 's|#AUTOINST_URL#|"
          . autoinst_url
          . "|g' >/etc/apache2/vhosts.d/proxy.conf\n";
        $setup_script .= "systemctl restart apache2\n";
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
        setup_iscsi_server();
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

    die "no services configured, SUPPORT_SERVER_ROLES variable missing?" unless $setup_script;

    bmwqemu::log_call(setup_script => $setup_script);

    script_output($setup_script, 300);
    assert_script_run opensusebasetest::firewall . ' stop' if $disable_firewall;

    # Create mutexes for running services
    mutex_create($_) foreach (keys %server_roles);

    # Create a *last* mutex to signal that support_server initialization is done
    mutex_create('support_server_ready');
}

sub test_flags {
    return {fatal => 1};
}

1;
