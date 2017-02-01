package opensusebasetest;
use base 'basetest';

use testapi;
use utils;
use strict;

# Base class for all openSUSE tests

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    $self->{in_wait_boot} = 0;
    return $self;
}

# Additional to backend testapi 'clear-console' we do a needle match to ensure
# continuation only after verification
sub clear_and_verify_console {
    my ($self) = @_;

    clear_console;
    assert_screen('cleared-console');

}

sub post_run_hook {
    my ($self) = @_;
    # overloaded in x11 and console
}

sub save_and_upload_log {
    my ($cmd, $file, $args) = @_;
    script_run("$cmd | tee $file", $args->{timeout});
    upload_logs($file) unless $args->{noupload};
    save_screenshot if $args->{screenshot};
}

sub problem_detection {
    my $self = shift;

    type_string "pushd \$(mktemp -d)\n";

    # Slowest services
    save_and_upload_log("systemd-analyze blame", "systemd-analyze-blame.txt", {noupload => 1});
    clear_console;

    # Generate and upload SVG out of `systemd-analyze plot'
    save_and_upload_log('systemd-analyze plot', "systemd-analyze-plot.svg", {noupload => 1});
    clear_console;

    # Failed system services
    save_and_upload_log('systemctl --all --state=failed', "failed-system-services.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Unapplied configuration files
    save_and_upload_log("find /* -name '*.rpmnew'", "unapplied-configuration-files.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Errors, warnings, exceptions, and crashes mentioned in dmesg
    save_and_upload_log("dmesg | grep -i 'error\\|warn\\|exception\\|crash'", "dmesg-errors.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Errors in journal
    save_and_upload_log("journalctl --no-pager -p 'err'", "journalctl-errors.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Tracebacks in journal
    save_and_upload_log('journalctl | grep -i traceback', "journalctl-tracebacks.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Segmentation faults
    save_and_upload_log("coredumpctl list", "segmentation-faults-list.txt", {screenshot => 1, noupload => 1});
    save_and_upload_log("coredumpctl info", "segmentation-faults-info.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Broken links
    save_and_upload_log(
"find / -type d \\( -path /proc -o -path /run -o -path /.snapshots -o -path /var \\) -prune -o -xtype l -exec ls -l --color=always {} \\; -exec rpmquery -f {} \\;",
        "broken-symlinks.txt",
        {screenshot => 1, noupload => 1});
    clear_console;

    # Binaries with missing libraries
    save_and_upload_log("
IFS=:
for path in \$PATH; do
    for bin in \$path/*; do
        ldd \$bin 2> /dev/null | grep 'not found' && echo -n Affected binary: \$bin 'from ' && rpmquery -f \$bin
    done
done", "binaries-with-missing-libraries.txt", {timeout => 60, noupload => 1});
    clear_console;

    # rpmverify problems
    save_and_upload_log("rpmverify -a | grep -v \"[S5T].* c \"", "rpmverify-problems.txt", {timeout => 300, screenshot => 1, noupload => 1});
    clear_console;

    # VMware specific
    if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        save_and_upload_log('systemctl status vmtoolsd vgauthd', "vmware-services.txt", {screenshot => 1, noupload => 1});
        clear_console;
    }

    script_run 'tar cvvJf problem_detection_logs.tar.xz *';
    upload_logs('problem_detection_logs.tar.xz');
    type_string "popd\n";
}

sub export_logs {
    select_console 'root-console';
    save_screenshot;

    problem_detection;

    save_and_upload_log('cat /proc/loadavg', '/tmp/loadavg.txt', {screenshot => 1});
    save_and_upload_log('journalctl -b',     '/tmp/journal.log', {screenshot => 1});
    save_and_upload_log('ps axf',            '/tmp/psaxf.log',   {screenshot => 1});

    # Just after the setup: let's see the network configuration
    save_and_upload_log("ip addr show", "/tmp/ip-addr-show.log");

    save_screenshot;

    # check whether xorg logs is exists in user's home, if yes, upload xorg logs from user's
    # home instead of /var/log
    script_run "test -d /home/*/.local/share/xorg ; echo user-xlog-path-\$? > /dev/$serialdev", 0;
    if (wait_serial("user-xlog-path-0", 10)) {
        save_and_upload_log('cat /home/*/.local/share/xorg/X*', '/tmp/Xlogs.log', {screenshot => 1});
    }
    else {
        save_and_upload_log('cat /var/log/X*', '/tmp/Xlogs.log', {screenshot => 1});
    }

    # do not upload empty .xsession-errors
    script_run
      "xsefiles=(/home/*/.xsession-errors*); for file in \${xsefiles[@]}; do if [ -s \$file ]; then echo xsefile-valid > /dev/$serialdev; fi; done",
      0;
    if (wait_serial("xsefile-valid", 10)) {
        save_and_upload_log('cat /home/*/.xsession-errors*', '/tmp/XSE.log', {screenshot => 1});
    }

    save_and_upload_log('systemctl list-unit-files', '/tmp/systemctl_unit-files.log');
    save_and_upload_log('systemctl status',          '/tmp/systemctl_status.log');
    save_and_upload_log('systemctl',                 '/tmp/systemctl.log', {screenshot => 1});

    script_run "save_y2logs /tmp/y2logs_clone.tar.bz2";
    upload_logs "/tmp/y2logs_clone.tar.bz2";
}

# Set a simple reproducible prompt for easier needle matching without hostname
sub set_standard_prompt {
    $testapi::distri->set_standard_prompt;
}

sub select_bootmenu_option {
    my ($self, $tag, $more) = @_;

    assert_screen "inst-bootmenu", 15;

    # after installation-images 14.210 added a submenu
    if ($more && check_screen "inst-submenu-more", 1) {
        if (get_var('OFW')) {
            send_key_until_needlematch 'inst-onmore', 'up';
        }
        else {
            send_key_until_needlematch('inst-onmore', 'down', 10, 5);
        }
        send_key "ret";
    }
    if (get_var('OFW')) {
        send_key_until_needlematch $tag, 'up';
    }
    else {
        send_key_until_needlematch($tag, 'down', 10, 5);
    }
    send_key "ret";
}

sub export_kde_logs {
    select_console 'root-console';
    save_screenshot;

    if (check_var("DESKTOP", "kde")) {
        if (get_var('PLASMA5')) {
            my $fn = '/tmp/plasma5_configs.tar.bz2';
            my $cmd = sprintf 'tar cjf %s /home/%s/.config/*rc', $fn, $username;
            type_string "$cmd\n";
            upload_logs $fn;
        }
        else {
            my $fn = '/tmp/kde4_configs.tar.bz2';
            my $cmd = sprintf 'tar cjf %s /home/%s/.kde4/share/config/*rc', $fn, $username;
            type_string "$cmd\n";
            upload_logs $fn;
        }
        save_screenshot;
    }
}

# makes sure bootloader appears and then boots to desktop resp text
# mode. Handles unlocking encrypted disk if needed.
# arguments: bootloader_time => seconds # now long to wait for bootloader to appear
sub wait_boot {
    my ($self, %args) = @_;
    my $bootloader_time = $args{bootloader_time} // 100;
    my $textmode        = $args{textmode};
    my $ready_time      = $args{ready_time} // 200;

    # used to register a post fail hook being active while we are waiting for
    # boot to be finished to help investigate in case the system is stuck in
    # shutting down or booting up
    $self->{in_wait_boot} = 1;

    # Reset the consoles after the reboot: there is no user logged in anywhere
    reset_consoles;

    if (get_var("OFW")) {
        assert_screen "bootloader-ofw", $bootloader_time;
    }
    # reconnect s390
    elsif (check_var('ARCH', 's390x')) {
        my $login_ready = qr/Welcome to SUSE Linux Enterprise Server.*\(s390x\)/;
        if (check_var('BACKEND', 's390x')) {

            console('x3270')->expect_3270(
                output_delim => $login_ready,
                timeout      => $ready_time + 100
            );

            # give the system time to have routes up
            # and start serial grab again
            sleep 30;
            select_console('iucvconn');
        }
        else {
            wait_serial($login_ready, $ready_time + 100);
        }

        # on z/(K)VM we need to re-select a console
        if ($textmode || check_var('DESKTOP', 'textmode')) {
            select_console('root-console');
        }
        else {
            select_console('x11');
        }
    }
    # On Xen PV and svirt we don't see a Grub menu
    elsif (!(check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux') && check_var('BACKEND', 'svirt'))) {
        my @tags = ('grub2');
        push @tags, 'bootloader-shim-import-prompt'   if get_var('UEFI');
        push @tags, 'boot-live-' . get_var('DESKTOP') if get_var('LIVETEST');    # LIVETEST won't to do installation and no grub2 menu show up
        if (get_var('ONLINE_MIGRATION')) {
            push @tags, 'migration-source-system-grub2';
        }
        # after gh#os-autoinst/os-autoinst#641 68c815a "use bootindex for boot
        # order on UEFI" the USB install medium is priority and will always be
        # booted so we have to handle that
        # because of broken firmware, bootindex doesn't work on aarch64 bsc#1022064
        push @tags, 'inst-bootmenu' if ((get_var('USBBOOT') and get_var('UEFI')) || (check_var('ARCH', 'aarch64') and get_var('UEFI')));
        check_screen(\@tags, $bootloader_time);
        if (match_has_tag("bootloader-shim-import-prompt")) {
            send_key "down";
            send_key "ret";
            assert_screen "grub2", 15;
        }
        elsif (match_has_tag("migration-source-system-grub2") or match_has_tag('grub2')) {
            send_key "ret";    # boot to source system
        }
        elsif (get_var("LIVETEST")) {
            # prevent if one day booting livesystem is not the first entry of the boot list
            if (!match_has_tag("boot-live-" . get_var("DESKTOP"))) {
                send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 10, 5);
            }
            send_key "ret";
        }
        elsif (match_has_tag('inst-bootmenu')) {
            # assuming the cursor is on 'installation' by default and 'boot from
            # harddisk' is above
            send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
            wait_screen_change { send_key 'ret' };
            if (check_var('ARCH', 'aarch64') and get_var('UEFI')) {
                record_soft_failure 'bsc#1022064';
                assert_screen 'boot-firmware';
                send_key 'ret';
            }
            assert_screen 'grub2', 15;
            # confirm default choice
            send_key 'ret';
        }
        elsif (!match_has_tag("grub2")) {
            # check_screen timeout
            die "needle 'grub2' not found";
        }
    }

    unlock_if_encrypted;

    if ($textmode || check_var('DESKTOP', 'textmode')) {
        assert_screen [qw(linux-login emergency-shell emergency-mode)], $ready_time;
        handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));
        reset_consoles;

        # Without this login name and password won't get to the system. They get
        # lost somewhere. Applies for all systems installed via svirt, but zKVM.
        if (check_var('BACKEND', 'svirt') and !check_var('ARCH', 's390x')) {
            wait_idle;
        }

        $self->{in_wait_boot} = 0;
        return;
    }

    mouse_hide();

    if (get_var("NOAUTOLOGIN") || get_var("XDMUSED")) {
        assert_screen [qw(displaymanager emergency-shell emergency-mode)], $ready_time;
        handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));

        wait_idle;
        if (get_var('DM_NEEDS_USERNAME')) {
            type_string "$username\n";
        }
        # log in
        #assert_screen "dm-password-input", 10;
        elsif (check_var('DESKTOP', 'gnome')) {
            # In GNOME/gdm, we do not have to enter a username, but we have to select it
            send_key 'ret';
        }
        assert_screen 'displaymanager-password-prompt';
        type_password $password. "\n";
    }

    assert_screen [qw(generic-desktop emergency-shell emergency-mode)], $ready_time + 100;
    handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));
    mouse_hide(1);
    $self->{in_wait_boot} = 0;
}

# useful post_fail_hook for any module that calls wait_boot
#
# we could use the same approach in all cases of boot/reboot/shutdown in case
# of wait_boot, e.g. see `git grep -l reboot | xargs grep -L wait_boot`
sub post_fail_hook {
    my ($self) = @_;
    return unless $self->{in_wait_boot};
    # In case the system is stuck in shutting down or during boot up, press
    # 'esc' just in case the plymouth splash screen is shown and we can not
    # see any interesting console logs.
    send_key 'esc';
}

1;
# vim: set sw=4 et:
