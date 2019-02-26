package y2logsstep;
use base "installbasetest";
use testapi;
use strict;
use warnings;
use version_utils qw(is_sle is_caasp);
use ipmi_backend_utils;
use network_utils;
use utils 'zypper_call';

sub use_wicked {
    script_run "cd /proc/sys/net/ipv4/conf";
    script_run("for i in *[0-9]; do echo BOOTPROTO=dhcp > /etc/sysconfig/network/ifcfg-\$i; wicked --debug all ifup \$i; done", 300);
    save_screenshot;
}

sub use_ifconfig {
    script_run "dhcpcd eth0";
}

sub get_ip_address {
    return if (get_var('NET') || check_var('ARCH', 's390x'));
    return if (get_var('NOLOGS'));

    # avoid known issue in FIPS mode: bsc#985969
    return if get_var('FIPS');

    if (get_var('OLD_IFCONFIG')) {
        use_ifconfig;
    }
    else {
        use_wicked;
    }
    script_run "ip a";
    save_screenshot;
    script_run "cat /etc/resolv.conf";
    save_screenshot;
}

sub get_to_console {
    my @tags = qw(yast-still-running linuxrc-install-fail linuxrc-repo-not-found);
    my $ret  = check_screen(\@tags, 5);
    if ($ret && match_has_tag("linuxrc-repo-not-found")) {    # KVM only
        send_key "ctrl-alt-f9";
        assert_screen "inst-console";
        type_string "blkid\n";
        save_screenshot();
        wait_screen_change { send_key 'ctrl-alt-f3' };
        save_screenshot();
    }
    elsif ($ret) {
        select_console('install-shell');
        get_ip_address;
    }
    else {
        # We ended up somewhere else, still in a phase we consider yast running
        # (e.g. livecdrerboot did not see a grub screen and booted through to an installed system)
        # so we try to perform a login on TTY2 and export yast logs
        select_console('root-console');
    }
}

# select the conflict resolution for dependency issues
sub select_conflict_resolution {
    # higher similarity level as this should only select a single
    # entry, not close the dialog or something
    wait_screen_change(sub { send_key 'spc' }, undef, similarity_level => 55);
    # lower similarity level to not confuse the button press for
    # screen change
    wait_screen_change(sub { send_key 'alt-o' }, undef, similarity_level => 48);
}

# to workaround dependency issues
sub workaround_dependency_issues {
    return unless check_screen 'dependency-issue', 10;

    if (check_var('VIDEOMODE', 'text')) {
        while (check_screen('dependency-issue', 5)) {
            wait_screen_change { send_key 'alt-s' };
            wait_screen_change { send_key 'ret' };
            wait_screen_change { send_key 'alt-o' };
        }
    }
    else {
        while (check_screen('dependency-issue', 5)) {
            wait_screen_change { send_key 'alt-1' };
            select_conflict_resolution;
        }
    }
    return 1;
}

# to break dependency issues
sub break_dependency {
    return unless check_screen 'dependency-issue', 10;

    if (check_var('VIDEOMODE', 'text')) {
        while (check_screen('dependency-issue-text', 5)) {    # repeat it untill all dependency issues are resolved
            wait_screen_change { send_key 'alt-s' };          # Solution
            send_key 'down';                                  # down to option break dependency
            send_key 'ret';                                   # select option break dependency
            wait_screen_change { send_key 'alt-o' };          # OK - Try Again
        }
    }
    else {
        while (check_screen('dependency-issue', 5)) {
            # 2 is the option to break dependency
            send_key 'alt-2';
            select_conflict_resolution;
        }
    }
}

sub process_unsigned_files {
    my ($self, $expected_screens) = @_;
    # SLE 15 has unsigned file errors, workaround them - rbrown 04/07/2017
    return unless (is_sle('15+'));
    my $counter = 0;
    while ($counter++ < 5) {
        if (check_screen 'sle-15-unsigned-file', 0) {
            record_soft_failure 'bsc#1047304';
            send_key 'alt-y';
        }
        elsif (check_screen $expected_screens, 0) {
            last;
        }
        wait_still_screen;
    }
}

# to deal with dependency issues, either work around it, or break dependency to continue with installation
sub deal_with_dependency_issues {
    my ($self) = @_;

    return unless check_screen 'manual-intervention', 0;

    record_info 'dependency warning', "Dependency warning, working around dependency issues", result => 'fail';

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-c';    # Change
        assert_screen 'inst-overview-options';
        send_key 'alt-s';    # Software
    }
    else {
        send_key_until_needlematch 'packages-section-selected', 'tab';
        send_key 'ret';
    }
    if (get_var("WORKAROUND_DEPS")) {
        $self->workaround_dependency_issues;
    }
    elsif (get_var("BREAK_DEPS")) {
        $self->break_dependency;
    }
    else {
        die 'Dependency problems';
    }

    assert_screen 'dependency-issue-fixed';    # make sure the dependancy issue is fixed now
    send_key 'alt-a';                          # Accept
    sleep 2;

  DO_CHECKS:
    while (check_screen('accept-licence', 2)) {
        wait_screen_change { send_key 'alt-a'; }    # Accept
    }
    while (check_screen('automatic-changes', 2)) {
        wait_screen_change { send_key 'alt-o'; }    # Continue
    }
    while (check_screen('unsupported-packages', 2)) {
        wait_screen_change { send_key 'alt-o'; }    # Continue
    }
    while (check_screen('error-with-patterns', 2)) {
        record_soft_failure 'bsc#1047337';
        send_key 'alt-o';                           # OK
    }
    sleep 2;

    if (check_screen('dependency-issue-fixed', 0)) {
        if (check_var('VIDEOMODE', 'text')) {
            send_key 'alt-o';                       # OK
        }
        else {
            send_key 'alt-a';                       # Accept
        }
        sleep 2;
    }

    if (check_screen([qw(accept-licence automatic-changes unsupported-packages error-with-patterns sle-15-failed-to-select-pattern)], 2)) {
        goto DO_CHECKS;
    }

    # Installer need time to adapt the proposal after conflicts fixed
    # Refer ticket: https://progress.opensuse.org/issues/48371
    assert_screen([qw(installation-settings-overview-loaded adapting_proposal)], 90);
    if (match_has_tag('adapting_proposal')) {
        my $timeout  = 600;
        my $interval = 10;
        my $timetick = 0;

        while (check_screen('adapting_proposal', timeout => 30, no_wait => 1)) {
            sleep 10;
            $timetick += $interval;
            last if $timetick >= $timeout;
        }
        die "System might be stuck on adapting proposal" if $timetick >= $timeout;
    }

    # In text mode dependency issues may occur again after resolving them
    if (check_screen 'manual-intervention', 30) {
        $self->deal_with_dependency_issues;
    }
}

=head2 verify_license_has_to_be_accepted

    verify_license_has_to_be_accepted;

Explicitly check that the license has to be accepted.

Press 'Next' button to trigger a popup saying that the License has to be accepted then close the popup.

=cut

sub verify_license_has_to_be_accepted {
    send_key $cmd{next};
    assert_screen 'license-not-accepted';
    send_key $cmd{ok};
    wait_still_screen 1;
}

=head2 accept_license

    accept_license;

Select checkbox accepting the License agreement and check if it is actually selected.

Mark the test as failed if the checkbox is not selected after sending an appropriate command, otherwise proceed further.

=cut

sub accept_license {
    send_key $cmd{accept};
    assert_screen('license-agreement-accepted');
}

sub verify_license_translations {
    return if (is_sle && get_var("BETA") || check_var('VIDEOMODE', 'text'));
    my $current_lang = 'english-us';
    for my $lang (split(/,/, get_var('EULA_LANGUAGES')), 'english-us') {
        wait_screen_change { send_key 'alt-l' };
        assert_and_click "license-language-selected-$current_lang";
        wait_screen_change { type_string(substr($lang, 0, 1)) };
        send_key_until_needlematch("license-language-selected-dropbox-$lang", 'down', 60);
        send_key 'ret';
        assert_screen "license-content-$lang";
        $current_lang = $lang;
    }
}

sub save_upload_y2logs {
    my ($self, %args) = @_;

    return if (get_var('NOLOGS'));
    $args{suffix} //= '';

    # Do not test/recover network if collect from installation system, as it won't work anyway with current approach
    # Do not recover network on non-qemu backend, as not implemented yet
    $args{no_ntwrk_recovery} //= (get_var('BACKEND') !~ /qemu/);

    # Try to recover network if cannot reach gw and upload logs if everything works
    if (can_upload_logs() || (!$args{no_ntwrk_recovery} && recover_network())) {
        assert_script_run 'sed -i \'s/^tar \(.*$\)/tar --warning=no-file-changed -\1 || true/\' /usr/sbin/save_y2logs';
        my $filename = "/tmp/y2logs$args{suffix}.tar" . get_available_compression();
        assert_script_run "save_y2logs $filename", 180;
        upload_logs $filename;
    } else {    # Redirect logs content to serial
        script_run("journalctl -b --no-pager > /dev/$serialdev");
        script_run("dmesg > /dev/$serialdev");
        script_run("cat /var/log/YaST/y2log > /dev/$serialdev");
    }
    save_screenshot();
    # We skip parsing yast2 logs in each installation scenario, but only if
    # test has failed or we want to explicitly identify failures
    $self->investigate_yast2_failure() unless $args{skip_logs_investigation};
}

sub get_available_compression {
    my %extensions = (bzip2 => '.bz2', gzip => '.gz', xz => '.xz');
    foreach my $binary (sort keys %extensions) {
        return $extensions{$binary} unless script_run("type $binary");
    }
    return "";
}

sub save_system_logs {
    my ($self) = @_;

    return if (get_var('NOLOGS'));

    if (get_var('FILESYSTEM', 'btrfs') =~ /btrfs/) {
        assert_script_run 'btrfs filesystem df /mnt | tee /tmp/btrfs-filesystem-df-mnt.txt';
        assert_script_run 'btrfs filesystem usage /mnt | tee /tmp/btrfs-filesystem-usage-mnt.txt';
        upload_logs '/tmp/btrfs-filesystem-df-mnt.txt';
        upload_logs '/tmp/btrfs-filesystem-usage-mnt.txt';
    }
    assert_script_run 'df -h';
    assert_script_run 'df > /tmp/df.txt';
    upload_logs '/tmp/df.txt';

    # Log connections
    script_run('ss -tulpn > /tmp/connections.txt');
    upload_logs '/tmp/connections.txt';
    # Check network traffic
    script_run('for run in {1..10}; do echo "RUN: $run"; nstat; sleep 3; done | tee /tmp/network_traffic.log');
    upload_logs '/tmp/network_traffic.log';
    # Check VM load
    script_run('for run in {1..3}; do echo "RUN: $run"; vmstat; sleep 5; done | tee /tmp/cpu_mem_usage.log');
    upload_logs '/tmp/cpu_mem_usage.log';

    $self->save_and_upload_log('pstree',  '/tmp/pstree');
    $self->save_and_upload_log('ps auxf', '/tmp/ps_auxf');
}

sub save_strace_gdb_output {
    my ($self, $is_yast_module) = @_;
    return if (get_var('NOLOGS'));

    # Collect yast2 installer or yast2 module trace if is still running
    if (!script_run(qq{ps -eo pid,comm | grep -i [y]2start | cut -f 2 -d " " > /dev/$serialdev}, 0)) {
        chomp(my $yast_pid = wait_serial(qr/^[\d{4}]/, 10));
        return unless defined($yast_pid);
        my $trace_timeout = 120;
        my $strace_log    = '/tmp/yast_trace.log';
        my $strace_ret    = script_run("timeout $trace_timeout strace -f -o $strace_log -tt -p $yast_pid", ($trace_timeout + 5));

        upload_logs $strace_log if script_run "! [[ -e $strace_log ]]";

        # collect installer proc fs files
        my @procfs_files = qw(
          mounts
          mountinfo
          mountstats
          maps
          status
          stack
          cmdline
          environ
          smaps);

        my $opt = defined($is_yast_module) ? 'module' : 'installer';
        foreach (@procfs_files) {
            $self->save_and_upload_log("cat /proc/$yast_pid/$_", "/tmp/yast2-$opt.$_");
        }
        # We enable gdb differently in the installer and in the installed SUT
        if ($is_yast_module) {
            zypper_call 'in gdb';
        }
        else {
            assert_script_run 'extend gdb';
        }
        my $gdb_output = '/tmp/yast_gdb.log';
        my $gdb_ret    = script_run("gdb attach $yast_pid --batch -q -ex 'thread apply all bt' -ex q > $gdb_output", ($trace_timeout + 5));
        upload_logs $gdb_output if script_run '! [[ -e /tmp/yast_gdb.log ]]';
    }
}

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook;
    get_to_console;
    $self->detect_bsc_1063638;
    $self->get_ip_address;
    $self->remount_tmp_if_ro;
    # Avoid collectin logs twice when investigate_yast2_failure() is inteded to hard-fail
    $self->save_upload_y2logs unless get_var('ASSERT_Y2LOGS');
    return if is_caasp;
    $self->save_system_logs;

    # Collect yast2 installer  strace and gbd debug output if is still running
    $self->save_strace_gdb_output;
}

1;
