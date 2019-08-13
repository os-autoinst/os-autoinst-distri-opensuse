package opensusebasetest;
use base 'basetest';

use bootloader_setup qw(stop_grub_timeout boot_local_disk tianocore_enter_menu zkvm_add_disk zkvm_add_pty zkvm_add_interface);
use testapi;
use strict;
use warnings;
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

sub tar_and_upload_log {
    my ($self, $sources, $dest, $args) = @_;
    script_run("tar -jcv -f $dest $sources", $args->{timeout});
    upload_logs($dest) unless $args->{noupload};
    save_screenshot() if $args->{screenshot};
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
    # Hash with critical errors in YaST2 and bug reference if any
    my %y2log_errors = (
        "<3>.*Cannot parse the data from server"     => 'bsc#1126045',
        "No textdomain configured"                   => 'bsc#1127756',    # Detecting missing translations
                                                                          # Detecting specifi errors proposed by the YaST dev team
        "nothing provides"                           => undef,            # Detecting missing required packages
        "but this requirement cannot be provided"    => undef,            # Detecting package conflicts
        "Could not load icon|Couldn't load pixmap"   => undef,            # Detecting missing icons
        "Internal error. Please report a bug report" => undef,            # Detecting internal errors
    );
    # Hash with known errors which we don't want to track in each postfail hook
    my %y2log_known_errors = (
        "<3>.*no[t]? mount" => 'bsc#1092088',                             # Detect not mounted partition

        # The error below will be cleaned up, see https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup
        # Adding reference to trello, detect those in single scenario
        "<3>.*Error output: dracut:"                            => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Reading install.inf"                              => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*shellcommand"                                     => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*libstorage.*device not found"                     => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*lib/cheetah.rb.*Error output"                     => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Slides.rb.*Directory.*does not exist"             => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*agent-ini.*(Can not open|Unable to stat)"         => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Interpreter.*File not found"                      => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Interpreter.*Couldn't find an agent"              => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Interpreter.*Read.*failed"                        => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*ag_uid.*argument is not a path"                   => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*ag_uid.*wrong command"                            => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Interpreter.*'Syslog' failed"                     => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*libycp.*No matching component found"              => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Perl.*Perl call of Log"                           => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Y2Ruby.*SSHAuthorizedKeys.write_keys failed"      => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Directory.* does not exist"                       => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Cannot find the installed base product"           => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Can not open"                                     => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*File not found"                                   => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Created symlink"                                  => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Unable to stat"                                   => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*cannot access"                                    => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*hostname: Temporary failure in name resolution"   => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*hostname: Name or service not known"              => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Couldn't find an agent to handle"                 => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Read.*failed:"                                    => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*SCR::Read"                                        => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Failed to get unit file state for"                => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Running in chroot, ignoring request"              => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*The first argument is not a path"                 => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*wrong command (SetRoot), only Read is accepted"   => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Loading module.*failed"                           => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*No matching component found"                      => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*for a Perl call of Log"                           => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*SSHAuthorizedKeys.write_keys failed"              => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*warning: Discarding improperly nested partition"  => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*device not found, name"                           => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Wrong source ID"                                  => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Argument.*nil.*to Write.*is nil"                  => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*UI::ChangeWidget failed"                          => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Error on key label of widget"                     => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*inhibit udisks failed"                            => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Command not found"                                => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*converting.*to enum failed"                       => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*No release notes URL for"                         => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*btrfs subvolume not found"                        => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Widget id.*is not unique"                         => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*has no item with ID"                              => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Label has no shortcut or more than 1 shortcuts"   => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*diff failed"                                      => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Failed to stat"                                   => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Bad directive: options"                           => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*OPEN_FAILED opening"                              => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*rpmdbInit error"                                  => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Failed to initialize database"                    => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "(<3>|<5>).*Rpm Exception"                              => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Cleanup on error"                                 => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Can't import namespace 'YaPI::SubscriptionTools'" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Can't find YCP client component wrapper_storage"  => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*ChangeVolumeProperties device"                    => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*can't find 'keyboard_raw_sles.ycp'"               => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*error accessing /usr/sbin/xfs_repair"             => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*home_path in control.xml does not start with /"   => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*CopyFilesToTemp\\(\\) needs to be called first"   => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*X11 configuration not written"                    => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Forcing /libQtGui.so.5 open failed"               => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*can't find 'consolefonts_sles.ycp'"               => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Could not import key.*Subprocess failed"          => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*baseproduct symlink is dangling or missing"       => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*falling back to @\\{DEFAULT_HOME_PATH\\}"         => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        # libzypp errors
        "<3>.*The requested URL returned error" => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<3>.*Not adding cache"                 => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Repository not found"             => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*File.*not found on medium"        => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Login failed."                    => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Path.*on medium"                  => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Aborting requested by user"       => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
        "<5>.*Exception.cc"                     => 'https://trello.com/c/5qTQZKH3/2918-sp2-logs-cleanup',
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
    my $is_zgrep_available = (script_output('type zgrep') == 0);
    my $cmd_prefix         = ($is_zgrep_available ? 'zgrep' : 'grep');
    # If zgrep is available, using wildcard to search in rolled archives,
    # And only in y2log in case of grep
    my $logs_path   = '/var/log/YaST2/';
    my $cmd_postfix = $logs_path . ($is_zgrep_available ? 'y2log*' : 'y2log') . ' || true';
    # String to accumulate unknown detected issues
    my $detected_errors_detailed = '';
    for my $y2log_error (keys %y2log_errors) {
        if (my $y2log_error_result = script_output("$cmd_prefix -C 5 -E \"$y2log_error\" $cmd_postfix")) {
            # Save detected error to indetify if have new regressions
            push @detected_errors, $y2log_error;
            if (my $bug = $y2log_errors{$y2log_error}) {
                record_soft_failure("$bug\n\nDetails:\n$y2log_error_result");
                next;
            }
            $detected_errors_detailed .= "$y2log_error_result\n\n$delimiter\n\n";
        }
    }
    ## Check generic erros and exclude already detected issues
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
        type_string "echo $delimiter > /dev/$serialdev\n";
        type_string "echo 'YaST LOGS' > /dev/$serialdev\n";
        type_string "tail -n 150 $logs_path/y2log > /dev/$serialdev\n";
        type_string "echo $delimiter > /dev/$serialdev\n";
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

# Logs that make sense for any failure
sub export_logs_basic {
    my ($self) = @_;
    $self->save_and_upload_log('cat /proc/loadavg', '/tmp/loadavg.txt', {screenshot => 1});
    $self->save_and_upload_log('ps axf',            '/tmp/psaxf.log',   {screenshot => 1});
    $self->save_and_upload_log('journalctl -b',     '/tmp/journal.log', {screenshot => 1});
    $self->save_and_upload_log('dmesg',             '/tmp/dmesg.log',   {screenshot => 1});
    $self->tar_and_upload_log('/etc/sysconfig', '/tmp/sysconfig.tar.bz2');
}

sub export_logs {
    my ($self) = shift;
    select_console 'log-console';
    save_screenshot;
    $self->remount_tmp_if_ro;
    $self->problem_detection;

    $self->export_logs_basic;

    # Just after the setup: let's see the network configuration
    $self->save_and_upload_log("ip addr show", "/tmp/ip-addr-show.log");

    save_screenshot;

    $self->export_logs_desktop;

    $self->save_and_upload_log('systemctl list-unit-files', '/tmp/systemctl_unit-files.log');
    $self->save_and_upload_log('systemctl status',          '/tmp/systemctl_status.log');
    $self->save_and_upload_log('systemctl',                 '/tmp/systemctl.log', {screenshot => 1});

    script_run "save_y2logs /tmp/y2logs_clone.tar.bz2";
    upload_logs "/tmp/y2logs_clone.tar.bz2";
    $self->investigate_yast2_failure();
}

sub export_logs_locale {
    my ($self) = shift;
    $self->save_and_upload_log('locale',                 '/tmp/locale.log');
    $self->save_and_upload_log('localectl status',       '/tmp/localectl.log');
    $self->save_and_upload_log('cat /etc/vconsole.conf', '/tmp/vconsole.conf');
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

sub export_logs_desktop {
    my ($self) = @_;
    select_console 'log-console';
    save_screenshot;

    if (check_var("DESKTOP", "kde")) {
        if (get_var('PLASMA5')) {
            $self->tar_and_upload_log("/home/$username/.config/*rc", '/tmp/plasma5_configs.tar.bz2');
        }
        else {
            $self->tar_and_upload_log("/home/$username/.kde4/share/config/*rc", '/tmp/kde4_configs.tar.bz2');
        }
        save_screenshot;
    } elsif (check_var("DESKTOP", "gnome")) {
        $self->tar_and_upload_log('/home/bernhard/.cache/gdm', '/tmp/gdm.tar.bz2');
    }

    # check whether xorg logs exist in user's home, if yes, upload xorg logs
    # from user's home instead of /var/log
    my $log_path = '/home/*/.local/share/xorg/';
    if (!script_run("test -d $log_path")) {
        $self->tar_and_upload_log("$log_path", '/tmp/Xlogs.users.tar.bz2', {screenshot => 1});
    }
    $log_path = '/var/log/X*';
    if (!script_run("ls -l $log_path")) {
        $self->save_and_upload_log("cat $log_path", '/tmp/Xlogs.system.log', {screenshot => 1});
    }

    # do not upload empty .xsession-errors
    $log_path = '/home/*/.xsession-errors*';
    if (!script_run("ls -l $log_path")) {
        $self->save_and_upload_log("cat $log_path", '/tmp/xsession-errors.log', {screenshot => 1});
    }
    $log_path = '/home/*/.local/share/sddm/*session.log';
    if (!script_run("ls -l $log_path")) {
        $self->save_and_upload_log("cat $log_path", '/tmp/sddm_session.log', {screenshot => 1});
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
    # Device selection: HD or CDROM
    send_key_until_needlematch 'tianocore-select_HD', 'down';
    wait_screen_change { send_key 'ret' };
    # cycle to last entry by going up in the next steps
    # <EFI>
    send_key 'up';
    save_screenshot;
    wait_screen_change { send_key 'ret' };
    # <sles> or <opensuse>
    send_key 'up';
    save_screenshot;
    wait_screen_change { send_key 'ret' };
    # efi file
    send_key_until_needlematch 'tianocore-select_grubaa64_efi', 'up';
    wait_screen_change { send_key 'ret' };
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
    my $in_grub         = $args{in_grub}         // 0;
    my @tags            = ('grub2');
    push @tags, 'bootloader-shim-import-prompt'   if get_var('UEFI');
    push @tags, 'boot-live-' . get_var('DESKTOP') if get_var('LIVETEST');    # LIVETEST won't to do installation and no grub2 menu show up
    push @tags, 'bootloader'                      if get_var('OFW');
    push @tags, 'encrypted-disk-password-prompt'  if get_var('ENCRYPT');
    if (get_var('ONLINE_MIGRATION')) {
        push @tags, 'migration-source-system-grub2';
    }
    # after gh#os-autoinst/os-autoinst#641 68c815a "use bootindex for boot
    # order on UEFI" the USB install medium is priority and will always be
    # booted so we have to handle that
    # because of broken firmware, bootindex doesn't work on aarch64 bsc#1022064
    push @tags, 'inst-bootmenu'
      if (get_var('USBBOOT') && get_var('UEFI')
        || (check_var('ARCH', 'aarch64') && get_var('UEFI'))
        || get_var('OFW')
        || (check_var('BOOTFROM', 'd')));
    # Enable all migration path on aarch64
    # Refer to ticket: https://progress.opensuse.org/issues/49340
    $self->handle_uefi_boot_disk_workaround
      if (is_aarch64_uefi_boot_hdd
        && !$in_grub
        && (!(isotovideo::get_version() >= 12 && get_var('UEFI_PFLASH_VARS')) || get_var('ONLINE_MIGRATION') || get_var('UPGRADE') || get_var('ZDUP')));
    assert_screen(\@tags, $bootloader_time);
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
        $self->wait_grub_to_boot_on_local_disk;
    }
    elsif (match_has_tag('encrypted-disk-password-prompt')) {
        # unlock encrypted disk before grub
        workaround_type_encrypted_passphrase;
        assert_screen "grub2", 15;
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

    assert_screen(\@tags, 15);
    if (match_has_tag('tianocore-mainmenu')) {
        opensusebasetest::handle_uefi_boot_disk_workaround();
        check_screen('encrypted-disk-password-prompt', 10);
    }
    if (match_has_tag('encrypted-disk-password-prompt')) {
        workaround_type_encrypted_passphrase;
        assert_screen('grub2');
    }
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
    my $linux_boot_entry //= 14;

    die "wait_boot: got undefined class" unless $self;
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
    # On Xen PV and svirt we don't see a Grub menu
    # If KEEP_GRUB_TIMEOUT is defined it means that GRUB menu will appear only for one second
    elsif (!(check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux') && check_var('BACKEND', 'svirt') || check_var('KEEP_GRUB_TIMEOUT', '1'))) {
        $self->wait_grub(bootloader_time => $bootloader_time, in_grub => $in_grub);
        if (my $boot_params = get_var('EXTRABOOTPARAMS_BOOT_LOCAL')) {
            # TODO do we already have code to control the boot parameters? I
            # think so
            wait_screen_change { send_key 'e' };
            for (1 .. $linux_boot_entry) { send_key 'down' }
            wait_screen_change { send_key 'end' };
            send_key_until_needlematch(get_var('EXTRABOOTPARAMS_DELETE_NEEDLE_TARGET'), 'left', 1000) if get_var('EXTRABOOTPARAMS_DELETE_NEEDLE_TARGET');
            for (1 .. get_var('EXTRABOOTPARAMS_DELETE_CHARACTERS', 0)) { send_key 'backspace' }
            type_string_very_slow "$boot_params ";
            save_screenshot;
            send_key 'ctrl-x';
        }
        else {
            # confirm default choice
            send_key 'ret';
        }
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
    my $old_product_versions      = is_sle('<15') || is_leap('<15.0');
    my $upgrade_from_susefirewall = is_upgrade && get_var('HDD_1') =~ /\b(1[123]|42)[\.-]/;
    return (($old_product_versions || $upgrade_from_susefirewall) && !is_tumbleweed) ? 'SuSEfirewall2' : 'firewalld';
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

Purpose of this wrapper is to avoid if/else conditions when selecting console.

Optional C<root> parameter specifies, whether use root user (C<root>=1, also
default when parameter not specified) or prefer non-root user if available.

Variables affecting behavior:
C<VIRTIO_CONSOLE>=0 disables virtio console (use {root,user}-console instead
of the default {root-,}virtio-terminal)

C<SERIAL_CONSOLE>=0 disables serial console (use {root,user}-console instead
of the default {root-,}sut-serial)

On ikvm|ipmi|spvm it's expected, that use_ssh_serial_console() has been called
(done via activate_console()) therefore SERIALDEV has been set and we can
use root-ssh console directly.
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
    } elsif ($backend eq 'svirt') {
        if (check_var('SERIAL_CONSOLE', 0)) {
            $console = $root ? 'root-console' : 'user-console';
        } else {
            $console = $root ? 'root-sut-serial' : 'sut-serial';
        }
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

    if (get_var('FULL_LVM_ENCRYPT') && get_var('LVM_THIN_LV')) {
        my $self = shift;
        select_console 'root-console';
        my $lvmdump_regex = qr{/root/lvmdump-.*?-\d+\.tgz};
        my $out           = script_output 'lvmdump';
        if ($out =~ /(?<lvmdump_gzip>$lvmdump_regex)/) {
            upload_logs "$+{lvmdump_gzip}";
        }
        $self->save_and_upload_log('lvm dumpconfig', '/tmp/lvm_dumpconf.out');
    }

    if ($self->{in_wait_boot}) {
        record_info('shutdown', 'At least we reached target Shutdown') if (wait_serial 'Reached target Shutdown');
    }
    elsif ($self->{in_boot_desktop}) {
        record_info('Startup', 'At least Startup is finished.') if (wait_serial 'Startup finished');
    }
    # Find out in post-fail-hook if system is I/O-busy, poo#35877
    else {
        select_console 'log-console';
        my $io_status = script_output("sed -n 's/^.*da / /p' /proc/diskstats | cut -d' ' -f10");
        record_info('System I/O status:', ($io_status =~ /^0$/) ? 'idle' : 'busy');
    }

    # In case the system is stuck in shutting down or during boot up, press
    # 'esc' just in case the plymouth splash screen is shown and we can not
    # see any interesting console logs.
    send_key 'esc';
    save_screenshot;
    # the space prevents the esc from eating up the next alphanumerical
    # character typed into the console
    send_key 'spc';
}

1;
