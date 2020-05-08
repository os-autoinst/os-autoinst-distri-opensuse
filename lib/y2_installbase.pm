# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
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
# with this program; if not, see <http://www.gnu.org/licenses/>.
package y2_installbase;

use base "installbasetest";
use strict;
use warnings;
use ipmi_backend_utils;
use testapi;
use network_utils;
use version_utils qw(is_caasp is_sle);
use y2_logs_helper 'get_available_compression';
use utils qw(type_string_slow zypper_call);
use lockapi;
use mmapi;

=head1 y2_installbase

C<y2_installbase> - Base class for Yast installer related functionality

=cut

=head2 accept3rdparty

    accept3rdparty();

After making changes in the "software selection" screen, accepts any 3rd party
license.
=cut
sub accept3rdparty {
    my ($self) = @_;
    #Third party licenses sometimes appear
    while (check_screen([qw(3rdpartylicense automatic-changes inst-overview)], 15)) {
        if (match_has_tag("automatic-changes")) {
            send_key 'alt-o';
            last;
        }

        last if match_has_tag("inst-overview");
        wait_screen_change { send_key $cmd{acceptlicense} };
    }
}

=head2 accept_changes

    accept_changes();

After making changes in the "pattern selection" screen, accepts changes.
=cut
sub accept_changes {
    my ($self) = @_;
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-a';
    } else {
        send_key 'alt-o';
    }
    $self->accept3rdparty();
    assert_screen 'inst-overview';
}

=head2 back_to_overview_from_packages

    back_to_overview_from_packages();

Being in the "search packages" screen, performs steps needed to go back to
overview page accepting automatic changes changes and 3rd party licenses.
=cut
sub back_to_overview_from_packages {
    my ($self) = @_;
    wait_screen_change { send_key 'alt-a' };    # accept
    assert_screen('automatic-changes');
    send_key 'alt-o';
    $self->accept3rdparty();
    assert_screen('installation-settings-overview-loaded');
}

=head2 check12qtbug

    check12qtbug();

Being in the "select pattern" screen, workaround a known bug of Yast using QT.
=cut
sub check12qtbug {
    if (check_screen('pattern-too-low', 5)) {
        assert_and_click('pattern-too-low', timeout => 1);
    }
}

=head2 go_to_patterns

    go_to_patterns();

Performs steps needed to go from the "installation overview" screen to the
"pattern selection" screen.
=cut
sub go_to_patterns {
    my ($self) = @_;
    $self->deal_with_dependency_issues();
    if (check_var('VIDEOMODE', 'text')) {
        wait_still_screen;
        send_key 'alt-c';
        assert_screen 'inst-overview-options';
        send_key 'alt-s';
    }
    else {
        send_key_until_needlematch 'packages-section-selected', 'tab';
        send_key 'ret';
    }
    assert_screen 'pattern_selector';
    if (check_var('VIDEOMODE', 'text')) {
        wait_screen_change { send_key 'alt-f' };
        for (1 .. 4) { send_key 'up'; }
        send_key 'ret';
    }
    else {
        send_key 'tab';
    }
    # pressing end and home to have selection more visible, and the scrollbar
    # length is re-caculated
    wait_screen_change { send_key 'end' };
    wait_screen_change { send_key 'home' };
    assert_screen 'patterns-list-selected';
}

=head2 go_to_search_packages

    go_to_search_packages();

Performs steps needed to go from the "pattern selection" screen to
"search packages" screen.
=cut
sub go_to_search_packages {
    my ($self) = @_;
    send_key 'alt-d';    # details button
    assert_screen 'packages-manager-detail';
    assert_and_click 'packages-search-tab';
    assert_and_click 'packages-search-field-selected';
}

=head2 move_down

    move_down();

Being in the "select pattern" screen, performs steps needed to move the
highlight cursor one item down.
=cut
sub move_down {
    my $ret = wait_screen_change { send_key 'down' };
    last         if (!$ret);                      # down didn't change the screen, so exit here
    check12qtbug if check_var('VERSION', '12');
}

=head2 process_patterns

    process_patterns();

Decides to select all patterns or specific patterns based on setting PATTERNS
Possible values for PATTERNS
  PATTERNS=minimal,base
  PATTERNS=all (to select all of them)
  PATTERNS=default,web,-x11,-gnome (to keep the default but add web and remove x11 and gnome)
=cut
sub process_patterns {
    my ($self) = @_;
    if (get_required_var('PATTERNS')) {
        if (check_var('PATTERNS', 'all') && !check_var('VIDEOMODE', 'text')) {
            $self->select_all_patterns_by_menu();
        }
        else {
            $self->select_specific_patterns_by_iteration();
        }
    }
}

=head2 search_package

    search_package($package_name);

Being in the "search package" screen, performs steps needed to search for
C<$package_name>
=cut
sub search_package {
    my ($self, $package_name) = @_;
    assert_and_click 'packages-search-field-selected';
    wait_screen_change { send_key 'ctrl-a' };
    wait_screen_change { send_key 'delete' };
    type_string_slow "$package_name";
    send_key 'alt-s';    # search button
}

=head2 select_all_patterns_by_menu

    select_all_patterns_by_menu();

Being in the "select pattern" screen, performs steps needed to select all
available patterns.
=cut
sub select_all_patterns_by_menu {
    my ($self) = @_;
    # move mouse on patterns and open menu
    mouse_set 100, 400;
    mouse_click 'right';
    wait_still_screen 3;
    # select action on all patterns
    wait_screen_change { send_key 'a'; };
    # confirm install
    wait_screen_change { send_key 'ret'; };
    mouse_hide;
    save_screenshot;
    send_key 'alt-o';
    $self->accept3rdparty();
    assert_screen 'inst-overview';
}

=head2 select_specific_patterns_by_iteration

    select_specific_patterns_by_iteration();

Being in the "select pattern" screen, performs steps needed to select given
patterns.
You can pass
  PATTERNS=minimal,base or
  PATTERNS=all to select all of them
  PATTERNS=default,web,-x11,-gnome to keep the default but add web and remove
  x11 and gnome
=cut
sub select_specific_patterns_by_iteration {
    my %patterns;    # set of patterns to be processed
                     # fill with variable values
    @patterns{split(/,/, get_var('PATTERNS'))} = ();

    my $counter = 80;
    # delete special 'all' and 'default' keys from the check
    delete $patterns{default};
    delete $patterns{all};
    while (1) {
        die "looping for too long" unless ($counter--);
        my $needs_to_be_selected;
        my $ret = check_screen('on-pattern', 1);
        # this variable will only be updated when the pattern list entry is under the cursor
        # and the pattern is in the PATTERNS variable and there is a needle for that entry
        my $current_pattern = 'UNKNOWN_PATTERN';

        if ($ret) {    # unneedled pattern
            for my $p (keys %patterns) {
                my $sel     = 1;
                my $pattern = $p;    # store pattern untouched
                if ($p =~ /^-/) {
                    # this pattern shall be deselected as indicated by '-' prefix
                    $sel = 0;
                    $p =~ s/^-//;
                }
                if (match_has_tag("pattern-$p")) {
                    $needs_to_be_selected = $sel;
                    $current_pattern      = $p;
                    delete $patterns{$pattern};    # mark this pattern as processed
                    record_info($current_pattern, $needs_to_be_selected);
                }
            }
        }
        $needs_to_be_selected = 1 if get_var('PATTERNS', '') =~ /all/;

        my $selected = check_screen([qw(current-pattern-selected on-category)], 0);
        if ($selected && $selected->{needle}->has_tag('on-category')) {
            move_down;
            next;
        }
        if ($needs_to_be_selected && !$selected) {
            switch_selection(action => 'select', needles => ['current-pattern-selected']);
        }
        if (get_var('PATTERNS', '') =~ /default/ && !(get_var('PATTERNS', '') =~ /$current_pattern/)) {
            $needs_to_be_selected = $selected;
            record_info("keep default", "");
        }
        if (!$needs_to_be_selected && $selected) {
            switch_selection(action => 'unselect', needles => [qw(current-pattern-unselected current-pattern-autoselected)]);
        }

        # exit earlier if default and all patterns were processed
        last if ((get_var('PATTERNS', '') =~ /default/) && !(scalar keys %patterns));

        move_down;
    }
    # check if we have processed all patterns mentioned in the test suite settings
    my @unseen = keys %patterns;
    die "Not all patterns given in the job settings were processed:" . join(", ", @unseen) if @unseen;
}

=head2 switch_selection

    switch_selection(action => $action, needles => ARRAY($needles));

Being in the "select pattern" screen, performs steps needed to switch the
checkbox (C<$action>) of the pattern matching one of the given C<$needles>.
Example
  switch_selection(action => 'select', needles => ['current-pattern-selected']);
=cut
sub switch_selection {
    my (%args)  = @_;
    my $action  = $args{action};
    my $needles = $args{needles};
    wait_screen_change {
        send_key ' ';
        record_info($action, "");
    };
    assert_screen $needles, 8;
}

=head2 toogle_package

    toogle_package($package_name, $operation);

Being in the "search package" screen, and showing a list of found packages,
performs steps needed to toogle the checkbox of C<$package_name>.
The C<$operation> can be '+' or 'minus'.
=cut
sub toogle_package {
    my ($self, $package_name, $operation) = @_;
    send_key_until_needlematch "packages-$package_name-selected", 'down', 60;
    wait_screen_change { send_key "$operation" };
    wait_still_screen 2;
    save_screenshot;
}

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
    return if get_var('FIPS_INSTALLATION');

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

# Process unsigned files:
# - return value 0 (false) when expected screen is present, regardless files were found or not
# - return value 1 (true) when rearching number of retries or when this check does not apply.
sub process_unsigned_files {
    my ($self, $expected_screens) = @_;
    # SLE 15 has unsigned file errors, workaround them - rbrown 04/07/2017
    return 1 unless (is_sle('15+'));
    my $counter = 0;
    while ($counter++ < 5) {
        if (check_screen 'sle-15-unsigned-file', 0) {
            record_soft_failure 'bsc#1047304';
            send_key 'alt-y';
            wait_still_screen;
        }
        elsif (check_screen $expected_screens, 0) {
            return 0;
        }
    }
    return 1;
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
    if (check_var("WORKAROUND_DEPS", '1')) {
        y2_logs_helper::workaround_dependency_issues;
    }
    elsif (check_var("BREAK_DEPS", '1')) {
        y2_logs_helper::break_dependency;
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
        $self->deal_with_dependency_issues();
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
        script_run("journalctl -b --no-pager -o short-precise > /dev/$serialdev");
        script_run("dmesg > /dev/$serialdev");
        script_run("cat /var/log/YaST/y2log > /dev/$serialdev");
    }
    save_screenshot();
    # We skip parsing yast2 logs in each installation scenario, but only if
    # test has failed or we want to explicitly identify failures
    $self->investigate_yast2_failure() unless $args{skip_logs_investigation};
}

sub save_remote_upload_y2logs {
    my ($self, %args) = @_;

    return if (get_var('NOLOGS'));
    $args{suffix} //= '';

    type_string 'sed -i \'s/^tar \(.*$\)/tar --warning=no-file-changed -\1 || true/\' /usr/sbin/save_y2logs';
    send_key 'ret';
    my $filename = "/tmp/y2logs$args{suffix}.tar" . get_available_compression();
    type_string "save_y2logs $filename\n";
    my $uploadname = +(split('/', $filename))[2];
    my $upname     = ($args{log_name} || $autotest::current_test->{name}) . '-' . $uploadname;
    type_string "curl --form upload=\@$filename --form upname=$upname " . autoinst_url("/uploadlog/$upname") . "\n";
    save_screenshot();
    $self->investigate_yast2_failure();
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
        my $system_management_locked;
        if ($is_yast_module) {
            $system_management_locked = zypper_call('in gdb', exitcode => [0, 7]) == 7;
        }
        else {
            script_run 'extend gdb';
        }
        unless ($system_management_locked) {
            my $gdb_output = '/tmp/yast_gdb.log';
            my $gdb_ret    = script_run("gdb attach $yast_pid --batch -q -ex 'thread apply all bt' -ex q > $gdb_output", ($trace_timeout + 5));
            upload_logs $gdb_output if script_run '! [[ -e /tmp/yast_gdb.log ]]';
        }
    }
}

sub post_fail_hook {
    my $self = shift;

    if (check_var("REMOTE_CONTROLLER", "ssh") || check_var("REMOTE_CONTROLLER", "vnc")) {
        mutex_create("installation_done");
        wait_for_children;
    }
    else {
        # In case of autoyast, actions in parent post fail hook might close
        # error pop-up and system will reboot, so log collection will fail (see poo#61052)
        $self->SUPER::post_fail_hook unless get_var('AUTOYAST');
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
}

1;
