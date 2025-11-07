# VIRTUALIZAITON DOMAIN MANAGEMENT UTILITIES
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Domain management utilities providied by various tools,
# for example, libvirt, xl and etc. Also utilities to manage guest
# naming or services.
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt <qe-virt@suse.de>
package virt_autotest::domain_management_utils;

use strict;
use warnings;
use testapi;
use virt_autotest::utils qw(is_kvm_host is_xen_host add_guest_to_hosts);
use utils qw(script_retry);
use Carp;

our @EXPORT = qw(
  construct_uri
  create_guest
  remove_guest
  shutdown_guest
  show_guest
  check_guest_state
  register_guest_name
  manage_guest_service
);

=head2 construct_uri

Construct connection URI to be used with virsh command. URI is composed of many
parts which are all supported here. Please refer to libvirt page for details:
https://libvirt.org/uri.html#remote-uris.
=cut

sub construct_uri {
    my (%args) = @_;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    $args{driver} = (is_kvm_host ? "qemu" : "xen") if (!$args{driver});

    my $uri = "";
    if ($args{host} eq 'localhost') {
        $uri = "$args{driver}:///$args{path}";
    }
    else {
        $uri = ($args{transport} ? "$args{driver}+$args{transport}://" : "$args{driver}://");
        $uri .= "$args{user}@" if ($args{user});
        $uri .= $args{host};
        $uri .= ":$args{port}" if ($args{port});
        $uri .= "/";
        $uri .= $args{path} if ($args{path});
        $uri .= "?$args{extra}" if ($args{extra});
    }
    return $uri;
}

=head2 create_guest

Create guest by using virsh define or xl create. Main arguments are guest to be
created, virtualization management tool to be used, whether die (1) or not (0)
if any failures happen, directory in which guest xml and xl config are stored
and whether start (1) or not (0) guest after defining it. This subroutine also 
calls construct_uri to determine the desired URI to be connected if the interested 
party is not localhost. Please refer to subroutine construct_uri for the arguments 
related.
=cut

