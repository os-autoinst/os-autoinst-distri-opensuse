# Copyright (C) 2014 SUSE Linux GmbH
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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use base "basetest";
use strict;
use testapi;
use virtmanager;

sub go_for_netif {
    my $netif = shift;
    launch_virtmanager();
    # go tab networkd interface
    connection_details("netinterface");
    create_netinterface($netif);
    # close virt-manager details
    send_key "ctrl-w";
}

sub checking_netif_result {
    my $volumes = shift;
    x11_start_program("xterm");
    wait_idle;
    send_key "alt-f10";
    become_root();
    type_string "ip link show"; send_key "ret";
    wait_idle;
    save_screenshot;
    if (get_var("DESKTOP") !~ /icewm/) {
	assert_screen "virtman-sle12-gnome_netifcheck", 20;
    } else {
	assert_screen "virtman_netifcheck", 20;
    }
}


sub run {
    my $netif = {
	"type" => "bridge", # type: bridge, bond, ethernet, vlan
	"name" => "br1",
	"startmode" => "onboot", # none, onboot, hotplug
	"activenow" => "true", # true / false
	"ipsetting" => { # only support manual mode
	    "manually" => {
		#"ipv6" => "", # no support
		"active" => "true",
		"ipv4" => {
		    "mode" => "static", # dhcp, static, noconf
		    "address" => "10.0.2.99",
		    "gateway" => "10.0.2.254",
		}, 
	    },
	    "copy" => { # FIXME
		"active" => "false",
		"childinterface" => "",
	    },
	},
	# only in bridge setting
	"bridgesettings" => {
	    "fwddelay" => "0.5", # in seconds
	    "stp" => "true", # true / false
	},
	"interface" => "other", # lo or other
	# vlantag only exist with VLAN
	"vlantag" => "3",
    };
    go_for_netif($netif);
    
#    $netif->{type} = "bond";
#    $netif->{name} = "bond1";
#    $netif->{startmode} = "none";
#    $netif->{activenow} = "false";
#    $netif->{ipsetting}{manually}{active} = "true";
#    $netif->{ipsetting}{copy}{active} = "false";
#    $netif->{interface} = "other";
#    go_for_netif($netif);

    $netif->{type} = "vlan";
    $netif->{startmode} = "onboot";
    $netif->{activenow} = "false";
    $netif->{ipsetting}{manually}{active} = "true";
    $netif->{ipsetting}{manually}{ipv4}{mode} = "dhcp";
    $netif->{vlantag} = "2";
    $netif->{interface} = "other";
    go_for_netif($netif);
    delete_netinterface();

    $netif->{type} = "ethernet";
    $netif->{startmode} = "hotplug";
    $netif->{activenow} = "true";
    $netif->{ipsetting}{manually}{active} = "true";
    $netif->{ipsetting}{manually}{ipv4}{mode} = "static";
    $netif->{ipsetting}{manually}{ipv4}{address} = "10.1.2.22";
    $netif->{ipsetting}{manually}{ipv4}{gateway} = "10.1.2.25";
    $netif->{interface} = "other";
    go_for_netif($netif);

    checking_netif_result();
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 0, fatal => 0 };
}

1;

# vim: set sw=4 et:
