# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

package opensusebasetest;
use base 'basetest';

use bootloader_setup qw(boot_grub_item boot_local_disk stop_grub_timeout tianocore_enter_menu zkvm_add_disk zkvm_add_pty zkvm_add_interface tianocore_disable_secureboot tianocore_select_bootloader);
use testapi qw(is_serial_terminal :DEFAULT);
use strict;
use warnings;
use utils;
use Utils::Backends;
use Utils::Systemd;
use Utils::Architectures;
use lockapi 'mutex_wait';
use serial_terminal 'get_login_message';
use version_utils;
use main_common 'opensuse_welcome_applicable';
use isotovideo;
use IO::Socket::INET;
use x11utils qw(handle_login ensure_unlocked_desktop handle_additional_polkit_windows);
use publiccloud::ssh_interactive 'select_host_console';
use Utils::Logging qw(save_and_upload_log tar_and_upload_log export_healthcheck_basic select_log_console upload_coredumps export_logs);
use serial_terminal 'select_serial_terminal';

# Base class for all openSUSE tests

sub grub_select;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    $self->{in_wait_boot} = 0;
    $self->{in_boot_desktop} = 0;
    return $self;
}

=head2 clear_and_verify_console

 clear_and_verify_console();

Clear the console and ensure that it really got cleared
using a needle.

=cut

sub clear_and_verify_console {
    my ($self) = @_;

    clear_console;
    assert_screen('cleared-console') unless is_serial_terminal();
}

=head2 pre_run_hook

 pre_run_hook();

This method will be called before each module is executed.
Test modules (or their intermediate base classes) may overwrite
this method, must call this baseclass method from the overwriting method.

=cut

sub pre_run_hook {
    my ($self) = @_;
    clear_started_systemd_services();
}

=head2 post_run_hook

 post_run_hook();

This method will be called after each module finished.
It will B<not> get executed when the test module failed.
Test modules (or their intermediate base classes) may overwrite
this method.

=cut

sub post_run_hook {
    my ($self) = @_;
    # overloaded in x11 and console
}

=head2 investigate_yast2_failure

 investigate_yast2_failure(logs_path => $logs_path);

Inspect the YaST2 logfile checking for known issues. logs_path can be a directory where logs are saved
e.g. /tmp. In that case the function will parse /tmp/var/log/YaST2/y2logs* files.

=cut

sub investigate_yast2_failure {
    my ($self, %args) = @_;
    my $logs_path = $args{logs_path} . '/var/log/YaST2';
    record_info("logs path", "Parsing longs in $logs_path");
    my $error_detected;
    # first check if badlist exists which could be the most likely problem
    if (my $badlist = script_output "test -f $logs_path/badlist && cat $logs_path/badlist | tail -n 20 || true") {
        record_info 'Likely error detected: badlist', "badlist content:\n\n$badlist", result => 'fail';
        $error_detected = 1;
    }
    # Hash with critical errors in YaST2 and bug reference if any
    my %y2log_errors = (
        "No textdomain configured" => undef,    # Detecting missing translations
                                                # Detecting specific errors proposed by the YaST dev team
        "nothing provides" => undef,    # Detecting missing required packages
        "but this requirement cannot be provided" => undef,    # Detecting package conflicts
        "Could not load icon|Couldn't load pixmap" => undef,    # Detecting missing icons
        "Internal error. Please report a bug report" => undef,    # Detecting internal errors
        "error.*@.*is not allowed" => undef,    # Detecting incompatible type classes, see bsc#1158589
    );
    # Hash with known errors which we don't want to track in each postfail hook
    my %y2log_known_errors = (
        "<3>.*QueryWidget failed.*RichText.*VScrollValue" => 'bsc#1167248',
        "<3>.*Solverrun finished with an ERROR" => 'bsc#1170322',
        "<3>.*3 packages failed.*badlist" => 'bsc#1170322',
        "<3>.*Unknown option.*MultiSelectionBox widget" => 'bsc#1170431',
        "<3>.*XML.*Argument.*to Read.*is nil" => 'bsc#1170432',
        "<3>.*no[t]? mount" => 'bsc#1092088',    # Detect not mounted partition
        "<3>.*lib/cheetah.rb" => 'bsc#1153749',
        "<3>.*Invalid path .value." => 'bsc#1180208',
        # The error below will be cleaned up, see https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup
        # Adding reference to trello, detect those in single scenario
        # (build97.1) regressions
        # found https://openqa.suse.de/tests/3646274#step/logs_from_installation_system/412
        "<3>.*SCR::Dir\\(\\) failed" => 'bsc#1158186',
        "<3>.*Unknown desktop file: installation" => 'bsc#1158186',
        "<3>.*Bad options for module: virtio_net" => 'bsc#1158186',
        "<3>.*Wrong value for path ." => 'bsc#1158186',
        "<3>.*setOptions:Empty map" => 'bsc#1158186',
        "<3>.*Unmounting media failed" => 'bsc#1158186',
        "<3>.*No base product has been found" => 'bsc#1158186',
        "<3>.*Error output: dracut:" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Reading install.inf" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*shellcommand" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*libstorage.*device not found" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*lib/cheetah.rb.*Error output" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Slides.rb.*Directory.*does not exist" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*agent-ini.*(Can not open|Unable to stat)" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Interpreter.*File not found" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Interpreter.*Couldn't find an agent" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Interpreter.*Read.*failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*ag_uid.*argument is not a path" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*ag_uid.*wrong command" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Interpreter.*'Syslog' failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*libycp.*No matching component found" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Perl.*Perl call of Log" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Y2Ruby.*SSHAuthorizedKeys.write_keys failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Directory.* does not exist" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Cannot find the installed base product" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Can not open" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*File not found" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Created symlink" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Unable to stat" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*cannot access" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*hostname: Temporary failure in name resolution" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*hostname: Name or service not known" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Couldn't find an agent to handle" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Read.*failed:" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*SCR::Read" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Failed to get unit file state for" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Running in chroot, ignoring request" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*The first argument is not a path" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*wrong command (SetRoot), only Read is accepted" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Loading module.*failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*No matching component found" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*for a Perl call of Log" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*SSHAuthorizedKeys.write_keys failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*warning: Discarding improperly nested partition" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*device not found, name" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Wrong source ID" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Argument.*nil.*to Write.*is nil" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*UI::ChangeWidget failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Error on key label of widget" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*inhibit udisks failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Command not found" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*converting.*to enum failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*No release notes URL for" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*btrfs subvolume not found" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Widget id.*is not unique" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*has no item with ID" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Label has no shortcut or more than 1 shortcuts" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*diff failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Failed to stat" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*OPEN_FAILED opening" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*rpmdbInit error" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Bad directive: options" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Failed to initialize database" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "(<3>|<5>).*Rpm Exception" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Cleanup on error" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Can't import namespace 'YaPI::SubscriptionTools'" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Can't find YCP client component wrapper_storage" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*ChangeVolumeProperties device" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*can't find 'keyboard_raw_sles.ycp'" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*error accessing /usr/sbin/xfs_repair" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*home_path in control.xml does not start with /" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*CopyFilesToTemp\\(\\) needs to be called first" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*X11 configuration not written" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Forcing /libQtGui.so.5 open failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*can't find 'consolefonts_sles.ycp'" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Could not import key.*Subprocess failed" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*baseproduct symlink is dangling or missing" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*falling back to @\\{DEFAULT_HOME_PATH\\}" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        # libzypp errors
        "<3>.*The requested URL returned error" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Not adding cache" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Repository not found" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*File.*not found on medium" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Login failed." => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Path.*on medium" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Aborting requested by user" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Exception.cc" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
    );

    my $delimiter = '=========================================';
    # Do not report issues we accepted to detect regressions in all scenarios
    my @detected_errors = ();
    if (get_var('ASSERT_Y2LOGS')) {
        %y2log_errors = (%y2log_errors, %y2log_known_errors);
    } else {
        @detected_errors = (keys %y2log_known_errors);
    }
    # Test if zgrep is available
    my $is_zgrep_available = (script_run('type zgrep') == 0);
    my $cmd_prefix = ($is_zgrep_available ? 'zgrep' : 'grep');
    # If zgrep is available, using wildcard to search in rolled archives,
    # And only in y2log in case of grep
    my $cmd_postfix = $logs_path . "/" . ($is_zgrep_available ? 'y2log*' : 'y2log') . ' || true';
    # String to accumulate unknown detected issues
    my $detected_errors_detailed = '';
    for my $y2log_error (keys %y2log_errors) {
        if (my $y2log_error_result = script_output("$cmd_prefix -m 20 -C 5 -E \"$y2log_error\" $cmd_postfix")) {
            # Save detected error to indetify if have new regressions
            push @detected_errors, $y2log_error;
            if (my $bug = $y2log_errors{$y2log_error}) {
                record_info('Softfail', "$bug\n\nDetails:\n$y2log_error_result", result => 'softfail');
                next;
            }
            $detected_errors_detailed .= "$y2log_error_result\n\n$delimiter\n\n";
        }
    }
    ## Check generic errors and exclude already detected issues
    if (my $y2log_error_result = script_output("$cmd_prefix -E \"<3>|<5>\" $cmd_postfix")) {
        # remove known errors from the log
        for my $known_error (@detected_errors) {
            $y2log_error_result =~ s/.*${known_error}.*//g;
        }
        # remove empty lines
        $y2log_error_result =~ s/\n+/\n/gs;
        $detected_errors_detailed .= "$y2log_error_result\n" if $y2log_error_result !~ m/^(\n|\s)*$/;
    }

    # Send last lines to serial to copy in case of new critical bugs
    # If yast log file exists
    if (script_run("test -e $logs_path/y2log") == 0) {
        enter_cmd "echo $delimiter > /dev/$serialdev";
        enter_cmd "echo 'YaST LOGS' > /dev/$serialdev";
        enter_cmd "tail -n 150 $logs_path/y2log > /dev/$serialdev";
        enter_cmd "echo $delimiter > /dev/$serialdev";
    }
    if ($detected_errors_detailed) {
        record_info(
            'YaST2 log errors',
            "Please, file a bug(s) with expected error. Details:\n\n$detected_errors_detailed",
            result => 'fail'
        );

        if (get_var('ASSERT_Y2LOGS')) {
            die "YaST2 error(s) detected. Please, check details";
        }
    }
}

=head2 export_logs_locale

 export_logs_locale();

Upload logs related to system locale settings.
This includes C<locale>, C<localectl> and C</etc/vconsole.conf>.

=cut

sub export_logs_locale {
    my ($self) = shift;
    save_and_upload_log('locale', '/tmp/locale.log');
    save_and_upload_log('localectl status', '/tmp/localectl.log');
    save_and_upload_log('cat /etc/vconsole.conf', '/tmp/vconsole.conf');
}

=head2 upload_packagekit_logs

 upload_packagekit_logs();

Upload C</var/log/pk_backend_zypp>.

=cut

sub upload_packagekit_logs {
    my ($self) = @_;
    upload_logs '/var/log/pk_backend_zypp';
}

=head2 set_standard_prompt

 set_standard_prompt();

Set a simple reproducible prompt for easier needle matching without hostname.

=cut

sub set_standard_prompt {
    my ($self, $user) = @_;
    $testapi::distri->set_standard_prompt($user);
}

=head2 handle_uefi_boot_disk_workaround

 handle_uefi_boot_disk_workaround();

Our aarch64 setup fails to boot properly from an installed hard disk so
point the firmware boot manager to the right file.

=cut

sub handle_uefi_boot_disk_workaround {
    my ($self) = @_;
    record_info 'workaround', 'Manually selecting boot entry, see bsc#1022064 for details';
    tianocore_enter_menu;
    send_key_until_needlematch 'tianocore-boot_maintenance_manager', 'down', 6, 5;
    wait_screen_change { send_key 'ret' };
    send_key_until_needlematch 'tianocore-boot_from_file', 'down';
    wait_screen_change { send_key 'ret' };
    # Device selection: HD or CDROM
    send_key_until_needlematch 'tianocore-select_HD', 'down';
    wait_screen_change { send_key 'ret' };
    # cycle to last entry by going up in the next steps
    # <EFI>
    send_key 'up';
    save_screenshot;
    wait_screen_change { send_key 'ret' };
    # <sles> or <opensuse>
    send_key_until_needlematch [qw(tianocore-select_opensuse_or_sles tianocore-select_boot)], 'up';
    save_screenshot;
    wait_screen_change { send_key 'ret' };
    # efi file, first check shim.efi exist or not
    my $counter = 10;
    my $shim_efi_found = 1;
    while (!check_screen('tianocore-select_shim_efi', 2)) {
        wait_screen_change {
            send_key 'up';
        };
        if (!$counter--) {
            $shim_efi_found = 0;
            last;
        }
    }
    if ($shim_efi_found == 1) {
        wait_screen_change { send_key 'ret' };
    } else {
        send_key_until_needlematch [qw(tianocore-select_grubaa64_efi tianocore-select_bootaa64_efi)], 'up';
        wait_screen_change { send_key 'ret' };
    }
}

=head2 wait_grub

 wait_grub([bootloader_time => $bootloader_time] [,in_grub => $in_grub]);

Makes sure the bootloader appears. Returns successfully when reached the bootloader menu, ready to control it further or continue. The time waiting for the bootloader can be configured with
C<$bootloader_time> in seconds. Set C<$in_grub> to 1 when the
SUT is already expected to be within the grub menu.
=cut

sub wait_grub {
    my ($self, %args) = @_;
    my $bootloader_time = $args{bootloader_time} // 100;
    my $in_grub = $args{in_grub} // 0;
    my @tags;
    push @tags, 'bootloader-shim-import-prompt' if get_var('UEFI');
    push @tags, 'grub2';
    push @tags, 'boot-live-' . get_var('DESKTOP') if get_var('LIVETEST');    # LIVETEST won't to do installation and no grub2 menu show up
    push @tags, 'bootloader' if get_var('OFW');
    push @tags, 'encrypted-disk-password-prompt-grub' if get_var('ENCRYPT');
    if (get_var('ONLINE_MIGRATION')) {
        push @tags, 'migration-source-system-grub2';
    }
    # if there was a request to enroll or remove a certificate used for SecureBoot process
    if (get_var('_EXPECT_EFI_MOK_MANAGER')) {
        if (is_hyperv) {
            assert_screen 'shim-key-management';
        } else {
            wait_serial('Shim UEFI key management', 60) or die 'MokManager has not been started!';
        }
        send_key 'ret';
        assert_screen 'shim-perform-mok-management';
        send_key 'down';
        assert_screen([qw(shim-enroll-mok shim-delete-mok)]);
        send_key 'ret';
        assert_screen 'shim-view-key';
        send_key 'ret';
        assert_screen 'shim-imported-mock-cert';
        send_key 'ret';
        assert_screen 'shim-view-key';
        send_key 'down';
        assert_screen 'shim-enroll-mok-continue';
        send_key 'ret';
        assert_screen 'shim-keys-confirm-dialog';
        send_key 'down';
        assert_screen 'shim-keys-confirm-yes';
        send_key 'ret';
        assert_screen 'shim-mok-password';
        type_password;
        send_key 'ret';
        assert_screen 'shim-perform-mok-reboot';
        send_key 'ret';
    }
    # after gh#os-autoinst/os-autoinst#641 68c815a "use bootindex for boot
    # order on UEFI" the USB install medium is priority and will always be
    # booted so we have to handle that
    # because of broken firmware, bootindex doesn't work on aarch64 bsc#1022064
    push @tags, 'inst-bootmenu'
      if (get_var('USBBOOT') && get_var('UEFI')
        || (is_aarch64 && get_var('UEFI'))
        || get_var('OFW')
        || (check_var('BOOTFROM', 'd')));
    # Enable all migration path on aarch64
    # Refer to ticket: https://progress.opensuse.org/issues/49340
    $self->handle_uefi_boot_disk_workaround
      if (is_aarch64_uefi_boot_hdd
        && !is_jeos
        && !$in_grub
        && (!(isotovideo::get_version() >= 12 && get_var('UEFI_PFLASH_VARS')) || get_var('ONLINE_MIGRATION') || get_var('UPGRADE') || get_var('ZDUP')));
    assert_screen(\@tags, $bootloader_time);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
        if (is_upgrade && check_var('BOOTFROM', 'd')) {
            assert_screen 'inst-bootmenu';
            # Select boot from HDD
            send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
            send_key 'ret';
        }
        assert_screen "grub2", 15;
    }
    elsif (get_var("LIVETEST")) {
        # prevent if one day booting livesystem is not the first entry of the boot list
        if (!match_has_tag("boot-live-" . get_var("DESKTOP"))) {
            send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 11, 5);
        }
    }
    elsif (match_has_tag('inst-bootmenu')) {
        $self->wait_grub_to_boot_on_local_disk;
    }
    elsif (match_has_tag('encrypted-disk-password-prompt-grub')) {
        # unlock encrypted disk before grub
        workaround_type_encrypted_passphrase;
        assert_screen("grub2", timeout => ((is_pvm) ? 300 : 90));
    }
    mutex_wait 'support_server_ready' if get_var('USE_SUPPORT_SERVER');
}

=head2 wait_grub_to_boot_on_local_disk

 wait_grub_to_boot_on_local_disk

When bootloader appears, make sure to boot from local disk when it is on aarch64.
=cut

sub wait_grub_to_boot_on_local_disk {
    # assuming the cursor is on 'installation' by default and 'boot from
    # harddisk' is above
    send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
    boot_local_disk;
    my @tags = qw(grub2 tianocore-mainmenu);
    push @tags, 'encrypted-disk-password-prompt' if (get_var('ENCRYPT'));

    # Workaround for poo#118336
    if (is_ppc64le && is_qemu) {
        push @tags, 'linux-login' if check_var('DESKTOP', 'textmode');
        push @tags, 'displaymanager' if check_var('DESKTOP', 'gnome');
    }

    # Enable boot menu for x86_64 uefi workaround, see bsc#1180080 for details
    if (is_sle && get_required_var('FLAVOR') =~ /Migration/ && is_x86_64 && get_var('UEFI')) {
        if (!check_screen(\@tags, 15)) {
            record_soft_failure 'bsc#1180080';
            wait_screen_change { send_key 'e' };
            wait_screen_change { send_key 'f2' };
            type_string "exit";
            wait_screen_change { send_key 'ret' };
            tianocore_select_bootloader;
            send_key_until_needlematch("ovmf-boot-HDD", 'down', 6, 1);
            send_key "ret";
            return;
        }
    }

    # We need to wait more for aarch64's tianocore-mainmenu and for qemu ppc64le
    if ((is_aarch64) || (is_ppc64le && is_qemu)) {
        assert_screen(\@tags, 30);
    } else {
        assert_screen(\@tags, 15);
    }
    if (match_has_tag('tianocore-mainmenu')) {
        opensusebasetest::handle_uefi_boot_disk_workaround();
        check_screen('encrypted-disk-password-prompt', 10);
    }
    if (match_has_tag('encrypted-disk-password-prompt')) {
        workaround_type_encrypted_passphrase;
        assert_screen('grub2');
    }
}

sub reconnect_s390 {
    my (%args) = @_;
    my $ready_time = $args{ready_time};
    my $textmode = $args{textmode};
    return undef unless is_s390x;
    my $login_ready = get_login_message();
    if (is_backend_s390x) {
        my $console = console('x3270');
        # skip grub handle for 11sp4
        if (!is_sle('=11-SP4')) {
            handle_grub_zvm($console);
        }
        $console->expect_3270(
            output_delim => $login_ready,
            timeout => $ready_time + 100
        );

        # give the system time to have routes up
        # and start serial grab again
        sleep 30;
        select_console('iucvconn');
    }
    else {
        my $worker_hostname = get_required_var('WORKER_HOSTNAME');
        my $virsh_guest = get_required_var('VIRSH_GUEST');
        workaround_type_encrypted_passphrase if get_var('S390_ZKVM');

        select_console('svirt');
        save_svirt_pty;

        wait_serial('GNU GRUB|Welcome to GRUB!', 180) || diag 'Could not find GRUB screen, continuing nevertheless, trying to boot';
        grub_select;

        type_line_svirt '', expect => $login_ready, timeout => $ready_time + 100, fail_message => 'Could not find login prompt';
        type_line_svirt "root", expect => 'Password';
        type_line_svirt "$testapi::password";
        type_line_svirt "systemctl is-active network", expect => 'active';
        type_line_svirt 'systemctl is-active sshd', expect => 'active';

        # make sure we can reach the SSH server in the SUT, try up to 1 min (12 * 5s)
        my $retries = 12;
        my $port = 22;
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
    return 1;
}

# On Xen we have to re-connect to serial line as Xen closed it after restart
sub reconnect_xen {
    return unless check_var('VIRSH_VMM_FAMILY', 'xen');
    wait_serial("reboot: (Restarting system|System halted)") if check_var('VIRSH_VMM_TYPE', 'linux');
    console('svirt')->attach_to_running;
    select_console('sut');
}

sub handle_emergency_if_needed {
    handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));
}

sub handle_displaymanager_login {
    my ($self, %args) = @_;
    assert_screen [qw(displaymanager emergency-shell emergency-mode)], $args{ready_time};
    handle_emergency_if_needed;
    handle_login unless $args{nologin};
}

=head2 handle_pxeboot

 handle_pxeboot(bootloader_time => $bootloader_time, pxemenu => $pxemenu, pxeselect => $pxeselect);

Handle a textmode PXE bootloader menu by means of two needle tags:
C<$pxemenu> to match the initial menu, C<$pxeselect> to match the
menu with the desired entry selected.
=cut

sub handle_pxeboot {
    my ($self, %args) = @_;
    my $bootloader_time = $args{bootloader_time};

    assert_screen($args{pxemenu}, $bootloader_time);
    unless (match_has_tag($args{pxeselect})) {
        send_key_until_needlematch($args{pxeselect}, 'down');
    }
    send_key 'ret';
}

sub grub_select {
    if ((my $grub_nondefault = get_var('GRUB_BOOT_NONDEFAULT', 0)) gt 0) {
        my $menu = $grub_nondefault * 2 + 1;
        bmwqemu::fctinfo("Boot non-default grub option $grub_nondefault (menu item $menu)");
        boot_grub_item($menu);
    } elsif (my $first_menu = get_var('GRUB_SELECT_FIRST_MENU')) {
        if (my $second_menu = get_var('GRUB_SELECT_SECOND_MENU')) {
            bmwqemu::fctinfo("Boot $first_menu > $second_menu");
            boot_grub_item($first_menu, $second_menu);
        } else {
            bmwqemu::fctinfo("Boot $first_menu");
            boot_grub_item($first_menu);
        }
    }
    elsif (is_ppc64le && is_qemu) {
        my @tags = qw(grub2);

        # Workaround for poo#118336
        push @tags, 'linux-login' if check_var('DESKTOP', 'textmode');
        push @tags, 'displaymanager' if check_var('DESKTOP', 'gnome');

        assert_screen(\@tags);

        if (match_has_tag 'grub2') {
            send_key 'ret';
        }
    }
    elsif (!get_var('S390_ZKVM')) {
        # confirm default choice
        send_key 'ret';
        if (get_var('USE_SUPPORT_SERVER') && is_aarch64 && is_opensuse)
        {
            # On remote installations of openSUSE distris on aarch64, first key
            # press doesn't always reach the SUT, so introducing the workaround
            wait_still_screen;
            if (check_screen('grub2')) {
                record_info 'WARN', 'Return key did not reach the system, re-trying';
                send_key 'ret';
            }
        }
    }
}

sub handle_grub {
    my ($self, %args) = @_;
    my $bootloader_time = $args{bootloader_time};
    my $in_grub = $args{in_grub};
    my $linux_boot_entry = $args{linux_boot_entry} // (is_sle('15+') ? 15 : 14);
    $linux_boot_entry = $linux_boot_entry - 1 if is_aarch64;    # poo#100500

    # On Xen PV and svirt we don't see a Grub menu
    # If KEEP_GRUB_TIMEOUT is defined it means that GRUB menu will appear only for one second
    return if (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux') && is_svirt || check_var('KEEP_GRUB_TIMEOUT', '1'));
    $self->wait_grub(bootloader_time => $bootloader_time, in_grub => $in_grub);
    if (my $boot_params = get_var('EXTRABOOTPARAMS_BOOT_LOCAL')) {
        wait_screen_change { send_key 'e' };
        for (1 .. $linux_boot_entry) { send_key 'down' }
        wait_screen_change { send_key 'end' };
        send_key_until_needlematch(get_var('EXTRABOOTPARAMS_DELETE_NEEDLE_TARGET'), 'left', 1000) if get_var('EXTRABOOTPARAMS_DELETE_NEEDLE_TARGET');
        for (1 .. get_var('EXTRABOOTPARAMS_DELETE_CHARACTERS', 0)) { send_key 'backspace' }
        bmwqemu::fctinfo("Adding boot params '$boot_params'");
        type_string_very_slow " $boot_params ";
        save_screenshot;
        send_key 'ctrl-x';
    }
    else {
        grub_select;
    }
}

sub wait_boot_textmode {
    my ($self, %args) = @_;
    # For s390x we validate system boot in reconnect_mgmt_console test module
    # and use ssh connection to operate on the SUT, so do early return
    return if is_s390x;

    my $ready_time = $args{ready_time};
    my $textmode_needles = [qw(linux-login emergency-shell emergency-mode)];
    # 2nd stage of autoyast can be considered as linux-login
    push @{$textmode_needles}, 'autoyast-init-second-stage' if get_var('AUTOYAST');
    # Soft-fail for user_defined_snapshot in extra_tests_on_gnome and extra_tests_on_gnome_on_ppc
    # if not able to boot from snapshot
    if (get_var('EXTRATEST', '') !~ /desktop/) {
        assert_screen $textmode_needles, $ready_time;
    }
    elsif (is_sle('<15') && !check_screen $textmode_needles, $ready_time / 2) {
        # We are not able to boot due to bsc#980337
        record_soft_failure 'bsc#980337';
        # Switch to root console and continue
        select_console 'root-console';
    }
    elsif (check_screen 'displaymanager', 90) {
        # due to workaround on sle15+ is test user_defined_snapshot expecting to boot textmode despite snapshot booted properly
        select_console 'root-console';
    }

    handle_emergency_if_needed;

    reset_consoles;
    $self->{in_wait_boot} = 0;
    return;

}

sub handle_broken_autologin_boo1102563 {
    record_soft_failure 'boo#1102563 - GNOME autologin broken. Handle login and disable Wayland for login page to make it work next time';
    handle_login;
    assert_screen 'generic-desktop';
    # Force the login screen to use Xorg to get autologin working
    # (needed for additional tests using boot_to_desktop)
    x11_start_program('xterm');
    wait_still_screen;
    script_sudo('sed -i s/#WaylandEnable=false/WaylandEnable=false/ /etc/gdm/custom.conf');
    wait_screen_change { send_key 'alt-f4' };
}

=head2 wait_boot_past_bootloader

 wait_boot_past_bootloader([, textmode => $textmode] [,ready_time => $ready_time] [, nologin => $nologin] [, forcenologin => $forcenologin]);

Waits until the system is booted, every step after the bootloader or
bootloader menu. Returns successfully when the system is ready on a login
prompt or logged in desktop. Set C<$textmode> to 1 when the text mode login
prompt should be expected rather than a desktop or display manager.  Expects
already unlocked encrypted disks, see C<wait_boot> for handling these in
before.  The time waiting for the system to be fully booted can be configured
with C<$ready_time> in seconds. C<$forcenologin> makes this function
behave as if the env var NOAUTOLOGIN was set.
=cut

sub wait_boot_past_bootloader {
    my ($self, %args) = @_;
    my $textmode = $args{textmode};
    my $ready_time = $args{ready_time} // 500;
    my $nologin = $args{nologin};
    my $forcenologin = $args{forcenologin};

    # Workaround for bsc#1204221, bsc#1204230 and bsc#1203641
    if (is_sle('=15-SP5') && check_var('VIRSH_VMM_FAMILY', 'hyperv') && check_var('HYPERV_VERSION', '2019') && check_var('FLAVOR', 'Online')) {
        # This should only happen on SLE15SP5 and on hyperv 2019
        # This is for legacy workaround.
        if (!get_var('UEFI')) {
            record_soft_failure 'workaround bsc#1204221 - Failed to boot at SLES15SP5 with gnome in hyperv 2019' if check_var('DESKTOP', 'gnome');
            record_soft_failure 'workaround bsc#1204230 - Failed to boot at SLES15SP5 with x server in hyperv 2019' if check_var('DESKTOP', 'textmode');
            sleep 30;
            send_key 'esc';
        }
        # This is for UEFI workaround.
        else {
            record_soft_failure 'workaround bsc#1203641 - Failed to boot after installation on hyperv-2019 UEFI setup' if check_var('DESKTOP', 'gnome');
            sleep 30;
            send_key 'esc';
        }
    }

    # On IPMI, when selecting x11 console, we are connecting to the VNC server on the SUT.
    # select_console('x11'); also performs a login, so we should be at generic-desktop.
    my $gnome_ipmi = (is_ipmi && check_var('DESKTOP', 'gnome'));
    if ($gnome_ipmi) {
        # first boot takes sometimes quite long time, ensure that it reaches login prompt
        $self->wait_boot_textmode(ready_time => $ready_time);
        select_console('x11');
    }
    elsif ($textmode || check_var('DESKTOP', 'textmode')) {
        return $self->wait_boot_textmode(ready_time => $ready_time);
    }

    # On SLES4SAP upgrade tests with desktop, only check for a DM screen with the SAP System
    # Administrator user listed but do not attempt to login
    if (!is_sle('<=11-SP4') && get_var('HDDVERSION') && is_desktop_installed && is_upgrade && is_sles4sap) {
        assert_screen 'displaymanager-sapadm', $ready_time;
        wait_still_screen;    # We need to ensure that we are in a stable state
        return;
    }

    $self->handle_displaymanager_login(ready_time => $ready_time, nologin => $nologin) if (get_var("NOAUTOLOGIN") || get_var("XDMUSED") || $nologin || $forcenologin);
    return if $args{nologin};

    my @tags = qw(generic-desktop emergency-shell emergency-mode);
    push(@tags, 'opensuse-welcome') if opensuse_welcome_applicable;
    push(@tags, 'gnome-activities') if check_var('DESKTOP', 'gnome');

    # boo#1102563 - autologin fails on aarch64 with GNOME on current Tumbleweed
    if (!is_sle('<=15') && !is_leap('<=15.0') && is_aarch64 && check_var('DESKTOP', 'gnome')) {
        push(@tags, 'displaymanager');
        # Workaround for bsc#1169723
        push(@tags, 'guest-disable-display');
    }
    # bsc#1177446 - Polkit popup appears at first login, again
    if (is_sle && !is_sle('<=15-SP1') && is_s390x) {
        push(@tags, 'authentication-required-user-settings');
    }

    # GNOME and KDE get into screenlock after 5 minutes without activities.
    # using multiple check intervals here then we can get the wrong desktop
    # screenshot at least in case desktop screenshot changed, otherwise we get
    # the screenlock screenshot.
    my $timeout = $ready_time;
    my $check_interval = 30;
    while ($timeout > $check_interval) {
        my $ret = check_screen \@tags, $check_interval;
        last if $ret;
        $timeout -= $check_interval;
    }
    # Starting with GNOME 40, upon login, the activities screen is open (assuming the
    # user will want to start something. For openQA, we simply press 'esc' to close
    # it again and really end up on the desktop
    if (match_has_tag('gnome-activities')) {
        send_key 'esc';
        @tags = grep { !/gnome-activities/ } @tags;
    }
    # if we reached a logged in desktop we are done here
    return 1 if match_has_tag('generic-desktop') || match_has_tag('opensuse-welcome');
    # the last check after previous intervals must be fatal
    assert_screen \@tags, $check_interval;
    handle_emergency_if_needed;

    handle_broken_autologin_boo1102563() if match_has_tag('displaymanager');
    handle_additional_polkit_windows if match_has_tag('authentication-required-user-settings');
    if (match_has_tag('guest-disable-display')) {
        record_soft_failure 'bsc#1169723 - [Build 174.1] openQA test fails in first_boot - Guest disabled display shown when boot up after migration';
        send_key 'ret';
    }
    mouse_hide(1);
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
    my $bootloader_time = $args{bootloader_time} // ((is_pvm || is_ipmi) ? 300 : 100);
    my $textmode = $args{textmode};
    my $ready_time = $args{ready_time} // ((check_var('VIRSH_VMM_FAMILY', 'hyperv') || is_ipmi) ? 500 : 300);
    my $in_grub = $args{in_grub} // 0;

    die "wait_boot: got undefined class" unless $self;
    # used to register a post fail hook being active while we are waiting for
    # boot to be finished to help investigate in case the system is stuck in
    # shutting down or booting up
    $self->{in_wait_boot} = 1;

    # for powerVM, it need switch console, it need wait longer time to
    # get grub page. After we get grub page, the workflow will be same
    # as others
    $self->wait_grub(bootloader_time => $bootloader_time) if is_pvm;

    # Reset the consoles after the reboot: there is no user logged in anywhere
    reset_consoles;
    select_console('sol', await_console => 0) if is_ipmi;
    if (reconnect_s390(textmode => $textmode, ready_time => $ready_time)) {
    }
    elsif (get_var('USE_SUPPORT_SERVER') && get_var('USE_SUPPORT_SERVER_PXE_CUSTOMKERNEL')) {
        # A supportserver client to reboot via PXE after an initial installation.
        # No GRUB menu. Instead, the mandatory parallel supportserver job is
        # supposedly ready to provide the desired customized PXE boot menu.

        # Expected: three menu entries, one of them being "Custom kernel"
        # (the boot configuration from the just-finished initial installation)
        #
        $self->handle_pxeboot(bootloader_time => $bootloader_time, pxemenu => 'pxe-custom-kernel', pxeselect => 'pxe-custom-kernel-selected');
    }
    else {
        assert_screen([qw(virttest-pxe-menu qa-net-selection prague-pxe-menu pxe-menu)], 600) if (uses_qa_net_hardware() || get_var("PXEBOOT"));
        $self->handle_grub(bootloader_time => $bootloader_time, in_grub => $in_grub);
        # part of soft failure bsc#1118456
        if (get_var('UEFI') && is_hyperv) {
            wait_still_screen stilltime => 5, timeout => 26;
            save_screenshot;
            if (check_screen('grub2', 20)) {
                record_soft_failure 'bsc#1118456 - Booting reset on Hyper-V (UEFI)';
                send_key 'ret';
            }
        }
    }
    reconnect_xen if check_var('VIRSH_VMM_FAMILY', 'xen');

    # on s390x svirt encryption is unlocked with workaround_type_encrypted_passphrase before here
    unlock_if_encrypted unless get_var('S390_ZKVM');

    $self->wait_boot_past_bootloader(%args);
    $self->{in_wait_boot} = 0;
}

=head2 enter_test_text

 enter_test_text($name [, cmd => $cmd] [, slow => $slow]);

For testing a text editor or terminal emulator.
This will type some newlines and then enter the following text:

 If you can see this text $name is working.

C<$name> will default to "I<your program>".
If C<$slow> is set, the typing will be very slow.
If C<$cmd> is set, the text will be prefixed by an C<echo> command.

=cut

sub enter_test_text {
    my ($self, $name, %args) = @_;
    $name //= 'your program';
    $args{cmd} //= 0;
    $args{slow} //= 0;
    for (1 .. 13) { send_key 'ret' }
    my $text = "If you can see this text $name is working.\n";
    $text = 'echo ' . $text if $args{cmd};
    if ($args{slow}) {
        type_string_very_slow $text;
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
    return (($old_product_versions || $upgrade_from_susefirewall) && !is_tumbleweed && !(check_var('SUSEFIREWALL2_SERVICE_CHECK', 1))) ? 'SuSEfirewall2' : 'firewalld';
}

=head2 post_fail_hook

 post_fail_hook();

When the test module fails, this method will be called.
It will try to fetch some logs from the SUT.
Test modules (or their intermediate base classes) may overwrite
this method to export certain specific logfiles and call the
base method using C<$self-E<gt>SUPER::post_fail_hook;> at the end.

=cut

sub post_fail_hook {
    my ($self) = @_;

    return if (get_var('NOLOGS'));

    # Upload basic health check log
    select_serial_terminal();
    export_healthcheck_basic;

    # set by x11_start_program
    if (get_var('IN_X11_START_PROGRAM')) {
        my ($program) = get_var('IN_X11_START_PROGRAM') =~ m/(\S+)/;
        set_var('IN_X11_START_PROGRAM', undef);

        my $r = script_run "which $program";
        if ($r != 0) {
            record_info("no $program", "Could not find '$program' on the system", result => 'fail');
        }
    }

    if (get_var('FULL_LVM_ENCRYPT') && get_var('LVM_THIN_LV')) {
        my $lvmdump_regex = qr{/root/lvmdump-.*?-\d+\.tgz};
        my $out = script_output('lvmdump', proceed_on_failure => 1);
        if ($out =~ /(?<lvmdump_gzip>$lvmdump_regex)/) {
            upload_logs("$+{lvmdump_gzip}", failok => 1);
        }
        save_and_upload_log('lvm dumpconfig', '/tmp/lvm_dumpconf.out');
    }

    if (get_var('COLLECT_COREDUMPS')) {
        upload_coredumps(proceed_on_failure => 1);
    }

    if ($self->{in_wait_boot}) {
        record_info('shutdown', 'At least we reached target Shutdown') if (wait_serial 'Reached target Shutdown');
    }
    elsif ($self->{in_boot_desktop}) {
        record_info('Startup', 'At least Startup is finished.') if (wait_serial 'Startup finished');
    }
    # Find out in post-fail-hook if system is I/O-busy, poo#35877
    else {
        my $io_status = script_output("sed -n 's/^.*da / /p' /proc/diskstats | cut -d' ' -f10");
        record_info('System I/O status:', ($io_status =~ /^0$/) ? 'idle' : 'busy');
    }

    export_logs;

    if ((is_public_cloud() || is_openstack()) && $self->{run_args}->{my_provider}) {
        select_host_console(force => 1);

        # Destroy the public cloud instance in case of fatal test failure
        my $flags = $self->test_flags();
        $self->{run_args}->{my_provider}->cleanup() if ($flags->{fatal});

        # When tunnel-console is used we upload the log
        my $ssh_sut = '/var/tmp/ssh_sut.log';
        upload_logs($ssh_sut) unless (script_run("test -f $ssh_sut") != 0);
    }
}

sub test_flags {
    # no_rollback is needed for ssh-tunnel and fatal must be explicitly defined
    return get_var('PUBLIC_CLOUD') ? {no_rollback => 1, fatal => 0} : {};
}

1;