sub create_guest {
    my (%args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{confdir} //= '/var/lib/libvirt/images';
    $args{start} //= 1;
    $args{die} //= 0;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be created must be given") if (!$args{guest});

    my $ret = 0;
    my $uri = "--connect=" . construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    foreach my $guest (split(/ /, $args{guest})) {
        my $temp = 1;
        if ($args{virttool} eq 'virsh') {
            $temp = script_run("virsh $uri define --file $args{confdir}/$guest.xml --validate");
            $temp |= script_run("virsh $uri start $guest") if ($args{start} == 1);
            record_info("Failed to create guest $guest from $args{confdir}/$guest.xml", "Failed to create guest $guest using virsh define/start --file $args{confdir}/$guest.xml --validate", result => 'fail') if ($temp != 0);
        }
        elsif ($args{virttool} eq 'xl') {
            $temp = ((script_run("ls $args{confdir}/$guest.cfg") == 0) ? 0 : script_run("virsh $uri domxml-to-native --xml $args{confdir}/$guest.xml --format xen-xl > $args{confdir}/$guest.cfg"));
            $temp |= script_run("xl -vvv create $args{confdir}/$guest.cfg");
            record_info("Guest $guest creating failed", "Failed to create guest $guest using xl -vvv create $args{confdir}/$guest.cfg", result => 'fail') if ($temp != 0);
        }
        $ret |= $temp;
        save_screenshot;
        record_info("Guest $guest config", script_output("cat $args{confdir}/$guest.xml;cat $args{confdir}/$guest.cfg", type_command => 1, proceed_on_failure => 1));
    }
    croak("Failed to define all guests") if ($ret != 0 and $args{die} == 1);
    return $ret;
}

=head2 shutdown_guest

Shutdown guest and verify result. Main arguments are guest to be powered off,
virtualization management tool (virsh or xl) to be used and whether die (1) or
not (0) if any failures happen. This subroutine also calls construct_uri to
determine the desired URI to be connected if the interested party is not
localhost. Please refer to subroutine construct_uri for the arguments related.
=cut

sub shutdown_guest {
    my (%args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{die} //= 0;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be shut down must be given") if (!$args{guest});

    my $ret = 0;
    my $uri = "--connect=" . construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    foreach my $guest (split(/ /, $args{guest})) {
        my $temp = 1;
        if ($args{virttool} eq 'virsh') {
            if (script_run("virsh $uri list --state-shutoff | grep \"$guest \"") != 0) {
                script_retry("virsh $uri shutdown $guest", retry => 12, delay => 10, die => 0);
                if (script_retry("virsh $uri list --state-shutoff | grep \"$guest \"", retry => 12, delay => 10, die => 0) != 0) {
                    script_run("virsh $uri destroy $guest");
                    $temp = script_retry("virsh $uri list --state-shutoff | grep \"$guest \"", retry => 12, delay => 10, die => 0);
                }
                else {
                    $temp = 0;
                }
            }
            else {
                $temp = 0;
            }
        }
        elsif ($args{virttool} eq 'xl') {
            if (script_run("xl -vvv list | grep \"$guest .*---s-- \"") != 0) {
                script_retry("xl -vvv shutdown $guest", retry => 12, delay => 10, die => 0);
                $temp = script_retry("xl -vvv list | grep \"$guest .*---s-- \"", retry => 12, delay => 10, die => 0);
            }
            else {
                $temp = 0;
            }
        }
        $ret |= $temp;
        save_screenshot;
        record_info("Failed to stop guest $guest", "Guest $guest can not be stopped using $args{virttool} shutdown or destroy", result => 'fail') if ($temp != 0);
    }
    croak("Failed to stop all guests") if ($ret != 0 and $args{die} == 1);
    return $ret;
}

=head2 remove_guest

Remove guest forcibly. Main arguments are guest to be removed, and whether die
(1) or not (0) if any failures happen. This subroutine also calls construct_uri
to determine the desired URI to be connected if the interested party is not
localhost. Please refer to subroutine construct_uri for the arguments related.
=cut

sub remove_guest {
    my (%args) = @_;
    $args{guest} //= '';
    $args{die} //= 0;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be removed must be given") if (!$args{guest});

    my $ret = 0;
    my $uri = "--connect=" . construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    foreach my $guest (split(/ /, $args{guest})) {
        my $temp = 1;
        script_run("virsh $uri destroy $guest");
        $temp = ((script_run("virsh $uri list --all | grep \"$guest \"") == 0) ? script_run("virsh $uri undefine $guest || virsh $uri undefine $guest --keep-nvram") : 0);
        $temp |= script_run("xl -vvv destroy $guest") if (is_xen_host and script_run("xl list | grep \"$guest \"") == 0);
        $ret |= $temp;
        save_screenshot;
        record_info("Guest $guest removing failed", "Failed to remove guest $guest", result => 'fail') if ($temp != 0);
    }
    croak("Failed to remove all guests") if ($ret != 0 and $args{die} == 1);
    return $ret;
}

=head2 show_guest

Show all guests available on host or specified ones. Main arguments are guest to
be checked, virtualization management tool to be used (virsh or xl) and whether 
die (1) or not (0) if any failures happen. This subroutine also calls construct_uri 
to determine the desired URI to be connected if the interested party is not localhost. 
Please refer to subroutine construct_uri for the arguments related.
=cut

sub show_guest {
    my (%args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{die} //= 0;
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';

    my $ret = 0;
    my $uri = "--connect=" . construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    if (!$args{guest}) {
        $ret = script_run("virsh $uri list --all");
        $ret |= script_run("xl -vvv list") if (is_xen_host);
        save_screenshot;
        record_info("Listing guests failed", "Failed to list all guests available on host", result => 'fail') if ($ret != 0);
    }
    else {
        foreach my $guest (split(/ /, $args{guest})) {
            my $temp = 1;
            $temp = (($args{virttool} eq 'virsh') ? script_run("virsh $uri list --all | grep \"$guest \"") : script_run("xl -vvv list | grep \"$guest \""));
            $ret |= $temp;
            save_screenshot;
            record_info("Guest $guest xml config", script_output("virsh $uri dumpxml $guest", proceed_on_failure => 1));
            record_info("Guest $guest listing failed", "Failed to list guest $guest", result => 'fail') if ($temp != 0);
        }
    }
    croak("Certain guest listing failed") if ($ret != 0 and $args{die} == 1);
    return $ret;
}

=head2 check_guest_state

Check and return guest state. Main argument are guest to be checked and virtualization
management tool to be used (virsh or xl). This subroutine also calls construct_uri to
determine the desired URI to be connected if the interested party is not localhost.
Please refer to subroutine construct_uri for the arguments related.
=cut

sub check_guest_state {
    my (%args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{driver} //= '';
    $args{transport} //= 'ssh';
    $args{user} //= '';
    $args{host} //= 'localhost';
    $args{port} //= '';
    $args{path} //= 'system';
    $args{extra} //= '';
    croak("Guest to be checked must be given") if (!$args{guest});

    my $uri = "--connect=" . construct_uri(driver => $args{driver}, transport => $args{transport}, user => $args{user}, host => $args{host}, port => $args{port}, path => $args{path}, extra => $args{extra});
    my $state = "";
    $state = (($args{virttool} eq 'virsh') ? script_output("virsh $uri list --all | grep \"$args{guest} \" | awk \'{print \$3\$4}\'", proceed_on_failure => 1) : script_output("xl list | grep \"$args{guest} \" | awk \'{print \$5}\'", proceed_on_failure => 1));
    return $state;
}

=head2 register_guest_name

Configure guest hostname or write corresponding record into /etc/hosts based on
whether dns service is being used or not. Multiple guests and corresponding ip
addresses and domain names can be passed in as strings separated by space. Other
arguments include keyfile (key file for passwordless ssh connection) and usedns
(0 or 1). 
=cut

sub register_guest_name {
    my (%args) = @_;
    $args{guest} //= '';
    $args{ipaddr} //= '';
    $args{keyfile} //= '/root/.ssh/id_ed25519';
    $args{usedns} //= 0;
    $args{domainname} //= '';
    croak("Guest and ip address must be given") if (!$args{guest} or !$args{ipaddr});

    my $ret = 0;
    my %guest_matrix = ();
    foreach (0 .. scalar(split(/ /, $args{guest})) - 1) {
        $guest_matrix{(split(/ /, $args{guest}))[$_]}{ipaddr} = (split(/ /, $args{ipaddr}))[$_];
        $guest_matrix{(split(/ /, $args{guest}))[$_]}{domainname} = (split(/ /, $args{domainname}))[$_];
    }

    my $ssh_command = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ' . get_var('GUEST_SSH_KEYFILE', '/root/.ssh/id_ed25519');
    foreach (keys %guest_matrix) {
        my $temp = 1;
        my $hostname = $_ . '.' . $guest_matrix{$_}{domainname};
        if ($args{usedns}) {
            if (script_run("timeout --kill-after=1 --signal=9 15 $ssh_command root\@$guest_matrix{$_}{ipaddr} ls") == 0) {
                assert_script_run("timeout --kill-after=1 --signal=9 15 $ssh_command root\@$guest_matrix{$_}{ipaddr} \"echo -e $hostname > /etc/hostname\;hostnamectl hostname $hostname;sync\"");
                $temp = 0;
            }
            else {
                enter_cmd("clear", wait_still_screen => 3);
                enter_cmd("timeout --kill-after=1 --signal=9 30 $ssh_command root\@$guest_matrix{$_}{ipaddr} \"echo -e $hostname > /etc/hostname\;hostnamectl hostname $hostname;sync\"", wait_still_screen => 3);
                $temp = (check_screen("password-prompt", 60) ? 0 : 1);
                enter_cmd(get_var('_SECRET_GUEST_PASSWORD', ''), wait_screen_change => 50, max_interval => 1);
                $temp |= (wait_still_screen(35) ? 0 : 1);
            }
        }
        else {
            $temp = add_guest_to_hosts($_, $guest_matrix{$_}{ipaddr});
        }
        save_screenshot;
        record_info("Guest $_ register name failed", "Either setting hostname or writing /etc/hosts failed", result => 'fail') if ($temp != 0);
        $ret |= $temp;
    }
    return $ret;
}

=head2 manage_guest_service

Manage service/target/socket unit in guest by using systemctl command. Multiple
guests and corresponding ip addresses can be passed in as strings separated by
space. Other arguments include keyfile (key file for passwordless ssh connection
), operation (systemctl subcommand) and unit to be manipulated.
=cut

sub manage_guest_service {
    my (%args) = @_;
    $args{guest} //= '';
    $args{ipaddr} //= '';
    $args{keyfile} //= '/root/.ssh/id_ed25519';
    $args{operation} //= 'status';
    $args{unit} //= 'default.target';
    croak("Guest and ip aaddress must be given") if (!$args{guest} or !$args{ipaddr});

    my $ret = 0;
    my %guest_matrix = ();
    $guest_matrix{(split(/ /, $args{guest}))[$_]}{ipaddr} = (split(/ /, $args{ipaddr}))[$_] foreach (0 .. scalar(split(/ /, $args{guest})) - 1);

    my $ssh_command = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ' . get_var('GUEST_SSH_KEYFILE', '/root/.ssh/id_ed25519');
    foreach (keys %guest_matrix) {
        my $temp = 1;
        if (script_run("timeout --kill-after=1 --signal=9 15 $ssh_command root\@$guest_matrix{$_}{ipaddr} ls") == 0) {
            assert_script_run("timeout --kill-after=1 --signal=9 30 $ssh_command root\@$guest_matrix{$_}{ipaddr} \"systemctl $args{operation} $args{unit}\"");
            $temp = 0;
        }
        else {
            enter_cmd("clear", wait_still_screen => 3);
            enter_cmd("timeout --kill-after=1 --signal=9 60 $ssh_command root\@$guest_matrix{$_}{ipaddr} \"systemctl $args{operation} $args{unit}\"", wait_still_screen => 3);
            $temp = (check_screen("password-prompt", 60) ? 0 : 1);
            enter_cmd(get_var('_SECRET_GUEST_PASSWORD', ''), wait_screen_change => 50, max_interval => 1);
            $temp |= (wait_still_screen(35) ? 0 : 1);
        }
        save_screenshot;
        record_info("Guest $_ manage service failed", "Failed to systemctl $args{operation} $args{unit} on guest $_", result => 'fail') if ($temp != 0);
        $ret |= $temp;
    }
    return $ret;
}

1;
