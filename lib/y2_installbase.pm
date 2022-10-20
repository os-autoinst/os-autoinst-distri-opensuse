# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
package y2_installbase;

use parent 'y2_base';
use strict;
use warnings;

use testapi;
use Utils::Architectures;

use version_utils qw(is_microos is_sle);
use y2_logs_helper 'get_available_compression';
use utils qw(type_string_slow zypper_call);
use lockapi;
use mmapi;
use Test::Assert 'assert_equals';

my $workaround_bsc1189550_done;

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
    assert_screen 'inst-overview', 120;
}

=head2 validate_default_target

    validate_default_target($expected_target);

The function compares the actual systemd target with the expected one
(the one that passed as an argument to the function)

C<$expected_target> - systemd target that is expected and need to be validated.
=cut

sub validate_default_target {
    my ($self, $expected_target) = @_;
    select_console 'install-shell';

    my $target_search = 'default target has been set';
    # default.target is not yet linked, so we parse logs and assert expectations
    if (my $log_line = script_output("grep '$target_search' /var/log/YaST2/y2log | tail -1",
            proceed_on_failure => 1)) {
        $log_line =~ /$target_search: (?<current_target>.*)/;
        assert_equals($expected_target, $+{current_target}, "Mismatch in default.target");
    }

    select_console 'installation';
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
        assert_screen 'installation-settings-overview-loaded', 90;
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
    workaround_bsc1189550() if (!$workaround_bsc1189550_done && is_sle('>=15-sp3'));
    last if (!$ret);    # down didn't change the screen, so exit here
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
            $self->deselect_pattern() if get_var('EXCLUDE_PATTERNS');
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
    # Ensure mouse on certain pattern then right click
    assert_and_click("minimal-system", button => 'right');
    assert_screen 'selection-menu';
    # select action on all patterns
    wait_screen_change { send_key 'a'; };
    assert_screen 'all-select-install';
    # confirm install
    wait_screen_change { send_key 'ret'; };
    mouse_hide;
    save_screenshot;
    send_key 'alt-o';
    $self->accept3rdparty();
    assert_screen 'inst-overview';
}

=head2 select_not_install_any_pattern 

    select_not_install_any_pattern() 

Being in the "select pattern" screen, performs steps to not install any
patterns.
=cut

sub select_not_install_any_pattern {
    my ($self) = @_;

    # Ensure mouse on certain pattern then right click
    assert_and_click("minimal-system", button => 'right');
    assert_screen 'selection-menu';
    # select action on all patterns
    wait_screen_change { send_key 'a'; };
    # confirm do not install
    assert_and_click 'all-do-not-install';
    save_screenshot;
}

=head2 select_visible_unselected_patterns

    select_visible_unselected_patterns([@patterns])

Being in the "select pattern" screen, performs steps to select visible
patterns.
=cut

sub select_visible_unselected_patterns {
    my ($self, $patterns) = @_;

    assert_and_click("$_-pattern") for ($patterns->@*);
}

=head2 deselect_pattern

    deselect_pattern();

Deselect patterns from already selected ones.
=cut

sub deselect_pattern {
    my ($self) = @_;
    my %patterns;    # set of patterns to be processed
                     # fill with variable values
    @patterns{split(/,/, get_var('EXCLUDE_PATTERNS'))} = ();
    $self->go_to_patterns();
    for my $p (keys %patterns) {
        send_key_until_needlematch "$p-selected", 'down';
        send_key ' ';    #deselect pattern
        assert_screen 'on-pattern';
    }
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
                my $sel = 1;
                my $pattern = $p;    # store pattern untouched
                if ($p =~ /^-/) {
                    # this pattern shall be deselected as indicated by '-' prefix
                    $sel = 0;
                    $p =~ s/^-//;
                }
                if (match_has_tag("pattern-$p")) {
                    $needs_to_be_selected = $sel;
                    $current_pattern = $p;
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
    my (%args) = @_;
    my $action = $args{action};
    my $needles = $args{needles};
    wait_screen_change {
        send_key ' ';
        record_info($action, "");
    };
    assert_screen $needles, 8;
}

=head2 toggle_package

    toggle_package($package_name, $operation);

Being in the "search package" screen, and showing a list of found packages,
performs steps needed to toggle the checkbox of C<$package_name>.
The C<$operation> can be '+' or 'minus'.
=cut

sub toggle_package {
    my ($self, $package_name, $operation) = @_;
    # When coming from search_packages, the search might not be completed yet,
    # give it some time.
    check_screen "packages-$package_name-selected", 60;
    send_key_until_needlematch "packages-$package_name-selected", 'down', 61;
    wait_screen_change { send_key "$operation" };
    wait_still_screen 2;
    save_screenshot;
}

sub use_wicked {
    script_run "cd /proc/sys/net/ipv4/conf";
    script_run("for i in *[0-9]; do echo BOOTPROTO=dhcp > /etc/sysconfig/network/ifcfg-\$i; wicked --debug all ifup \$i; done", 600);
    save_screenshot;
}

sub use_ifconfig {
    script_run "dhcpcd eth0";
}

sub get_ip_address {
    return if (get_var('NET') || is_s390x);
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
    my $ret = check_screen(\@tags, 5);
    if ($ret && match_has_tag("linuxrc-repo-not-found")) {    # KVM only
        send_key "ctrl-alt-f9";
        assert_screen "inst-console";
        enter_cmd "blkid";
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
    send_key 'alt-a';    # Accept
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
        send_key 'alt-o';    # OK
    }
    sleep 2;

    if (check_screen('dependency-issue-fixed', 0)) {
        if (check_var('VIDEOMODE', 'text')) {
            send_key 'alt-o';    # OK
        }
        else {
            send_key 'alt-a';    # Accept
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
        my $timeout = 600;
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

sub save_remote_upload_y2logs {
    my ($self, %args) = @_;

    return if (get_var('NOLOGS'));
    $args{suffix} //= '';

    type_string 'sed -i \'s/^tar \(.*$\)/tar --warning=no-file-changed -\1 || true/\' /usr/sbin/save_y2logs';
    send_key 'ret';
    my $filename = "/tmp/y2logs$args{suffix}.tar" . get_available_compression();
    enter_cmd "save_y2logs $filename";
    my $uploadname = +(split('/', $filename))[2];
    my $upname = ($args{log_name} || $autotest::current_test->{name}) . '-' . $uploadname;
    enter_cmd "curl --form upload=\@$filename --form upname=$upname " . autoinst_url("/uploadlog/$upname") . "";
    save_screenshot();
    $self->investigate_yast2_failure();
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
        return if is_microos;
        $self->save_system_logs;

        # Collect yast2 installer  strace and gbd debug output if is still running
        $self->save_strace_gdb_output;
    }
}

sub workaround_bsc1189550 {
    wait_screen_change { send_key 'end' };
    wait_screen_change { send_key 'home' };
    $workaround_bsc1189550_done = 1;
}

# All steps in the installation are 'fatal'.
sub test_flags {
    return {fatal => 1};
}

1;
