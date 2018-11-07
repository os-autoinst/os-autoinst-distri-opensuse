package opensusebasetest;
use base 'basetest';

use bootloader_setup qw(stop_grub_timeout boot_local_disk tianocore_enter_menu zkvm_add_disk zkvm_add_pty zkvm_add_interface type_hyperv_fb_video_resolution);
use testapi;
use strict;
use utils;
use lockapi 'mutex_wait';
use serial_terminal 'get_login_message';
use version_utils qw(is_sle is_leap is_upgrade is_aarch64_uefi_boot_hdd is_tumbleweed);
use isotovideo;
use IO::Socket::INET;

# Base class for all openSUSE tests

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    $self->{in_wait_boot}    = 0;
    $self->{in_boot_desktop} = 0;
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
    my ($self, $cmd, $file, $args) = @_;
    script_run("$cmd | tee $file", $args->{timeout});
    upload_logs($file) unless $args->{noupload};
    save_screenshot if $args->{screenshot};
}

sub save_and_upload_systemd_unit_log {
    my ($self, $unit) = @_;
    $self->save_and_upload_log("journalctl --no-pager -u $unit", "journal_$unit.log");
}

# btrfs maintenance jobs lead to the system being unresponsive and affects SUT's performance
# Not to waste time during investigation of the failures, we would like to detect
# if such jobs are running, providing a hint why test timed out.
sub detect_bsc_1063638 {
    # Detect bsc#1063638
    record_soft_failure 'bsc#1063638' if (script_run('ps x | grep "btrfs-\(scrub\|balance\|trim\)"') == 0);
}

sub problem_detection {
    my $self = shift;

    type_string "pushd \$(mktemp -d)\n";
    $self->detect_bsc_1063638;
    # Slowest services
    $self->save_and_upload_log("systemd-analyze blame", "systemd-analyze-blame.txt", {noupload => 1});
    clear_console;

    # Generate and upload SVG out of `systemd-analyze plot'
    $self->save_and_upload_log('systemd-analyze plot', "systemd-analyze-plot.svg", {noupload => 1});
    clear_console;

    # Failed system services
    $self->save_and_upload_log('systemctl --all --state=failed', "failed-system-services.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Unapplied configuration files
    $self->save_and_upload_log("find /* -name '*.rpmnew'", "unapplied-configuration-files.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Errors, warnings, exceptions, and crashes mentioned in dmesg
    $self->save_and_upload_log("dmesg | grep -i 'error\\|warn\\|exception\\|crash'", "dmesg-errors.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Errors in journal
    $self->save_and_upload_log("journalctl --no-pager -p 'err'", "journalctl-errors.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Tracebacks in journal
    $self->save_and_upload_log('journalctl | grep -i traceback', "journalctl-tracebacks.txt", {screenshot => 1, noupload => 1});
    clear_console;

    # Segmentation faults
    $self->save_and_upload_log("coredumpctl list", "segmentation-faults-list.txt", {screenshot => 1, noupload => 1});
    $self->save_and_upload_log("coredumpctl info", "segmentation-faults-info.txt", {screenshot => 1, noupload => 1});
    # Save core dumps
    type_string "mkdir -p coredumps\n";
    type_string 'awk \'/Storage|Coredump/{printf("cp %s ./coredumps/\n",$2)}\' segmentation-faults-info.txt | sh';
    type_string "\n";
    clear_console;

    # Broken links
    $self->save_and_upload_log(
"find / -type d \\( -path /proc -o -path /run -o -path /.snapshots -o -path /var \\) -prune -o -xtype l -exec ls -l --color=always {} \\; -exec rpmquery -f {} \\;",
        "broken-symlinks.txt",
        {screenshot => 1, noupload => 1});
    clear_console;

    # Binaries with missing libraries
    $self->save_and_upload_log("
IFS=:
for path in \$PATH; do
    for bin in \$path/*; do
        ldd \$bin 2> /dev/null | grep 'not found' && echo -n Affected binary: \$bin 'from ' && rpmquery -f \$bin
    done
done", "binaries-with-missing-libraries.txt", {timeout => 60, noupload => 1});
    clear_console;

    # rpmverify problems
    $self->save_and_upload_log("rpmverify -a | grep -v \"[S5T].* c \"", "rpmverify-problems.txt", {timeout => 1200, screenshot => 1, noupload => 1});
    clear_console;

    # VMware specific
    if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
        assert_script_run('vm-support');
        upload_logs('vm-*.*.tar.gz');
        clear_console;
    }

    script_run 'tar cvvJf problem_detection_logs.tar.xz *';
    upload_logs('problem_detection_logs.tar.xz');
    type_string "popd\n";
}

sub investigate_yast2_failure {
    my ($self) = shift;

    my $error_detected;
    # first check if badlist exists which could be the most likely problem
    if (my $badlist = script_output 'test -f /var/log/YaST2/badlist && cat /var/log/YaST2/badlist | tail -n 20 || true') {
        record_info 'Likely error detected: badlist', "badlist content:\n\n$badlist", result => 'fail';
        $error_detected = 1;
    }
    # Array with possible strings to search in YaST2 logs
    my @y2log_errors = (
        'Internal error. Please report a bug report',    # Detecting errors
        '<3>',                                           # Detecting problems using error code
        'No textdomain configured',                      # Detecting missing translations
        'nothing provides',                              # Detecting missing required packages
        'but this requirement cannot be provided',       # and package conflicts
        'Could not load icon',                           # Detecting missing icons
        'Couldn\'t load pixmap'                          # additionally with this line, but if not caught with the message above
    );
    for my $y2log_error (@y2log_errors) {
        if (my $y2log_error_result = script_output 'grep -B 3 "' . $y2log_error . '" /var/log/YaST2/y2log | tail -n 20 || true') {
            record_info 'YaST2 log error detected', "Details:\n\n$y2log_error_result", result => 'fail';
            $error_detected = 1;
        }
    }
    if (get_var('ASSERT_Y2LOGS') && $error_detected) {
        die "YaST2 error(s) detected. Please, check details";
    }
}

sub export_logs {
    my ($self) = shift;
    select_console 'log-console';
    save_screenshot;
    $self->remount_tmp_if_ro;
    $self->problem_detection;

    $self->save_and_upload_log('cat /proc/loadavg', '/tmp/loadavg.txt', {screenshot => 1});
    $self->save_and_upload_log('journalctl -b',     '/tmp/journal.log', {screenshot => 1});
    $self->save_and_upload_log('ps axf',            '/tmp/psaxf.log',   {screenshot => 1});

    # Just after the setup: let's see the network configuration
    $self->save_and_upload_log("ip addr show", "/tmp/ip-addr-show.log");

    save_screenshot;

    # check whether xorg logs is exists in user's home, if yes, upload xorg logs from user's
    # home instead of /var/log
    script_run "test -d /home/*/.local/share/xorg ; echo user-xlog-path-\$? > /dev/$serialdev", 0;
    if (wait_serial("user-xlog-path-0", 10)) {
        $self->save_and_upload_log('cat /home/*/.local/share/xorg/X*', '/tmp/Xlogs.log', {screenshot => 1});
    }
    else {
        $self->save_and_upload_log('cat /var/log/X*', '/tmp/Xlogs.log', {screenshot => 1});
    }

    $self->upload_xsession_errors_log;
    $self->save_and_upload_log('systemctl list-unit-files', '/tmp/systemctl_unit-files.log');
    $self->save_and_upload_log('systemctl status',          '/tmp/systemctl_status.log');
    $self->save_and_upload_log('systemctl',                 '/tmp/systemctl.log', {screenshot => 1});

    script_run "save_y2logs /tmp/y2logs_clone.tar.bz2";
    upload_logs "/tmp/y2logs_clone.tar.bz2";
    $self->investigate_yast2_failure();
}

sub upload_xsession_errors_log {
    my ($self) = @_;
    # do not upload empty .xsession-errors
    script_run "xsefiles=(/home/*/{.xsession-errors*,.local/share/sddm/*session.log}); "
      . "for file in \${xsefiles[@]}; do if [ -s \$file ]; then echo xsefile-valid > /dev/$serialdev; fi; done",
      0;
    if (wait_serial("xsefile-valid", 10)) {
        $self->save_and_upload_log('cat /home/*/{.xsession-errors*,.local/share/sddm/*session.log}', '/tmp/XSE.log', {screenshot => 1});
    }
}

sub upload_packagekit_logs {
    my ($self) = @_;
    upload_logs '/var/log/pk_backend_zypp';
}

# Set a simple reproducible prompt for easier needle matching without hostname
sub set_standard_prompt {
    my ($self, $user) = @_;
    $testapi::distri->set_standard_prompt($user);
}

sub select_bootmenu_more {
    my ($self, $tag, $more) = @_;

    # do not waste time waiting when we already matched
    assert_screen 'inst-bootmenu', 15 unless match_has_tag 'inst-bootmenu';
    stop_grub_timeout;

    # after installation-images 14.210 added a submenu
    if ($more && check_screen 'inst-submenu-more', 0) {
        send_key_until_needlematch('inst-onmore', get_var('OFW') ? 'up' : 'down', 10, 5);
        send_key "ret";
    }
    send_key_until_needlematch($tag, get_var('OFW') ? 'up' : 'down', 10, 3);
    if (get_var('UEFI')) {
        send_key 'e';
        send_key 'down' for (1 .. 4);
        send_key 'end';
        # newer versions of qemu on arch automatically add 'console=ttyS0' so
        # we would end up nowhere. Setting console parameter explicitly
        # See https://bugzilla.suse.com/show_bug.cgi?id=1032335 for details
        type_string_slow ' console=tty1' if get_var('MACHINE') =~ /aarch64/;
        # Hyper-V defaults to 1280x1024, we need to fix it here
        type_hyperv_fb_video_resolution if check_var('VIRSH_VMM_FAMILY', 'hyperv');
        send_key 'f10';
    }
    else {
        type_hyperv_fb_video_resolution if check_var('VIRSH_VMM_FAMILY', 'hyperv');
        send_key 'ret';
    }
}

sub export_kde_logs {
    select_console 'log-console';
    save_screenshot;

    if (check_var("DESKTOP", "kde")) {
        if (get_var('PLASMA5')) {
            my $fn  = '/tmp/plasma5_configs.tar.bz2';
            my $cmd = sprintf 'tar cjf %s /home/%s/.config/*rc', $fn, $username;
            type_string "$cmd\n";
            upload_logs $fn;
        }
        else {
            my $fn  = '/tmp/kde4_configs.tar.bz2';
            my $cmd = sprintf 'tar cjf %s /home/%s/.kde4/share/config/*rc', $fn, $username;
            type_string "$cmd\n";
            upload_logs $fn;
        }
        save_screenshot;
    }
}

# Our aarch64 setup fails to boot properly from an installed hard disk so
# point the firmware boot manager to the right file.
sub handle_uefi_boot_disk_workaround {
    my ($self) = @_;
    record_info 'workaround', 'Manually selecting boot entry, see bsc#1022064 for details';
    tianocore_enter_menu;
    send_key_until_needlematch 'tianocore-boot_maintenance_manager', 'down', 5, 5;
    wait_screen_change { send_key 'ret' };
    send_key_until_needlematch 'tianocore-boot_from_file', 'down';
    wait_screen_change { send_key 'ret' };
    save_screenshot;
    wait_screen_change { send_key 'ret' };
    # cycle to last entry by going up in the next steps
    # <EFI>
    send_key 'up';
    save_screenshot;
    wait_screen_change { send_key 'ret' };
    # <sles>
    send_key 'up';
    save_screenshot;
    wait_screen_change { send_key 'ret' };
    # efi file
    send_key 'up';
    save_screenshot;
    wait_screen_change { send_key 'ret' };
}

=head2 wait_boot

  wait_boot([bootloader_time => $bootloader_time] [, textmode => $textmode] [,ready_time => $ready_time] [,in_grub => $in_grub] [, nologin => $nologin] [, forcenologin => $forcenologin]);

Makes sure the bootloader appears and then boots to desktop or text mode
correspondingly. Returns successfully when the system is ready on a login
prompt or logged in desktop. Set C<$textmode> to 1 when the text mode login
prompt should be expected rather than a desktop or display manager.
C<wait_boot> also handles unlocking encrypted disks if needed as well as
various exceptions during the boot process. Also, before the bootloader menu
or login prompt various architecture or machine specific handlings are in
place. The time waiting for the bootloader can be configured with
C<$bootloader_time> in seconds as well as the time waiting for the system to
be fully booted with C<$ready_time> in seconds. Set C<$in_grub> to 1 when the
SUT is already expected to be within the grub menu. C<wait_boot> continues
from there. C<$forcenologin> makes this function behave as if
the env var NOAUTOLOGIN was set.
=cut
sub wait_boot {
    my ($self, %args) = @_;
    my $bootloader_time = $args{bootloader_time} // 100;
    my $textmode        = $args{textmode};
    my $ready_time      = $args{ready_time} // 300;
    my $in_grub         = $args{in_grub} // 0;
    my $nologin         = $args{nologin};
    my $forcenologin    = $args{forcenologin};

    # used to register a post fail hook being active while we are waiting for
    # boot to be finished to help investigate in case the system is stuck in
    # shutting down or booting up
    $self->{in_wait_boot} = 1;

    # Reset the consoles after the reboot: there is no user logged in anywhere
    reset_consoles;
    # reconnect s390
    if (check_var('ARCH', 's390x')) {
        my $login_ready = get_login_message();
        if (check_var('BACKEND', 's390x')) {
            my $console = console('x3270');
            handle_grub_zvm($console);
            $console->expect_3270(
                output_delim => $login_ready,
                timeout      => $ready_time + 100
            );

            # give the system time to have routes up
            # and start serial grab again
            sleep 30;
            select_console('iucvconn');
        }
        else {
            my $worker_hostname = get_required_var('WORKER_HOSTNAME');
            my $virsh_guest     = get_required_var('VIRSH_GUEST');
            workaround_type_encrypted_passphrase if get_var('S390_ZKVM');
            wait_serial('GNU GRUB') || diag 'Could not find GRUB screen, continuing nevertheless, trying to boot';
            select_console('svirt');
            save_svirt_pty;
            type_line_svirt '', expect => $login_ready, timeout => $ready_time + 100, fail_message => 'Could not find login prompt';
            type_line_svirt "root", expect => 'Password';
            type_line_svirt "$testapi::password";
            type_line_svirt "systemctl is-active network", expect => 'active';
            type_line_svirt 'systemctl is-active sshd',    expect => 'active';

            # make sure we can reach the SSH server in the SUT, try up to 1 min (12 * 5s)
            my $retries = 12;
            my $port    = 22;
            for my $i (0 .. $retries) {
                die "The SSH Port in the SUT could not be reached within 1 minute, considering a product issue" if $i == $retries;
                if (IO::Socket::INET->new(PeerAddr => "$virsh_guest", PeerPort => $port)) {
                    record_info("ssh port open", "check for port $port on $virsh_guest successful");
                    last;
                }
                else {
                    record_info("ssh port closed", "check for port $port on $virsh_guest failed", result => 'fail');
                }
                sleep 5;
            }
            save_screenshot;
        }

        # on z/(K)VM we need to re-select a console
        if ($textmode || check_var('DESKTOP', 'textmode')) {
            select_console('root-console');
        }
        else {
            select_console('x11', await_console => 0);
        }
    }
    elsif (check_var('BACKEND', 'ipmi')) {
        select_console 'sol', await_console => 0;
        # boot from harddrive
        assert_screen([qw(virttest-pxe-menu qa-net-selection prague-pxe-menu pxe-menu)], 200);
        send_key 'ret';
    }
    # On Xen PV and svirt we don't see a Grub menu
    elsif (!(check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux') && check_var('BACKEND', 'svirt'))) {
        my @tags = ('grub2');
        push @tags, 'bootloader-shim-import-prompt'   if get_var('UEFI');
        push @tags, 'boot-live-' . get_var('DESKTOP') if get_var('LIVETEST');             # LIVETEST won't to do installation and no grub2 menu show up
        push @tags, 'bootloader'                      if get_var('OFW');
        push @tags, 'encrypted-disk-password-prompt'  if get_var('ENCRYPT');
        push @tags, 'linux-login'                     if get_var('KEEP_GRUB_TIMEOUT');    # Also wait for linux-login if grub timeout was not disabled
        if (get_var('ONLINE_MIGRATION')) {
            push @tags, 'migration-source-system-grub2';
        }
        # after gh#os-autoinst/os-autoinst#641 68c815a "use bootindex for boot
        # order on UEFI" the USB install medium is priority and will always be
        # booted so we have to handle that
        # because of broken firmware, bootindex doesn't work on aarch64 bsc#1022064
        push @tags, 'inst-bootmenu' if ((get_var('USBBOOT') and get_var('UEFI')) || (check_var('ARCH', 'aarch64') and get_var('UEFI')) || get_var('OFW'));
        $self->handle_uefi_boot_disk_workaround
          if (is_aarch64_uefi_boot_hdd
            && !$in_grub
            && (!(isotovideo::get_version() >= 12 && get_var('UEFI_PFLASH_VARS')) || get_var('ONLINE_MIGRATION')));
        check_screen(\@tags, $bootloader_time);
        if (match_has_tag("bootloader-shim-import-prompt")) {
            send_key "down";
            send_key "ret";
            assert_screen "grub2", 15;
        }
        elsif (get_var("LIVETEST")) {
            # prevent if one day booting livesystem is not the first entry of the boot list
            if (!match_has_tag("boot-live-" . get_var("DESKTOP"))) {
                send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 10, 5);
            }
        }
        elsif (match_has_tag('inst-bootmenu')) {
            # assuming the cursor is on 'installation' by default and 'boot from
            # harddisk' is above
            send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
            boot_local_disk;

            my @tags = qw(grub2 tianocore-mainmenu);
            push @tags, 'encrypted-disk-password-prompt' if (get_var('ENCRYPT'));

            check_screen(\@tags, 15)
              || die 'neither grub2 nor tianocore-mainmenu needles found';
            if (match_has_tag('tianocore-mainmenu')) {
                $self->handle_uefi_boot_disk_workaround();
                check_screen('encrypted-disk-password-prompt', 10);
            }
            if (match_has_tag('encrypted-disk-password-prompt')) {
                workaround_type_encrypted_passphrase;
                assert_screen('grub2');
            }
        }
        elsif (match_has_tag('encrypted-disk-password-prompt')) {
            # unlock encrypted disk before grub
            workaround_type_encrypted_passphrase;
            assert_screen "grub2", 15;
        }
        # If KEEP_GRUB_TIMEOUT is set, SUT may be at linux-login already, so no need to abort in that case
        elsif (!match_has_tag("grub2") and !match_has_tag('linux-login')) {
            # check_screen timeout
            my $failneedle = get_var('KEEP_GRUB_TIMEOUT') ? 'linux-login' : 'grub2';
            die "needle '$failneedle' not found";
        }
        mutex_wait 'support_server_ready' if get_var('USE_SUPPORT_SERVER');
        # confirm default choice
        send_key 'ret';
    }

    # On Xen we have to re-connect to serial line as Xen closed it after restart
    if (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        wait_serial("reboot: (Restarting system|System halted)") if check_var('VIRSH_VMM_TYPE', 'linux');
        console('svirt')->attach_to_running;
        select_console('sut');
    }

    # on s390x svirt encryption is unlocked with workaround_type_encrypted_passphrase before here
    unlock_if_encrypted if !get_var('S390_ZKVM');

    if ($textmode || check_var('DESKTOP', 'textmode')) {
        my $textmode_needles = [qw(linux-login emergency-shell emergency-mode)];
        # Soft-fail for user_defined_snapshot in extra_tests_on_gnome and extra_tests_on_gnome_on_ppc
        # if not able to boot from snapshot
        if (get_var('TEST') !~ /extra_tests_on_gnome/) {
            assert_screen $textmode_needles, $ready_time;
        }
        elsif (!check_screen $textmode_needles, $ready_time) {
            # We are not able to boot due to bsc#980337
            record_soft_failure 'bsc#980337';
            # Switch to root console and continue
            select_console 'root-console';
        }

        handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));

        reset_consoles;
        $self->{in_wait_boot} = 0;
        return;
    }

    mouse_hide();

    if (get_var("NOAUTOLOGIN") || get_var("XDMUSED") || $forcenologin) {
        assert_screen [qw(displaymanager emergency-shell emergency-mode)], $ready_time;
        handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));

        if (!$nologin) {
            # SLE11 SP4 kde desktop do not need type username
            if (get_var('DM_NEEDS_USERNAME')) {
                type_string "$username\n";
            }
            # log in
            #assert_screen "dm-password-input", 10;
            elsif (check_var('DESKTOP', 'gnome')) {
                # In GNOME/gdm, we do not have to enter a username, but we have to select it
                if (is_tumbleweed) {
                    send_key 'tab';
                }
                send_key 'ret';
            }

            assert_screen 'displaymanager-password-prompt', no_wait => 1;
            type_password $password. "\n";
        }
        else {
            mouse_hide(1);
            $self->{in_wait_boot} = 0;
            return;
        }
    }

    assert_screen [qw(generic-desktop emergency-shell emergency-mode)], $ready_time + 100;
    handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));
    mouse_hide(1);
    $self->{in_wait_boot} = 0;
}

sub enter_test_text {
    my ($self, $name, %args) = @_;
    $name       //= 'your program';
    $args{cmd}  //= 0;
    $args{slow} //= 0;
    for (1 .. 13) { send_key 'ret' }
    my $text = "If you can see this text $name is working.\n";
    $text = 'echo ' . $text if $args{cmd};
    if ($args{slow}) {
        type_string_slow $text;
    }
    else {
        type_string $text;
    }
}


=head2 firewall

  firewall();

Return the default expected firewall implementation depending on the product
under test, the version and if the SUT is an upgrade.

=cut
sub firewall {
    my $old_product_versions = is_sle('<15') || is_leap('<15.0');
    my $upgrade_from_susefirewall = is_upgrade && get_var('HDD_1') =~ /\b(1[123]|42)[\.-]/;
    return ($old_product_versions || $upgrade_from_susefirewall) ? 'SuSEfirewall2' : 'firewalld';
}

=head2 remount_tmp_if_ro

    remount_tmp_if_ro()

Mounts /tmp to shared memory if not possible to write to tmp.
For example, save_y2logs creates temporary files there.

=cut
sub remount_tmp_if_ro {
    script_run 'touch /tmp/test_ro || mount -t tmpfs /dev/shm /tmp';
}

=head2 select_serial_terminal

    select_serial_terminal($root);

Select most suitable text console with root user. The choice is made by
BACKEND and other variables.

Optional C<root> parameter specifies, whether use root user (C<root>=1, also
default when parameter not specified) or prefer non-root user if available.
=cut
sub select_serial_terminal {
    my ($self, $root) = @_;
    $root //= 1;

    my $backend = get_required_var('BACKEND');
    my $console;

    if ($backend eq 'qemu') {
        if (check_var('VIRTIO_CONSOLE', 0)) {
            $console = $root ? 'root-console' : 'user-console';
        } else {
            $console = $root ? 'root-virtio-terminal' : 'virtio-terminal';
        }
    } elsif (get_var('S390_ZKVM')) {
        $console = $root ? 'root-console' : 'user-console';
    } elsif ($backend eq 'svirt') {
        $console = $root ? 'root-console' : 'user-console';
    } elsif ($backend =~ /^(ikvm|ipmi|spvm)$/) {
        $console = 'root-ssh';
    }

    die "No support for backend '$backend', add it" if ($console eq '');
    select_console($console);
}

=head2 select_user_serial_terminal

    select_user_serial_terminal();

Select most suitable text console with non-root user.
The choice is made by BACKEND and other variables.
=cut
sub select_user_serial_terminal {
    select_serial_terminal(0);
}

# useful post_fail_hook for any module that calls wait_boot and x11_start_program
##
## we could use the same approach in all cases of boot/reboot/shutdown in case
## of wait_boot, e.g. see `git grep -l reboot | xargs grep -L wait_boot`
sub post_fail_hook {
    my ($self) = @_;
    return if testapi::is_serial_terminal();    # unless VIRTIO_CONSOLE=0 nothing below make sense

    show_tasks_in_blocked_state;

    # just output error if selected program doesn't exist instead of collecting all logs
    # set current variables in x11_start_program
    if (get_var('IN_X11_START_PROGRAM')) {
        my $program = get_var('IN_X11_START_PROGRAM');
        select_console 'log-console';
        my $r = script_run "which $program";
        if ($r != 0) {
            record_info("no $program", "Could not find '$program' on the system", result => 'fail') && die "$program does not exist on the system";
        }
    }

    if ($self->{in_wait_boot}) {
        record_info('shutdown', 'At least we reached target Shutdown') if (wait_serial 'Reached target Shutdown');
    }
    elsif ($self->{in_boot_desktop}) {
        record_info('Startup', 'At least Startup is finished.') if (wait_serial 'Startup finished');
    }
    # In case the system is stuck in shutting down or during boot up, press
    # 'esc' just in case the plymouth splash screen is shown and we can not
    # see any interesting console logs.
    send_key 'esc';
    save_screenshot;
}

1;
