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
use virt_autotest::utils qw(is_kvm_host is_xen_host add_guest_to_hosts select_backend_console);
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
  do_attach_guest_screen_with_sessid
  do_attach_guest_screen_without_sessid
  do_detach_guest_screen
  get_guest_screen_session
  power_cycle_guest
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
    $args{keyfile} //= '/root/.ssh/id_rsa';
    $args{usedns} //= 0;
    $args{domainname} //= '';
    croak("Guest and ip address must be given") if (!$args{guest} or !$args{ipaddr});

    my $ret = 0;
    my %guest_matrix = ();
    foreach (0 .. scalar(split(/ /, $args{guest})) - 1) {
        $guest_matrix{(split(/ /, $args{guest}))[$_]}{ipaddr} = (split(/ /, $args{ipaddr}))[$_];
        $guest_matrix{(split(/ /, $args{guest}))[$_]}{domainname} = (split(/ /, $args{domainname}))[$_];
    }

    my $ssh_command = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ' . get_var('GUEST_SSH_KEYFILE', '/root/.ssh/id_rsa');
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
    $args{keyfile} //= '/root/.ssh/id_rsa';
    $args{operation} //= 'status';
    $args{unit} //= 'default.target';
    croak("Guest and ip aaddress must be given") if (!$args{guest} or !$args{ipaddr});

    my $ret = 0;
    my %guest_matrix = ();
    $guest_matrix{(split(/ /, $args{guest}))[$_]}{ipaddr} = (split(/ /, $args{ipaddr}))[$_] foreach (0 .. scalar(split(/ /, $args{guest})) - 1);

    my $ssh_command = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ' . get_var('GUEST_SSH_KEYFILE', '/root/.ssh/id_rsa');
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

=head2 do_attach_guest_screen_with_sessid

  do_attach_guest_screen_with_sessid(sessid => 'guest screen session id', needle
      => 'needle to differentiate screen')

Detect needle, for example 'text-logged-in-root', and retry attach guest screen session.

=cut

sub do_attach_guest_screen_with_sessid {
    my %args = @_;
    $args{sessid} //= '';
    $args{needle} //= 'text-logged-in-root';
    die('Guest screen session id must be given') if (!$args{sessid});

    assert_screen($args{needle});
    enter_cmd('reset');
    save_screenshot;
    my $retry_counter = 3;
    while (check_screen($args{needle}, timeout => 5)) {
        if ($retry_counter gt 0) {
            wait_screen_change {
                enter_cmd("screen -d -r $args{sessid}");
            };
            save_screenshot;
            $retry_counter--;
        }
        else {
            save_screenshot;
            last;
        }
        save_screenshot;
        sleep 3;
    }
    save_screenshot;
    return;
}

=head2 do_attach_guest_screen_without_sessid

  do_attach_guest_screen_without_sessid($self)

If guest screen session is already terminated at reboot/shutoff or somehow,
power it on, detect needle 'text-logged-in-root' and retry attaching using
its screen command. Mark it as FAILED if needle 'text-logged-in-root' can
still be detected and poweron can not bring it back.

=cut

sub do_attach_guest_screen_without_sessid {
    my %args = @_;
    $args{guest} //= '';
    $args{sessname} //= $args{guest};
    $args{sessconf} //= '';
    $args{sessid} //= '';
    $args{logfolder} //= '';
    $args{command} //= '';
    $args{needle} //= 'text-logged-in-root';
    die('Guest and screen session log folder must be given') if (!$args{guest} or !$args{logfolder});

    script_run("screen -X -S $args{sessid} kill") if ($args{sessid});
    $args{sessid} = '';
    save_screenshot;
    power_cycle_guest(guest => $args{guest}, style => 'poweron');
    enter_cmd('reset');
    assert_screen($args{needle});
    my $retry_counter = 3;
    while (check_screen($args{needle}, timeout => 5)) {
        if ($retry_counter gt 0) {
            my $attach_timestamp = localtime();
            $attach_timestamp =~ s/ |:/_/g;
            my $session_log = $args{logfolder} . $args{guest} . '_installation_log_' . $attach_timestamp;
            $args{sessconf} = script_output("cd ~;pwd") . '/' . $args{guest} . '_installation_screen_config' if (!$args{sessconf});
            script_run("> $args{sessconf};cat /etc/screenrc > $args{sessconf};sed -in \'/^logfile .*\$/d\' $args{sessconf}");
            script_run("echo \"logfile $session_log\" >> $args{sessconf}");
         #Use "screen" in the most compatible way, screen -t "title (window's name)" -c "screen configuration file" -L(turn on output logging) "command to run".
            #The -Logfile option is only supported by more recent operating systems.
            $args{command} = "screen -t $args{guest} -L -c $args{sessconf} virsh console --force $args{guest}";
            wait_screen_change {
                enter_cmd("$args{command}");
            };
            send_key('ret') for (0 .. 2);
            save_screenshot;
            $retry_counter--;
            sleep 10;
        }
        else {
            save_screenshot;
            last;
        }
        save_screenshot;
    }
    save_screenshot;

    my $guest_screen_attached = 'false';
    my $attach_guest_screen_result = '';
    if (!(check_screen($args{needle}))) {
        $guest_screen_attached = 'true';
        record_info("Opened guest $args{guest} window successfully", "Well done !");
    }
    else {
        record_info("Failed to open guest $args{guest} window", "Bad luck !");
        power_cycle_guest(guest => $args{guest}, style => 'poweron');
        if ((script_output("virsh list --all --name | grep $args{guest}", proceed_on_failure => 1) eq '') or (script_output("virsh list --all | grep \"$args{guest}.*running\"", proceed_on_failure => 1) eq '')) {
            record_info("Guest $args{guest} screen process terminates somehow due to unexpected errors", "Guest disappears or stays at shutoff state even after poweron.Mark it as FAILED", result => 'fail');
            $attach_guest_screen_result = 'FAILED';
        }
    }
    return ($args{sessconf}, $args{command}, $guest_screen_attached, $attach_guest_screen_result);
}

=head2 do_detach_guest_screen

  do_detach_guest_screen(guest => 'guest name', sessid => 'guest screen session id')

Retry doing real guest installation screen detach using send_key('ctrl-a-d') and
detecting needle 'text-logged-in-root'. If either of the needles is detected, this
means successful detach. If neither of the needle can be detected, recover ssh
console by select_console('root-ssh').

=cut

sub do_detach_guest_screen {
    my %args = @_;
    $args{host} //= '';
    $args{guest} //= '';
    $args{sessname} //= '';
    $args{sessid} //= '';
    $args{needle} //= 'text-logged-in-root';
    die('Guest and its screen session name must be given') if (!$args{host} or !$args{guest} or !$args{sessname});

    wait_still_screen;
    save_screenshot;
    my $retry_counter = 3;
    while (!(check_screen($args{needle}, timeout => 5))) {
        if ($retry_counter gt 0) {
            send_key('ctrl-a-d');
            save_screenshot;
            type_string("reset\n");
            wait_still_screen;
            save_screenshot;
            $retry_counter--;
        }
        else {
            last;
        }
    }
    save_screenshot;
    my $session_tty = '';
    my $session_pid = '';
    if (check_screen($args{needle}, timeout => 5)) {
        record_info("Detached $args{guest} screen process $args{sessid} successfully", "Well Done !");
        ($session_tty, $session_pid, $args{sessid}) = get_guest_screen_session(host => $args{host}, guest => $args{guest}, sessname => $args{sessname}, sessid => $args{sessid}) if (!$args{sessid});
        enter_cmd('reset');
        wait_still_screen;
    }
    else {
        record_info("Failed to detach $args{guest} screen process $args{sessid}", "Bad luck !");
        select_backend_console(init => 0);
        ($session_tty, $session_pid, $args{sessid}) = get_guest_screen_session(host => $args{host}, guest => $args{guest}, sessname => $args{sessname}, sessid => $args{sessid}) if (!$args{sessid});
        enter_cmd('reset');
        wait_still_screen;
    }
    my $guest_screen_attached = 'false';
    return ($session_tty, $session_pid, $args{sessid}, $guest_screen_attached);
}

=head2 get_guest_screen_session

  get_guest_screen_session(host => 'host name', guest => 'guest name', sessname
      => 'guest screen session title', sessid => 'guest screen session id')

Get guest screen process information and store it in sessid which is in the form
of 3401.pts-1.vh017.

=cut

sub get_guest_screen_session {
    my %args = @_;
    $args{host} //= '';
    $args{guest} //= '';
    $args{sessname} //= '';
    $args{sessid} //= '';
    die('Host, guest and its screen sessin name must be given') if (!$args{host} or !$args{guest} or !$args{sessname});

    my $session_tty = '';
    my $session_pid = '';
    if ($args{sessid}) {
        record_info("Guest $args{guest} screen process info had already been known", "$args{guest} $args{sessid}");
        my $session_tty = (split('.', $args{sessid}))[1];
        $session_tty = (split('-', $session_tty))[0] if ($session_tty =~ /-/im);
        $session_pid = (split('.', $args{sessid}))[0];
        return ($session_tty, $session_pid, $args{sessid});
    }

    $session_tty = script_output("tty | awk -F\"/\" \'{print \$3}'", proceed_on_failure => 1);
    my $session_ttyno = script_output("tty | awk -F\"/\" \'{print \$4}\'", proceed_on_failure => 1);
    $session_tty = $session_tty . '-' . $session_ttyno if ($session_ttyno);
    #Use grep instead of pgrep to avoid that the latter's case-insensitive search option might not be supported by some obsolete operating systems.
    $session_pid = script_output("ps ax | grep -i \"SCREEN -t $args{guest}\" | grep -v grep | awk \'{print \$1}\'", proceed_on_failure => 1);
    $args{sessid} = (($session_pid eq '') ? '' : ($session_pid . ".$session_tty." . (split(/\./, $args{host}))[0]));
    record_info("Guest $args{guest} screen process info", "$args{guest} $args{sessid}");
    return ($session_tty, $session_pid, $args{sessid});
}

=head2 power_cycle_guest
            
  power_cycle_guest(guest => 'guest domain name or id', style => 'power cycle style')
            
Power cycle guest by force:virsh destroy, grace:virsh shutdown, reboot:virsh
reboot and poweron:virsh start.
                
=cut        

sub power_cycle_guest {
    my %args = @_;
    my ($self, $_power_cycle_style) = @_;
    $args{guest} //= '';
    $args{style} //= 'grace';
    die('Guest domain name/id must be given') if (!$args{guest});

    $args{style} //= 'grace';
    my $guest_name = '';
    my $time_out = '600';
    if ($args{style} eq 'force') {
        script_run("virsh destroy $args{guest}");
    }
    elsif ($args{style} eq 'grace') {
        script_run("virsh shutdown $args{guest}");
    }
    elsif ($args{style} eq 'reboot') {
        script_run("virsh reboot $args{guest}");
        return $self;
    }
    elsif ($args{style} eq 'poweron') {
        script_run("virsh start $args{guest}");
        return $self;
    }

    while (($guest_name ne "$args{guest}") and ($time_out lt 600)) {
        $guest_name = script_output("virsh list --name  --state-shutoff | grep -o $args{guest}", timeout => 30, proceed_on_failure => 1);
        $time_out += 5;
    }
    script_run("virsh start $args{guest}");
    return;
}

1;
