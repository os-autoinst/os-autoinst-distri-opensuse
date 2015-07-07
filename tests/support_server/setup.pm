# Copyright (C) 2015 SUSE Linux GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

use strict;
use base 'basetest';
use testapi;

my $pxe_server_set = 0;
my $quemu_proxy_set = 0;
my $http_server_set = 0;
my $ftp_server_set = 0;
my $tftp_server_set = 0;
my $dhcp_server_set = 0;
my $nfs_mount_set = 0;

my $setup_script;

sub setup_pxe_server
{
    return if $pxe_server_set;

    $setup_script.= "curl -f -v " . autoinst_url . "/data/supportserver/pxe/setup_pxe.sh  > setup_pxe.sh\n";
    $setup_script.= "/bin/bash -ex setup_pxe.sh\n";

    $pxe_server_set = 1;
}


sub setup_http_server
{
    return if $http_server_set;

    $setup_script.="systemctl stop apache2.service\n";
    $setup_script.="curl -f -v " . autoinst_url . "/data/supportserver/http/apache2  >/etc/sysconfig/apache2\n";
    $setup_script.="systemctl start apache2.service\n";

    $http_server_set = 1;
}

sub setup_ftp_server
{
    return if $ftp_server_set;

    $ftp_server_set = 1;
}

sub setup_tftp_server
{
    return if $tftp_server_set;

    $setup_script.="systemctl stop atftpd.service\n";
    $setup_script.="systemctl start atftpd.service\n";

    $tftp_server_set = 1;
}

sub setup_dhcp_server
{
    return if $dhcp_server_set;

    $setup_script.="systemctl stop dhcpd.service\n";
    $setup_script.="curl -f -v " . autoinst_url . "/data/supportserver/dhcp/dhcpd.conf  >/etc/dhcpd.conf \n";
    $setup_script.="curl -f -v " . autoinst_url . "/data/supportserver/dhcp/sysconfig/dhcpd  >/etc/sysconfig/dhcpd \n";
    $setup_script.="systemctl start dhcpd.service\n";

    $dhcp_server_set = 1;
}



sub setup_nfs_mount
{
    return if $nfs_mount_set;


    $nfs_mount_set = 1;
}





sub run {

    my @server_roles=split(',|;',lc(get_var("SUPPORT_SERVER_ROLES")) );
    my %server_roles= map { $_ => 1 } @server_roles;

    if ( exists $server_roles{'pxe'} ) {    
       setup_dhcp_server();
       setup_pxe_server();
       setup_tftp_server();
    }
    if ( exists $server_roles{'qemuproxy'} ) {    
       setup_http_server();
       $setup_script.="curl -f -v " . autoinst_url . "/data/supportserver/proxy.conf | sed -e 's|#AUTOINST_URL#|" . autoinst_url . "|g' >/etc/apache2/vhosts.d/proxy.conf\n";
       $setup_script.="systemctl restart apache2.service\n";
    }

    script_output("$setup_script");
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1, fatal => 1 };
}

1;

# vim: set sw=4 et:
