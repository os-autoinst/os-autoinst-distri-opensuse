# GUEST UPGRADE PREPARATION MODULE
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module prepares guest upgrade by activating necessary consoles,
# register/deregister extensions, installing packages, toggling repositories,
# adapting system settings and preserving logs.
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt@suse.de
package prepare_guest_upgrade;

use base "opensusebasetest";
use testapi;
use utils;
use version_utils;
use virt_autotest::utils;
use Utils::Logging;
use zypper;
use serial_terminal;
use registration;

our @zypper_allow_exit_codes;
our @serial_getty_ports;
our @guest_upgrade_list;
our @interim_guest_upgrade_list;

sub run {
    my $self = shift;

    @zypper_allow_exit_codes = ('0', '102', '103', '106');
    @serial_getty_ports = ('ttyS0', 'hvc1');
    @guest_upgrade_list = split(/\|/, get_var('GUEST_UPGRADE_LIST', ''));
    @interim_guest_upgrade_list = split(/\|/, get_var('INTERIM_GUEST_UPGRADE_LIST', ''));
    my @ssh_serial_srcdev = get_var('SERIAL_SOURCE_DEVICE') ? split(/\|/, get_var('SERIAL_SOURCE_DEVICE')) : ('ttyS0') x scalar @guest_upgrade_list;
    my $current_serialdev = get_serialdev;
    my $ret = 0;
    while (my ($index, $guest) = each(@guest_upgrade_list)) {
        next if ($interim_guest_upgrade_list[$index] =~ /^abnormal_/img);
        if (script_run("timeout 30 ssh root\@$guest hostname", timeout => 60) != 0) {
            $ret += 1;
            $interim_guest_upgrade_list[$index] = 'abnormal_' . $guest_upgrade_list[$index];
            record_info("Guest $guest ssh failed", 'Please check relevant info', result => 'fail');
            next;
        }
        my $temp = 0;
        record_info("Prepare $guest for upgrade");
        $temp |= $self->prepare_env(guest => $guest, serialdev => $ssh_serial_srcdev[$index]);
        if ($temp) {
            $ret += 1;
            $interim_guest_upgrade_list[$index] = 'abnormal_' . $guest_upgrade_list[$index];
            next;
        }
        $temp |= $self->prepare_console(guest => $guest);
        $temp |= $self->prepare_registration(guest => $guest);
        $temp |= $self->prepare_package(guest => $guest) if ($interim_guest_upgrade_list[$index] =~ /kvm2/im);
        $temp |= $self->prepare_registration(guest => $guest, register => 0);
        $temp |= $self->prepare_repository(guest => $guest) if ($interim_guest_upgrade_list[$index] =~ /kvm2/im);
        $temp |= $self->prepare_system(guest => $guest) if ($interim_guest_upgrade_list[$index] =~ /kvm2/im);
        $temp |= $self->prepare_logs(guest => $guest);
        $temp |= $self->restore_env(guest => $guest, serialdev => $current_serialdev);
        if ($temp) {
            $ret += 1;
            $interim_guest_upgrade_list[$index] = 'abnormal_' . $guest_upgrade_list[$index];
            next;
        }
    }

    set_var('INTERIM_GUEST_UPGRADE_LIST', join('|', @interim_guest_upgrade_list));
    bmwqemu::save_vars();
    record_info('Guest upgrade info', "ORIGINAL GUEST_UPGRADE_LIST:" . get_required_var('GUEST_UPGRADE_LIST') . "\nINTERIM_GUEST_UPGRADE_LIST:" . get_required_var('INTERIM_GUEST_UPGRADE_LIST') .
          "\nSERIAL_SOURCE_ADDRESS:" . get_required_var('SERIAL_SOURCE_ADDRESS') . "\nSERIAL_SOURCE_DEVICE:" . get_required_var('SERIAL_SOURCE_DEVICE'));

    if ($ret == 0) {
        record_info("All guests preparation done");
    }
    elsif ($ret < scalar @guest_upgrade_list) {
        record_info("Certain guests preparation not succeeded", "Please check relevant info", result => 'fail');
    }
    else {
        die("All guests preparation failed");
    }
    return $self;
}

sub prepare_env {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{serialdev} //= 'sshserial';
    die('Guest name or ip must be given') if (!$args{guest});

    my $ret = 0;
    set_serialdev($args{serialdev});
    save_screenshot;
    enter_cmd("reset");
    wait_still_screen;
    enter_cmd("ssh root\@$args{guest}");
    send_key('ret');
    if (!check_screen('text-logged-in-guest-as-root', timeout => 30)) {
        $ret |= 1;
        record_info("Guest $args{guest} prepare_env failed", 'Please check relevant info', result => 'fail');
        $self->restore_env(guest => $args{guest});
    }
    return $ret;
}

sub prepare_console {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name or ip must be given') if (!$args{guest});

    my $ret = 0;
    foreach my $port (@serial_getty_ports) {
        add_serial_console($port);
        $ret |= script_run("systemctl | grep 'serial-getty\@$port.service'");
        $ret |= script_run("chown $testapi::username /dev/$port && usermod -a -G tty,dialout,\$(stat -c %G /dev/$port) $testapi::username", timeout => 120);
        $ret |= script_run("usermod -a -G tty,dialout,\$(stat -c %G /dev/$port) root", timeout => 120);
    }
    record_info("Guest $guest prepare_console failed", script_output('systemctl | grep serial-getty'), result => 'fail') if ($ret);
    return $ret;
}

sub prepare_registration {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{register} //= 1;
    die('Guest name or ip must be given') if (!$args{guest});

    my $ret = 0;
    my $zypper_install_retcode = zypper_call("install --no-allow-downgrade --no-allow-name-change --no-allow-vendor-change suseconnect-ng", exitcode => \@zypper_allow_exit_codes);
    $ret |= 1 if (!scalar(grep { $_ eq $zypper_install_retcode } @zypper_allow_exit_codes));

    if ($args{register}) {
        virt_autotest::utils::subscribe_extensions_and_modules(reg_exts => get_var('GUEST_SCC_REGEXTS', ''));
    }
    else {
        if (get_var('GUEST_SCC_SUBTRACTIONS')) {
            foreach my $addon (split(',', get_var('GUEST_SCC_SUBTRACTIONS'))) {
                my $extension = get_addon_fullname($addon);
                my $version = ($extension eq 'nvidia') ? '15' : scc_version();
                my $arch = get_required_var('ARCH');
                $ret |= script_retry("SUSEConnect -d -p $extension/$version/$arch", retry => 5, delay => 60, timeout => 180, die => 0);
            }
            check_system_registration;
        }
    }
    record_info("Guest $guest prepare_registration failed", script_output('SUSEConnect --status-text'), result => 'fail') if ($ret);
    return $ret;
}

sub prepare_package {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name or ip must be given') if (!$args{guest});

    quit_packagekit;
    wait_quit_zypper;

    my $ret = 0;
    my $repo_server = get_var('REPO_MIRROR_HOST', 'download.suse.de');
    my $repo_home = "http://" . $repo_server . "/ibs/home:/fcrozat:/SLES16/SLE_" . "\$releasever";
    my $repo_images = 'http://' . $repo_server . '/ibs/home:/fcrozat:/SLES16/images/';
    zypper_call("ar --refresh -p 90 '$repo_home' home_sles16");
    zypper_call("ar --refresh -p 90 $repo_images home_images");
    my $zypper_install_retcode = zypper_call("--gpg-auto-import-keys -n in suse-migration-sle16-activation", exitcode => \@zypper_allow_exit_codes);
    if (!scalar(grep { $_ eq $zypper_install_retcode } @zypper_allow_exit_codes)) {
        $ret |= 1;
        record_info("Guest $guest prepare_package failed", script_output('zypper ls --details'), result => 'fail');
    }
    return $ret;
}

sub prepare_system {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name or ip must be given') if (!$args{guest});

    my $ret = 0;
    $ret |= script_run("echo 'url: " . get_var('SCC_URL') . "' > /etc/SUSEConnect");
    $ret |= script_run("sed -i 's/set timeout=[0-9]*/set timeout=-1/' /etc/grub.d/99_migration");
    $ret |= script_run("grub2-mkconfig -o /boot/grub2/grub.cfg");
    record_info("Guest $guest prepare_system failed", script_output('cat /boot/grub2/grub.cfg'), result => 'fail') if ($ret);
    return $ret;
}

sub prepare_repository {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name or ip must be given') if (!$args{guest});

    my $ret = 0;
    my $version = get_var('VERSION_UPGRADE_FROM');
    $version =~ s/-/_/;
    $ret |= script_run('for s in $(zypper -t ls | grep ' . "$version" . ' | sed -e \'s,|.*,,g\'); do zypper modifyservice --disable $s; done');
    $version =~ s/_/\./;
    $version =~ s/SP//;
    $ret |= script_run('for s in $(zypper -t ls | grep ' . "$version" . ' | sed -e \'s,|.*,,g\'); do zypper modifyservice --disable $s; done');
    if (get_var('KNOWN_INFRA_ISSUE')) {
        record_info('Please be aware of existing infra issue that leads to this workaround', 'Please check relevant info', result => 'fail');
        script_run("zypper mr --disable home_sles16");
        script_run("zypper mr --disable home_images");
        zypper_call("ar --refresh -p 90 https://download.nvidia.com/opensuse/leap/16.0 workaround_repo");
    }
    ($ret != 0) ? record_info("Guest $args{guest} prepare_repository failed", script_output('zypper ls --details'), result => 'fail') : record_info("Guest $args{guest} repository info", script_output('zypper ls --details'));
    return $ret;
}

sub prepare_logs {
    my ($self, %args) = @_;
    $args{guest} //= '';
    die('Guest name or ip must be given') if (!$args{guest});

    my $ret = 0;
    upload_logs("/boot/grub2/grub.cfg", failok => 1);
    upload_folders(folders => '/etc/zypp/repos.d/', failok => 1);
    return $ret;
}

sub restore_env {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{serialdev} //= 'ttyS0';
    die('Guest name or ip must be given') if (!$args{guest});

    my $ret = 0;
    set_serialdev($args{serialdev});
    save_screenshot;
    enter_cmd('sync');
    enter_cmd('reset');
    wait_still_screen;
    enter_cmd('exit');
    send_key('ret');
    if (!check_screen('text-logged-in-host-as-root', timeout => 30)) {
        $ret |= 1;
        record_info("Guest $guest restore_env failed", 'Please check relevant info', result => 'fail');
        enter_cmd('exit');
        send_key('ret');
        select_backend_console(init => 0);
    }
    return $ret;
}

sub test_flags {
    return {
        fatal => 1,
        no_rollback => 1
    };
}

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook;
    assert_script_run 'save_y2logs /tmp/system_prepare-y2logs.tar.bz2';
    upload_logs '/tmp/system_prepare-y2logs.tar.bz2';
    return $self;
}

1;
