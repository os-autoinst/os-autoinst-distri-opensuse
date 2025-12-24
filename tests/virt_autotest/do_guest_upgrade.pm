# GUEST UPGRADE PREPARATION MODULE
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module does guest upgrade for all involved guests by monitoring
# upgrade progress proactively one by one in a loop unitl a definite result is
# obtained or times out. Guest upgrade is only deemed as PASSED if os version
# after upgrade matches the expected one and ssh connectivity is good.
#
# Variables:
# GUEST_UPGRADE_START_RUN
# GUEST_UPGRADE_STOP_RUN
# GUEST_UPGRADE_TEST_TIME
# GUEST_UPGRADE_STATUS
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt@suse.de
package do_guest_upgrade;

use base "opensusebasetest";
use testapi;
use utils;
use Tie::IxHash;
use POSIX qw(strftime);
use Data::Dumper;
use version_utils;
use virt_autotest::utils;
use virt_autotest::domain_management_utils;
use Utils::Logging;
use zypper;

our $host_name;
our $log_root;
our $log_folder;
our @guest_upgrade_list;
our @interim_guest_upgrade_list;
our %guest_upgrade_session;
our @guest_upgrade_done;
our $ssh_command;
our %guest_matrix;

sub run {
    my $self = shift;

    $self->init_upgrade;
    $self->start_upgrade;
    $self->wait_upgrade;
    $self->cleanup_upgrade;
    return $self;
}

sub init_upgrade {
    my $self = shift;

    record_info('Init Upgrade');
    $host_name = script_output("hostname");
    $log_root = get_var('LOG_ROOT') ? get_required_var('LOG_ROOT') : '/var/lib/openqa/pool/' . get_required_var('WORKER_INSTANCE') . '/';
    $log_folder = $log_root . 'guest_upgrade/';
    @guest_upgrade_list = split(/\|/, get_var('GUEST_UPGRADE_LIST', ''));
    @interim_guest_upgrade_list = split(/\|/, get_var('INTERIM_GUEST_UPGRADE_LIST', ''));
    %guest_upgrade_session = ();
    @guest_upgrade_done = ();
    $ssh_command = 'ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa ';
    tie %guest_matrix, 'Tie::IxHash', ();
    script_run("mkdir -p $log_folder");
    diag("GUEST_UPGRADE_LIST: @guest_upgrade_list");
    while (my ($index, $guest) = each(@guest_upgrade_list)) {
        tie my %single_guest_upgrade_session, 'Tie::IxHash', (title => '', config => '', tty => '', pid => '', id => '', log => '', attached => 'false', start_run => '', stop_run => '', stop_timestamp => '', result => '');
        $guest_upgrade_session{$guest} = \%single_guest_upgrade_session;
        $guest_upgrade_session{$guest}{title} = $guest;
        $guest_upgrade_session{$guest}{config} = $log_folder . $guest . '_upgrade_session_' . strftime('%Y%m%d_%H%M%S', localtime()) . '.config';
        $guest_upgrade_session{$guest}{log} = $log_folder . $guest . '_upgrade_session_' . strftime('%Y%m%d_%H%M%S', localtime()) . '.log';
        if ($interim_guest_upgrade_list[$index] =~ /^abnormal_/img) {
            $guest_upgrade_session{$guest}{start_run} = time();
            $self->record_guest_upgrade_result(guest => $guest, result => 'UNKNOWN', reason => 'Skip abnormal guest');
        }
        script_run("rm -f -r $guest_upgrade_session{$guest}{config};touch $guest_upgrade_session{$guest}{config};chmod 777 $guest_upgrade_session{$guest}{config}");
        script_run("cat /etc/screenrc > $guest_upgrade_session{$guest}{config};sed -i -r \'/^logfile .*\$/d\' $guest_upgrade_session{$guest}{config}");
        script_run("echo \"logfile $guest_upgrade_session{$guest}{log}\" >> $guest_upgrade_session{$guest}{config}");
    }
    $self->update_guest_upgrade_list;
    return $self;
}

sub start_upgrade {
    my $self = shift;

    my $ret = 0;
    record_info('Start Upgrade');
    diag("GUEST_UPGRADE_LIST: @guest_upgrade_list");
    while (my ($index, $guest) = each(@guest_upgrade_list)) {
        $guest_upgrade_session{$guest}{start_run} = time();
        if ($interim_guest_upgrade_list[$index] =~ /^abnormal_/img) {
            $ret += 1;
            $self->record_guest_upgrade_result(guest => $guest, result => 'UNKNOWN', reason => 'Skip abnormal guest');
            next;
        }
        if (script_run("virsh reboot --domain $guest") != 0) {
            $ret += 1;
            $interim_guest_upgrade_list[$index] = 'abnormal_' . $guest_upgrade_list[$index];
            $self->record_guest_upgrade_result(guest => $guest, result => 'FAILED', reason => 'Reboot failed');
            next;
        }
        my $temp = 0;
        record_info("Started trying upgrade guest $guest");
        enter_cmd("screen -t $guest_upgrade_session{$guest}{title} -L -c $guest_upgrade_session{$guest}{config} virsh console --force --domain $guest", timeout => 180);
        if (check_screen('grub-menu-migration-text', 120)) {
            send_key('ret');
        }
        else {
            $temp |= 1;
            save_screenshot;
            record_info("Guest $guest has no migration grub menu", 'Please check relevant info', result => 'fail');
        }
        if (get_var('KNOWN_PRODUCT_ISSUE')) {
            record_info('Please be aware of existing product bug that leads to this workaround', 'Please check relevant info', result => 'fail');
            check_screen('linux-login', 300) ? record_info("Guest $guest upgrade trying", 'Upgrade successful or not needs to be furhter checked', result => 'fail') :
              ($temp |= 1 and record_info("Guest $guest upgrade did not even start trying", 'Please check relevant info', result => 'fail'));
        }
        else {
            check_screen('migration-running', 300) ? record_info("Guest $guest upgrade started") : ($temp |= 1 and record_info("Guest $guest upgrade did not start", 'Please check relevant info', result => 'fail'));
        }
        save_screenshot;
        ($guest_upgrade_session{$guest}{tty}, $guest_upgrade_session{$guest}{pid}, $guest_upgrade_session{$guest}{id}, $guest_upgrade_session{$guest}{attached}) =
          virt_autotest::domain_management_utils::do_detach_guest_screen(host => $host_name, guest => $guest, sessname => $guest_upgrade_session{$guest}{title}, sessid => $guest_upgrade_session{$guest}{id},
            needle => 'text-logged-in-host-as-root');
        ($guest_upgrade_session{$guest}{tty}, $guest_upgrade_session{$guest}{pid}, $guest_upgrade_session{$guest}{id}) =
          virt_autotest::domain_management_utils::get_guest_screen_session(host => $host_name, guest => $guest, sessname => $guest_upgrade_session{$guest}{title}, sessid => $guest_upgrade_session{$guest}{id});
        record_info("Guest $guest upgrade session info", Dumper($guest_upgrade_session{$guest}));
        if ($temp) {
            $interim_guest_upgrade_list[$index] = 'abnormal_' . $guest_upgrade_list[$index];
            $self->record_guest_upgrade_result(guest => $guest, result => 'FAILED', reason => 'Upgrade process did not start as expected');
            $ret += 1;
            next;
        }
    }
    $self->update_guest_upgrade_list;
    record_info('Guest upgrade info after start_upgrade', "ORIGINAL GUEST_UPGRADE_LIST:" . get_required_var('GUEST_UPGRADE_LIST') . "\nINTERIM_GUEST_UPGRADE_LIST:" . get_required_var('INTERIM_GUEST_UPGRADE_LIST') .
          "\nSERIAL_SOURCE_ADDRESS:" . get_required_var('SERIAL_SOURCE_ADDRESS'));
    die('No guest upgrade started successfully') if ($ret == scalar @guest_upgrade_list);
    ($ret == 0) ? record_info('All guests started upgrading successfully') : record_info('Not all guests started upgrading successfully', 'Upgrade process did not start as expected for certain guests', result => 'fail');
    return $self;
}

sub wait_upgrade {
    my $self = shift;

    my $ret = 0;
    record_info('Wait Upgrade');
    my $guest_upgrade_left = scalar(@guest_upgrade_list);
    diag("GUEST_UPGRADE_LEFT: $guest_upgrade_left");
    my $guest_upgrade_not_the_last = 1;
    my $start_time = time();
    my $wait_time = time();
    while ($wait_time - $start_time <= 14400) {
        diag("GUEST_UPGRADE_LIST: @guest_upgrade_list");
        while (my ($index, $guest) = each(@guest_upgrade_list)) {
            diag("BEGINNING GUEST: $guest RESULT: $guest_upgrade_session{$guest}{result}");
            if ($interim_guest_upgrade_list[$index] =~ /^abnormal_/img and !$self->is_guest_upgrade_done(guest => $guest)) {
                $ret += 1;
                push(@guest_upgrade_done, $guest);
                $guest_upgrade_left = scalar(@guest_upgrade_list) - scalar(@guest_upgrade_done);
                diag("GUEST_UPGRADE_LEFT: $guest_upgrade_left");
                $self->record_guest_upgrade_result(guest => $guest, result => 'UNKNOWN', reason => 'Skip abnormal guest');
                next;
            }
            if (!$self->is_guest_upgrade_done(guest => $guest)) {
                $self->attach_guest_upgrade_screen(guest => $guest) if (($guest_upgrade_not_the_last ne 0) or ($guest_upgrade_session{$guest}{attached} ne 'true'));
                $self->check_upgrade(guest => $guest);
                if (!$self->is_guest_upgrade_done(guest => $guest)) {
                    $guest_upgrade_not_the_last = 0 if ($guest_upgrade_left eq 1);
                    ($guest_upgrade_session{$guest}{tty}, $guest_upgrade_session{$guest}{pid}, $guest_upgrade_session{$guest}{id}, $guest_upgrade_session{$guest}{attached}) =
                      virt_autotest::domain_management_utils::do_detach_guest_screen(host => $host_name, guest => $guest, sessname => $guest_upgrade_session{$guest}{title}, sessid => $guest_upgrade_session{$guest}{id},
                        needle => 'text-logged-in-host-as-root')
                      if (($guest_upgrade_not_the_last ne 0) and ($guest_upgrade_session{$guest}{attached} ne 'false'));
                }
            }
            if ((!(grep { $_ eq $guest } @guest_upgrade_done)) and $self->is_guest_upgrade_done(guest => $guest)) {
                push(@guest_upgrade_done, $guest);
                $guest_upgrade_left = scalar(@guest_upgrade_list) - scalar(@guest_upgrade_done);
                diag("GUEST_UPGRADE_LEFT: $guest_upgrade_left");
                if ($guest_upgrade_session{$guest}{result} ne 'PASSED') {
                    $ret += 1;
                    $interim_guest_upgrade_list[$index] = 'abnormal_' . $guest_upgrade_list[$index];
                    diag("GUEST: $guest RESULT: $guest_upgrade_session{$guest}{result}");
                }
                diag("AFTER1 GUEST: $guest RESULT: $guest_upgrade_session{$guest}{result}");
                last if ($guest_upgrade_left eq 0);
            }
            diag("AFTER2 GUEST: $guest RESULT: $guest_upgrade_session{$guest}{result}");
        }
        last if ($guest_upgrade_left eq 0);
        sleep 60;
        $wait_time = time();
    }

    $self->update_guest_upgrade_list;
    foreach my $guest (@guest_upgrade_list) {
        diag("GUEST $guest RESULT: $guest_upgrade_session{$guest}{result}");
        if (!$guest_upgrade_session{$guest}{result}) {
            ($wait_time - $start_time <= 14400) ? $self->record_guest_upgrade_result(guest => $guest, result => 'UNKNOWN', reason => 'Upgrade failed due to unknown reason') :
              $self->record_guest_upgrade_result(guest => $guest, result => 'TIMEOUT', reason => 'Upgrade exceeded timeout');
        }
    }

    $self->update_guest_upgrade_list;
    record_info('Guest upgrade info after wait_upgrade', "ORIGINAL GUEST_UPGRADE_LIST:" . get_required_var('GUEST_UPGRADE_LIST') . "\nINTERIM_GUEST_UPGRADE_LIST:" . get_required_var('INTERIM_GUEST_UPGRADE_LIST') .
          "\nSERIAL_SOURCE_ADDRESS:" . get_required_var('SERIAL_SOURCE_ADDRESS'));
    die('No guest upgrade finished successfully') if ($ret == scalar @guest_upgrade_list);
    ($ret == 0) ? record_info('All guests finished upgrade successfully') : record_info('Not all guests finished upgrade successfully', 'Upgrade process did not finish as expected for certain guests', result => 'fail');
    return $self;
}

sub check_upgrade {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name/ip must be given') if (!$args{guest});

    if (!(check_screen([qw(text-logged-in-host-as-root guest-upgrade-in-progress guest-upgrade-failure grub2 text-login)], 300))) {
        record_info("Can not detect any relevant needle on guest $args{guest} upgrade process");
    }
    elsif (match_has_tag('grub2')) {
        send_key('ret');
    }
    elsif (match_has_tag('text-login')) {
        $self->check_security_control(guest => $args{guest}) if (get_var('CHECK_GUEST_SECURITY'));
        if (get_var('CHECK_GUEST_SECURITY') and !check_screen('text-login', timeout => 30)) {
            $self->detach_guest_upgrade_screen(guest => $args{guest});
            select_backend_console(init => 0);
            $self->terminate_guest_upgrade_session(guest => $args{guest});
            $guest_upgrade_session{$args{guest}}{attached} = 'false';
            $guest_upgrade_session{$args{guest}}{id} = '';
            $self->attach_guest_upgrade_screen(guest => $args{guest});
            $self->detach_guest_upgrade_screen(guest => $args{guest});
            ($guest_upgrade_session{$args{guest}}{tty}, $guest_upgrade_session{$args{guest}}{pid}, $guest_upgrade_session{$args{guest}}{id}) =
              virt_autotest::domain_management_utils::get_guest_screen_session(host => $host_name, guest => $args{guest}, sessname => $guest_upgrade_session{$args{guest}}{title}, sessid => $guest_upgrade_session{$args{guest}}{id});
        }
        else {
            $self->detach_guest_upgrade_screen(guest => $args{guest});
        }
        $self->check_ip_address(guest => $args{guest}) if (get_var('CHECK_GUEST_IPADDR'));
        $self->check_upgrade_os(guest => $args{guest});
    }
    elsif (match_has_tag('guest-upgrade-in-progress')) {
        record_info("Upgrade guest $args{guest} still in progress");
    }
    elsif (match_has_tag('guest-upgrade-failure')) {
        $self->record_guest_upgrade_result(guest => $args{guest}, result => 'FAILED', reason => 'Guest upgrade failure occurred');
        $self->detach_guest_upgrade_screen(guest => $args{guest});
    }
    elsif (match_has_tag('text-logged-in-host-as-root')) {
        $guest_upgrade_session{$args{guest}}{attached} = 'false';
        $guest_upgrade_session{$args{guest}}{id} = '';
        record_info("Upgrade guest $args{guest} screen detached unexpectedly", 'Need to check its screen session', result => 'fail');
        ($guest_upgrade_session{$args{guest}}{tty}, $guest_upgrade_session{$args{guest}}{pid}, $guest_upgrade_session{$args{guest}}{id}) =
          virt_autotest::domain_management_utils::get_guest_screen_session(host => $host_name, guest => $args{guest}, sessname => $guest_upgrade_session{$args{guest}}{title}, sessid => $guest_upgrade_session{$args{guest}}{id});
    }
    save_screenshot;
    return $self;
}

sub check_security_control {
    my ($self, %args) = @_;
    $args{guest} //= '';

    enter_cmd('root');
    assert_screen('password-prompt', timeout => 30);
    enter_cmd(get_var('_SECRET_GUEST_PASSWORD', ''), wait_screen_change => 60, max_interval => 1, timeout => 90);
    wait_still_screen(15);
    enter_cmd("reset");
    enter_cmd("timeout --kill-after=1 --signal=9 120 ip addr show && ip route show all", wait_still_screen => 5, timeout => 150);
    save_screenshot;
    enter_cmd("timeout --kill-after=1 --signal=9 120 systemctl --no-pager --full status firewalld;systemctl --no-pager --full status apparmor;cat /etc/selinux/config", wait_still_screen => 5, timeout => 150);
    save_screenshot;
    enter_cmd("timeout --kill-after=1 --signal=9 120 systemctl stop firewalld;systemctl disable firewalld;systemctl stop apparmor;systemctl disable apparmor", wait_still_screen => 5, timeout => 150);
    save_screenshot;
    enter_cmd("timeout --kill-after=1 --signal=9 120 systemctl --no-pager --full status firewalld;systemctl --no-pager --full status apparmor;cat /etc/selinux/config", wait_still_screen => 5, timeout => 150);
    wait_still_screen;
    enter_cmd("exit");
    wait_still_screen(15);
    return $self;
}

sub check_ip_address {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{confdir} //= '/var/lib/libvirt/images';
    die('Guest name/ip must be given') if (!$args{guest});

    tie my %single_guest_matrix, 'Tie::IxHash', (macaddr => '', ipaddr => '', nettype => '', netname => '', netmode => '', staticip => 'no');
    $guest_matrix{$args{guest}} = \%single_guest_matrix;
    $ret = 1;
    $ret = script_run("virsh dumpxml $args{guest} > $args{confdir}/$args{guest}.xml");
    record_info("Guest $args{guest} config", script_output("cat $args{confdir}/$args{guest}.xml"));
    virt_autotest::virtual_network_utils::check_guest_network_config(guest => $args{guest}, matrix => \%guest_matrix);
    virt_autotest::virtual_network_utils::check_guest_network_address(guest => $args{guest}, matrix => \%guest_matrix);
    virt_autotest::domain_management_utils::show_guest();
    record_info("Guest $args{guest} network config info",
        "macaddr:$guest_matrix{$args{guest}}{macaddr}, ipaddr:$guest_matrix{$args{guest}}{ipaddr}, nettype:$guest_matrix{$args{guest}}{nettype},
         netmode:$guest_matrix{$args{guest}}{netmode}, netname:$guest_matrix{$args{guest}}{netname}, staticip:$guest_matrix{$args{guest}}{staticip}");
    $ret |= script_run("virsh domiflist $args{guest}");
    return $self;
}

sub check_upgrade_os {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name/ip must be given') if (!$args{guest});

    if (script_run("timeout --kill-after=3 --signal=9 30 " . $ssh_command . "root\@$args{guest} hostname", timeout => 60) == 0) {
        my $version = script_output("timeout --kill-after=3 --signal=9 30 " . $ssh_command . "root\@$args{guest} cat /etc/os-release | grep ^VERSION= | awk -F\'\"\' '{print \$2}'", type_command => 1, proceed_on_failure => 1);
        my $version_id = script_output("timeout --kill-after=3 --signal=9 30 " . $ssh_command . "root\@$args{guest} cat /etc/os-release | grep ^VERSION_ID= | awk -F\'\"\' '{print \$2}'", type_command => 1, proceed_on_failure => 1);
        diag("VERSION: $version");
        diag("VERSION_ID: $version_id");
        diag("TEST SUITE VERSION: " . get_required_var('VERSION'));
        ($version_id eq get_required_var('VERSION_ENV')) ? $self->record_guest_upgrade_result(guest => $args{guest}, result => 'PASSED') : $self->record_guest_upgrade_result(guest => $args{guest}, result => 'FAILED', reason => 'Wrong OS version');
    }
    else {
        record_info("Upgrade guest $args{guest} finished", "But guest $args{guest} has connectivity issue.\nscript_output('ip addr show;ip route show all')", result => 'fail');
        $self->record_guest_upgrade_result(guest => $args{guest}, result => 'FAILED', reason => 'Guest ssh failed');
    }
    return $self;
}

sub cleanup_upgrade {
    my $self = shift;

    record_info('Cleanup Upgrade');
    my @guest_upgrade_start_run = ();
    my @guest_upgrade_stop_run = ();
    my @guest_upgrade_test_time = ();
    my @guest_upgrade_status = ();
    diag("GUEST_UPGRADE_LIST: @guest_upgrade_list");
    while (my ($index, $guest) = each(@guest_upgrade_list)) {
        $self->detach_guest_upgrade_screen(guest => $guest);
        $self->terminate_guest_upgrade_session(guest => $guest);
        diag("GUEST: $guest START_RUN: $guest_upgrade_session{$guest}{start_run} STOP_RUN: $guest_upgrade_session{$guest}{stop_run} STATUS: $guest_upgrade_session{$guest}{result}");
        push(@guest_upgrade_start_run, $guest_upgrade_session{$guest}{start_run});
        push(@guest_upgrade_stop_run, $guest_upgrade_session{$guest}{stop_run});
        push(@guest_upgrade_test_time, strftime("\%Hh\%Mm\%Ss", gmtime($guest_upgrade_session{$guest}{stop_run} - $guest_upgrade_session{$guest}{start_run})));
        push(@guest_upgrade_status, $guest_upgrade_session{$guest}{result});
    }
    diag("ARRAY START_RUN: @guest_upgrade_start_run ARRAY STOP_RUN: @guest_upgrade_stop_run ARRAY TIME: @guest_upgrade_test_time ARRAY STATUS: @guest_upgrade_status");
    set_var('GUEST_UPGRADE_START_RUN', join('|', @guest_upgrade_start_run));
    set_var('GUEST_UPGRADE_STOP_RUN', join('|', @guest_upgrade_stop_run));
    set_var('GUEST_UPGRADE_TEST_TIME', join('|', @guest_upgrade_test_time));
    set_var('GUEST_UPGRADE_STATUS', join('|', @guest_upgrade_status));
    bmwqemu::save_vars();
    record_info('Guest upgrade info', "ORIGINAL GUEST_UPGRADE_LIST:" . get_required_var('GUEST_UPGRADE_LIST') . "\nINTERIM_GUEST_UPGRADE_LIST:" . get_required_var('INTERIM_GUEST_UPGRADE_LIST') .
"\nSERIAL_SOURCE_ADDRESS:" . get_required_var('SERIAL_SOURCE_ADDRESS') . "\nGUEST_UPGRADE_START_RUN:" . get_required_var('GUEST_UPGRADE_START_RUN') . "\nGUEST_UPGRADE_STOP_RUN:" .
          get_required_var('GUEST_UPGRADE_STOP_RUN') . "\nGUEST_UPGRADE_TEST_TIME:" . get_required_var('GUEST_UPGRADE_TEST_TIME') . "\nGUEST_UPGRADE_STATUS:" . get_required_var('GUEST_UPGRADE_STATUS'));
    virt_utils::collect_host_and_guest_logs(extra_host_log => "$log_folder /var/log", extra_guest_log => '/var/log', full_supportconfig => get_var('FULL_SUPPORTCONFIG', 1), token => '_guest_upgrade', keep => 'true', timeout => 14400);
    return $self;
}

sub attach_guest_upgrade_screen {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{needle} //= 'text-logged-in-host-as-root';
    die('Guest name/ip must be given') if (!$args{guest});

    record_info("Attaching $args{guest} upgrade screen with $guest_upgrade_session{$args{guest}}{id}");
    if (($guest_upgrade_session{$args{guest}}{attached} eq 'false') or ($guest_upgrade_session{$args{guest}}{attached} eq '')) {
        if (!$guest_upgrade_session{$args{guest}}{id}) {
            record_info("Guest $args{guest} upgrade screen process may terminate on reboot after upgrade finishes", "Reconnect by using screen -t $guest_upgrade_session{$args{guest}}{title} virsh console $args{guest}");
            ($guest_upgrade_session{$args{guest}}{config}, $guest_upgrade_session{$args{guest}}{command}, $guest_upgrade_session{$args{guest}}{attached}, $guest_upgrade_session{$args{guest}}{result}) =
              virt_autotest::domain_management_utils::do_attach_guest_screen_without_sessid(guest => $args{guest}, sessid => $guest_upgrade_session{$args{guest}}{id},
                sessconf => $guest_upgrade_session{$args{guest}}{config}, command => $guest_upgrade_session{$args{guest}}{command}, logfolder => $log_folder, needle => $args{needle});
        }
        else {
            virt_autotest::domain_management_utils::do_attach_guest_screen_with_sessid(guest => $args{guest}, sessid => $guest_upgrade_session{$args{guest}}{id}, needle => $args{needle});
            if (!check_screen($args{needle})) {
                $guest_upgrade_session{$args{guest}}{attached} = 'true';
                record_info("Attached $args{guest} upgrade screen with $guest_upgrade_session{$args{guest}}{id} successfully");
            }
            else {
                record_info("Failed to attach $args{guest} upgrade screen with $guest_upgrade_session{$args{guest}}{id}", "Try to re-connect by using screen -t $guest_upgrade_session{$args{guest}}{title} virsh console $args{guest}");
                ($guest_upgrade_session{$args{guest}}{config}, $guest_upgrade_session{$args{guest}}{command}, $guest_upgrade_session{$args{guest}}{attached}, $guest_upgrade_session{$args{guest}}{result}) =
                  virt_autotest::domain_management_utils::do_attach_guest_screen_without_sessid(guest => $args{guest}, sessid => $guest_upgrade_session{$args{guest}}{id},
                    sessconf => $guest_upgrade_session{$args{guest}}{config}, command => $guest_upgrade_session{$args{guest}}{command}, logfolder => $log_folder, needle => $args{needle});
            }
        }
    }
    else {
        record_info("Guest $args{guest} upgrade screen with $guest_upgrade_session{$args{guest}}{id} attached");
    }
    record_info("Guest $args{guest} upgrade session info", Dumper($guest_upgrade_session{$args{guest}}));
    return $self;
}

sub detach_guest_upgrade_screen {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name/ip must be given') if (!$args{guest});

    save_screenshot;
    record_info("Detaching $args{guest} upgrade screen with $guest_upgrade_session{$args{guest}}{id}");
    if ($guest_upgrade_session{$args{guest}}{attached} eq 'true') {
        ($guest_upgrade_session{$args{guest}}{tty}, $guest_upgrade_session{$args{guest}}{pid}, $guest_upgrade_session{$args{guest}}{id}, $guest_upgrade_session{$args{guest}}{attached}) =
          virt_autotest::domain_management_utils::do_detach_guest_screen(host => $host_name, guest => $args{guest}, sessname => $guest_upgrade_session{$args{guest}}{title}, sessid => $guest_upgrade_session{$args{guest}}{id},
            needle => 'text-logged-in-host-as-root');
    }
    else {
        record_info("Guest $args{guest} upgrade screen with $guest_upgrade_session{$args{guest}}{id} detached");
        ($guest_upgrade_session{$args{guest}}{tty}, $guest_upgrade_session{$args{guest}}{pid}, $guest_upgrade_session{$args{guest}}{id}) =
          virt_autotest::domain_management_utils::get_guest_screen_session(host => $host_name, guest => $args{guest}, sessname => $guest_upgrade_session{$args{guest}}{title}, sessid => $guest_upgrade_session{$args{guest}}{id})
          if (!$guest_upgrade_session{$args{guest}}{id});
    }
    record_info("Guest $args{guest} upgrade session info", Dumper($guest_upgrade_session{$args{guest}}));
    return $self;
}

sub terminate_guest_upgrade_session {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name/ip must be given') if (!$args{guest});

    if ($guest_upgrade_session{$args{guest}}{id}) {
        script_run("screen -X -S $guest_upgrade_session{$args{guest}}{id} kill");
        record_info("Guest $args{guest} upgrade screen process with $guest_upgrade_session{$args{guest}}{id} terminated");
    }
    else {
        record_info("Guest $args{guest} has no associated upgrade screen process to be terminated");
    }
    return $self;
}

sub record_guest_upgrade_result {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{result} //= '';
    $args{reason} //= 'Reason not provided';
    die('Guest name/ip and result must be given') if (!$args{guest} or !$args{result});

    $guest_upgrade_session{$args{guest}}{result} = $args{result};
    $guest_upgrade_session{$args{guest}}{stop_run} = time();
    $guest_upgrade_session{$args{guest}}{stop_timestamp} = localtime($guest_upgrade_session{$args{guest}}{stop_run});
    diag("GUEST: $args{guest} RESULT: $guest_upgrade_session{$args{guest}}{result}");
    ($args{result} eq 'PASSED') ? record_info("Guest $args{guest} upgrade marked as $args{result}") : record_info("Guest $args{guest} upgrade marked as $args{result}", $args{reason}, result => 'fail');
    return $self;
}

sub is_guest_upgrade_done {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name/ip must be given') if (!$args{guest});

    return 1 if ($guest_upgrade_session{$args{guest}}{result} =~ /PASSED|FAILED|UNKNOWN|TIMEOUT/img);
    return 0;
}

sub update_guest_upgrade_list {
    my $self = shift;

    set_var('INTERIM_GUEST_UPGRADE_LIST', join('|', @interim_guest_upgrade_list));
    bmwqemu::save_vars();
    undef @guest_upgrade_list;
    @guest_upgrade_list = split(/\|/, get_required_var('GUEST_UPGRADE_LIST'));
    return $self;
}

sub test_flags {
    return {
        fatal => 0,
        no_rollback => 1
    };
}

sub post_fail_hook {
    my $self = shift;

    script_run('save_y2logs /tmp/system_prepare-y2logs.tar.bz2');
    upload_logs('/tmp/system_prepare-y2logs.tar.bz2', failok => 1);
    virt_utils::collect_host_and_guest_logs(extra_host_log => "$log_folder /var/log", extra_guest_log => '/var/log', full_supportconfig => get_var('FULL_SUPPORTCONFIG', 1), token => '_guest_upgrade', keep => 'true', timeout => 14400);
    return $self;
}

1;
