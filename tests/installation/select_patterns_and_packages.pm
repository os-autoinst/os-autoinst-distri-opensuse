# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select given PATTERNS or PACKAGES
#    You can pass
#    PATTERNS=minimal,base or
#    PATTERNS=all to select all of them
#    PACKAGES=quota-nfs,-samba,-grub2  packages starting with - will be removed
#    some package will block installation, conflict will be resolved via INSTALLATION_BLOCKED
#
#    For this you need to have needles that provide pattern-base,pattern-minimal...
#    additional to the on-pattern tag
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "y2logsstep";
use strict;
use testapi;
use version_utils 'is_sle';
#use y2logsstep;

my $secondrun = 0;    # bsc#1029660

sub open_file {
    my ($filename, $mode) = @_;
    open my $fh_log, $mode, $filename
      or die "Can't open yast2 log file '$filename': $!";
    return $fh_log;
}

sub parse_y2log_module_info {
    my @packages;
    my @problems;
    my @do_not_install_packages;
    my @options = ('Install', 'Remove', 'Weaken dependencies');
    my $save_temp_issue;
    my $fh_log;
    my $fh_report;

    {
        local $@;
        $fh_log = eval { open_file('ulogs/package-y2log', '<') };
        if (my $exception = $@) {
            warn "Caught exception: $exception";
        }
    }

    while (my $line = <$fh_log>) {
        chomp($line);
        if ($line =~ m/\[zypp\]/) {
            if ($line =~ m/Install\s.*\)(?<type_of_module>\bpattern\b|\bproduct\b)?:?(?<name_of_module>(((\w+)-)+).*)\((?<repo>\w+.*\w)/) {
                my $module_type = $+{type_of_module} // 'package';
                push @packages, {name => $+{name_of_module}, module => $+{repo}, type => $module_type, action => $options[0]};
            }
            elsif ($line =~ m/Keep NOT installed name\s\w+:\w+\s.*\)(?<type_of_module>\w+):(?<name_of_module>\w+.*\w)\((?<repo>\w+.*\w)/) {
                push @packages, {name => $+{name_of_module}, module => $+{repo}, type => $+{type_of_module}, action => $options[1]};
            }
            elsif ($line =~ m/Weaken dependencies of\s.*\)(?<type_of_module>\bpattern\b|\bproduct\b)?:?(?<name_of_module>\w+.*\w)\((?<repo>\w+.*\w)/) {
                my $module_type = $+{type_of_module} // 'package';
                push @packages,, {name => $+{name_of_module}, module => $+{repo}, type => $module_type, action => $options[2]};
            }
            elsif ($line =~ m/\sSATResolver.cc\(problems\):\d+\s(?<lowercase_problem_lines>[a-z]+(:|\s)\w+.*$)/) {
                # matches
                # (^pattern:((\w+)-)+(\d+\.)+\w+) -> pattern:Google_Cloud_Platform_Instance_Tools-15-3.14.x86_64
                # (^pattern:((\w+)-)+(\d+\.)+\w+\s\w+\s((\w+)-)+\w+) ->
                # pattern:Microsoft_Azure_Instance_Tools-15-3.14.x86_64 requires patterns-public-cloud-15-Microsoft-Azure-Instance-Tools
                if ($+{lowercase_problem_lines} =~ m/(?<issue>^pattern:((\w+)-)+(\d+\.)+\w+\s\w+\s((\w+)-)+\w+)/) {
                    $save_temp_issue = $+{issue};
                }
                elsif ($+{lowercase_problem_lines} =~ m/(?<issue>^nothing(\s\w+)+.*$)/) {
                    $save_temp_issue = $+{issue};
                }
                elsif ($+{lowercase_problem_lines} =~ m/^do not install(?<recommended>.*$)/) {
                    push @do_not_install_packages, $+{recommended};
                }
                elsif ($+{lowercase_problem_lines} =~ m/(?<ignore_deps>^ignore some dependencies of.*)\((?<module>.*)\)/) {
                    # convert array to string
                    push @problems,
                      {issue => $save_temp_issue, recommended_actions => join(",", @do_not_install_packages), ignore => $+{ignore_deps}, module => $+{module}};
                    @do_not_install_packages = ();
                }
            }
        }
    }

    close $fh_log or warn $!;

    {
        local $@;
        $fh_report = eval { open_file('ulogs/y2_module_report.txt', '>') };
        if (my $exception = $@) {
            warn "Caught exception: $exception";
        }
    }


    print $fh_report "=" x 172 . "\n";
    printf $fh_report "%-58s %-86s %s %s\n", 'NAME', 'MODULE', 'TYPE', '   ACTION';
    print $fh_report "=" x 172 . "\n";
    foreach (@packages) {
        my $gap = 149 - (56 + (length($_->{module})));
        printf $fh_report "%-58s %s %${gap}s %s\n", $_->{name}, $_->{module}, $_->{type}, $_->{action};
    }
    print $fh_report "=" x 172 . "\n\n";

    foreach (@problems) {
        print $fh_report "Problem: $_->{issue}\n";
        print $fh_report "Recommended actions:\nDo not install:$_->{recommended_actions}\n";
        print $fh_report "$_->{ignore} from module $_->{module}\n\n";
    }

    close $fh_report or warn $!;
}

sub accept3rdparty {
    #Third party licenses sometimes appear
    while (check_screen([qw(3rdpartylicense automatic-changes inst-overview)], 15)) {
        last if match_has_tag("automatic-changes");
        last if match_has_tag("inst-overview");
        wait_screen_change {
            send_key $cmd{acceptlicense};
        };
    }
}

sub movedownelseend {
    my $ret = wait_screen_change {
        send_key 'down';
    };
    # down didn't change the screen, so exit here
    last if (!$ret);
}

sub check12qtbug {
    if (check_var('VERSION', '12')) {
        if (check_screen('pattern-too-low', 5)) {
            assert_and_click('pattern-too-low', 'left', 1);
        }
    }
}

sub gotopatterns {
    my ($self) = @_;

    $self->deal_with_dependency_issues;

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
        assert_screen 'patterns-list-selected';
    }
    else {
        send_key 'tab';
        send_key ' ';
        assert_screen 'patterns-list-selected';
    }
}

sub package_action {
    my ($self, $unblock) = @_;
    my $operation;
    my $packages = $unblock ? get_var('INSTALLATION_BLOCKED') : get_var('PACKAGES');
    if (get_var('PACKAGES')) {
        if (check_var('VIDEOMODE', 'text')) {
            send_key 'alt-f';
            for (1 .. 4) { send_key 'down'; }
            send_key 'ret';
            assert_screen 'search-list-selected';
        }
        else {
            send_key 'alt-d';    # details button
            assert_screen 'packages-manager-detail';
            assert_and_click 'packages-search-tab';
        }
        for my $p (split(/,/, $packages)) {
            if ($p =~ /^-/) {
                $operation = 'minus';
            }
            else {
                $operation = '+';
            }
            $p =~ s/^-//;        # remove first -
            if (check_var('VIDEOMODE', 'text')) {
                send_key 'alt-p';
                assert_screen 'packages-search-field-selected';
                send_key_until_needlematch 'search-field-empty', 'backspace';
                type_string "$p";
                send_key 'ret';    # search package
            }
            else {
                assert_and_click 'packages-search-field-selected';
                wait_screen_change { send_key 'ctrl-a' };
                wait_screen_change { send_key 'delete' };
                type_string "$p";
                send_key 'alt-s';    # search button
            }
            send_key_until_needlematch "packages-$p-selected", 'down', 60;
            wait_screen_change { send_key "$operation" };
            wait_still_screen 2;
            save_screenshot;
        }
        wait_screen_change { send_key 'alt-a' };    # accept
        sleep 2;                                    # wait_screen_change is too fast
    }

    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-a';                           # accept
        accept3rdparty;
        assert_screen 'automatic-changes';
        send_key 'alt-o';                           # Continue
    }
    else {
        send_key 'alt-o';
        accept3rdparty;
    }
    if (get_var('INSTALLATION_BLOCKED') && $secondrun) {
        record_info 'low prio bug', 'bsc#1029660';
        assert_screen 'inst-overview-blocked';
        send_key 'alt-i';
        assert_screen 'startinstall-blocked';
        send_key 'alt-o';
        assert_screen 'inst-overview-blocked';
    }
    else {
        assert_screen 'inst-overview';
    }
}

sub run {
    my ($self) = @_;
    my $dep_issue;
    $self->gotopatterns;
    if (get_var('PATTERNS')) {
        my %wanted_patterns;
        for my $p (split(/,/, get_var('PATTERNS'))) {
            $wanted_patterns{$p} = 1;
        }

        my $counter = 70;
        while (1) {
            die "looping for too long" unless ($counter--);
            my $needs_to_be_selected;
            my $ret = check_screen('on-pattern', 1);

            if ($ret) {    # unneedled pattern
                for my $wp (keys %wanted_patterns) {
                    if (match_has_tag("pattern-$wp")) {
                        $needs_to_be_selected = 1;
                    }
                }
            }
            $needs_to_be_selected = 1 if ($wanted_patterns{all});

            my $selected = check_screen([qw(current-pattern-selected on-category)], 0);

            if ($selected && $selected->{needle}->has_tag('on-category')) {
                movedownelseend;
                check12qtbug;
                next;
            }
            if ($needs_to_be_selected && !$selected) {
                wait_screen_change {
                    send_key ' ';
                };
                assert_screen 'current-pattern-selected', 5;
            }
            # stick to the default patterns. Check if at least 1 dep. issue was displayed
            $dep_issue = $self->workaround_dependency_issues || $dep_issue;

            if (get_var('PATTERNS', '') =~ /default/) {
                $needs_to_be_selected = $selected;
            }
            if (!$needs_to_be_selected && $selected) {
                send_key ' ';
                assert_screen [qw(current-pattern-unselected current-pattern-autoselected)], 8;
            }
            movedownelseend;
            check12qtbug;
        }
    }
    $self->package_action;
    unless (is_sle('15+') && check_var('PATTERNS', 'all') && $dep_issue) {
        $secondrun++;
        $self->gotopatterns;
        $self->package_action;
        $secondrun--;
        $self->gotopatterns;
        $self->package_action('unblock');
    }
}

sub post_fail_hook {
    my $self = shift;
    select_console('install-shell');
    upload_logs('/var/log/YaST2/y2log', log_name => "package");
    parse_y2log_module_info;
}

1;
