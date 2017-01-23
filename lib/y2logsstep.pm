package y2logsstep;
use base "installbasetest";
use testapi;
use strict;

sub use_wicked() {
    script_run "cd /proc/sys/net/ipv4/conf";
    script_run
      "for i in *[0-9]; do echo BOOTPROTO=dhcp > /etc/sysconfig/network/ifcfg-\$i; wicked --debug all ifup \$i; done";
}

sub use_ifconfig() {
    script_run "dhcpcd eth0";
}

sub get_ip_address() {
    if (!get_var('NET') && !check_var('ARCH', 's390x')) {
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
}

sub get_to_console() {
    my @tags = qw(yast-still-running linuxrc-install-fail linuxrc-repo-not-found);
    my $ret = check_screen(\@tags, 5);
    if ($ret && match_has_tag("linuxrc-repo-not-found")) {    # KVM only
        send_key "ctrl-alt-f9";
        wait_idle;
        assert_screen "inst-console";
        type_string "blkid\n";
        save_screenshot();
        send_key "ctrl-alt-f3";
        wait_idle;
        sleep 1;
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

# to workaround dep issues
sub record_dependency_issues {
    while (check_screen 'dependancy-issue', 5) {
        wait_screen_change {
            if (check_var('VIDEOMODE', 'text')) {
                send_key 'alt-s';
            }
            else {
                send_key 'alt-1';
            }
        };
        wait_screen_change {
            send_key 'spc';
        };
        send_key 'alt-o';
    }
}

# check for dependency issues, if found, drill down to software selection, take a screenshot, then die
sub check_and_record_dependency_problems {
    my ($self) = @_;

    return unless check_screen("inst-overview-dep-warning", 1);
    record_soft_failure 'dependency warning';
    if (check_var('VIDEOMODE', 'text')) {
        send_key 'alt-c';
        assert_screen 'inst-overview-options';
        send_key 'alt-s';
    }
    else {
        send_key_until_needlematch 'packages-section-selected', 'tab';
        send_key 'ret';
    }

    assert_screen 'dependancy-issue';    #make sure the dependancy issue is actually showing

    if (get_var("WORKAROUND_DEPS")) {
        $self->record_dependency_issues;
        wait_screen_change {
            send_key 'alt-a';
        };
        send_key 'alt-o';
        assert_screen
          "inst-overview-after-depfix";    # Make sure you're back on the inst-overview before doing anything else
    }
    else {
        save_screenshot;
        die 'Dependency Problems';
    }
}

sub save_upload_y2logs() {
    assert_script_run "save_y2logs /tmp/y2logs.tar.bz2";
    upload_logs "/tmp/y2logs.tar.bz2";
    save_screenshot();
}

sub post_fail_hook() {
    my $self = shift;
    get_to_console;
    save_upload_y2logs;
}

1;
# vim: set sw=4 et:
