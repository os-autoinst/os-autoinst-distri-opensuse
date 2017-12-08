package y2logsstep;
use base "installbasetest";
use testapi;
use strict;
use version_utils 'sle_version_at_least';
use ipmi_backend_utils;

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
    if (check_var('BACKEND', 'ipmi')) {
        use_ssh_serial_console;
        get_ip_address;
        save_screenshot();
        return;
    }

    my @tags = qw(yast-still-running linuxrc-install-fail linuxrc-repo-not-found);
    my $ret = check_screen(\@tags, 5);
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
            send_key 'alt-1';
            sleep 1;
            send_key 'spc';
            sleep 1;
            send_key 'alt-o';
            sleep 2;
        }
    }
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
            send_key 'alt-2';                                 # 2 is the option to break dependency
            sleep 1;
            send_key 'spc';                                   # select it
            sleep 1;
            send_key 'alt-o';                                 # OK
            sleep 2;
        }
    }
}

sub process_unsigned_files {
    my ($self, $expected_screens) = @_;
    # SLE 15 has unsigned file errors, workaround them - rbrown 04/07/2017
    return unless (sle_version_at_least('15'));
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

    return unless check_screen 'manual-intervention', 10;

    record_soft_failure 'dependency warning';

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
        send_key 'alt-a';                      # Accept
    }
    while (check_screen('automatic-changes', 2)) {
        send_key 'alt-o';                      # Continue
    }
    while (check_screen('unsupported-packages', 2)) {
        send_key 'alt-o';                      # Continue
    }
    while (check_screen('error-with-patterns', 2)) {
        record_soft_failure 'bsc#1047337';
        send_key 'alt-o';                      # OK
    }
    sleep 2;

    if (check_screen('dependency-issue-fixed', 0)) {
        if (check_var('VIDEOMODE', 'text')) {
            send_key 'alt-o';                  # OK
        }
        else {
            send_key 'alt-a';                  # Accept
        }
        sleep 2;
    }

    if (check_screen([qw(accept-licence automatic-changes unsupported-packages error-with-patterns sle-15-failed-to-select-pattern)], 2)) {
        goto DO_CHECKS;
    }
    # In text mode dependency issues may occur again after resolving them
    if (check_screen 'manual-intervention') {
        $self->deal_with_dependency_issues;
    }
}

sub verify_license_has_to_be_accepted {
    # license+lang
    if (get_var('HASLICENSE')) {
        send_key $cmd{next};
        assert_screen 'license-not-accepted';
        send_key $cmd{ok};
        wait_still_screen 1;
        send_key $cmd{accept};    # accept license
        wait_still_screen 1;
        save_screenshot;
    }
}

sub save_upload_y2logs {
    my ($self) = shift;
    assert_script_run 'sed -i \'s/^tar \(.*$\)/tar --warning=no-file-changed -\1 || true/\' /usr/sbin/save_y2logs';
    assert_script_run "save_y2logs /tmp/y2logs.tar.bz2", 180;
    upload_logs "/tmp/y2logs.tar.bz2";
    save_screenshot();
    $self->investigate_yast2_failure();
}

sub post_fail_hook {
    my $self = shift;
    get_to_console;
    $self->save_upload_y2logs;
    if (get_var('FILESYSTEM', 'btrfs') =~ /btrfs/) {
        assert_script_run 'btrfs filesystem df /mnt | tee /tmp/btrfs-filesystem-df-mnt.txt';
        assert_script_run 'btrfs filesystem usage /mnt | tee /tmp/btrfs-filesystem-usage-mnt.txt';
        upload_logs '/tmp/btrfs-filesystem-df-mnt.txt';
        upload_logs '/tmp/btrfs-filesystem-usage-mnt.txt';
    }
    assert_script_run 'df -h';
    assert_script_run 'df > /tmp/df.txt';
    upload_logs '/tmp/df.txt';

}

1;
# vim: set sw=4 et:
