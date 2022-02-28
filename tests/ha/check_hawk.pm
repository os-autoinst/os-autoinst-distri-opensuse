# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: hawk2 iproute2 netcat-openbsd
# Summary: Basic check of Hawk Web interface
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster qw(get_cluster_name is_node);
use utils qw(systemctl);
use version_utils qw(is_sle);
use List::Util qw(sum);

sub check_hawk_cpu {
    my %args = @_;
    my $cluster_name = get_cluster_name;
    my @cpu_usage = ();
    my $threshold = $args{idle_check} ? 10 : 50;
    my $idle_check_loops = 60;

    # Do not wait on barriers if checking CPU usage while HAWK is idle
    barrier_wait("HAWK_GUI_CPU_TEST_START_$cluster_name") unless $args{idle_check};

    while ($args{idle_check} || !barrier_try_wait("HAWK_GUI_CPU_TEST_FINISH_$cluster_name")) {
        # Wrapping script_output in eval { } as node can be fenced by hawk test from client.
        # In fenced node, script_output will croak and kill the test. This prevents it
        my $metric = eval {
            script_output q@ps axo pcpu,cmd | awk '/hawk|puma/ {if ($2 != "awk") total += $1} END {print "cpu_usage["total"]"}'@,
              proceed_on_failure => 1, quiet => 1;
        };
        if ($@) {
            # When script_output croaks, command may be typed when SUT is on the grub menu
            # and either boot the system or get into grub editing. If system has booted,
            # force a new fence; if it's still in grub menu, do nothing; otherwise send an
            # ESC to return SUT to grub menu and exit the loop
            if (check_screen('linux-login')) {
                reset_consoles;
                select_console('root-console');
                enter_cmd 'echo b > /proc/sysrq-trigger';
            }
            else {
                send_key 'esc' unless check_screen('grub2');
            }
            barrier_wait("HAWK_GUI_CPU_TEST_FINISH_$cluster_name") unless $args{idle_check};
            last;
        }
        push @cpu_usage, $metric =~ /cpu_usage\[([\d\.]+)\]/;
        sleep bmwqemu::scale_timeout(1);
        last if ($args{idle_check} && (--$idle_check_loops < 0));
    }
    die "No HAWK/PUMA CPU usage measurements found. Is it running?" unless (@cpu_usage);
    my $cpu_usage = sum(@cpu_usage) / @cpu_usage;
    my $msg = "HAWK/PUMA CPU usage was $cpu_usage";
    $msg .= " while idle" if $args{idle_check};
    record_info "CPU usage", $msg;
    record_soft_failure "bsc#1179609 - HAWK/PUMA consume a considerable amount of CPU" if ($cpu_usage >= $threshold);
}

sub run {
    my $cluster_name = get_cluster_name;
    my $hawk_port = '7630';

    barrier_wait("HAWK_INIT_$cluster_name");

    # Test the Hawk service
    if (!systemctl 'status hawk.service', ignore_failure => 1) {
        # Test if Hawk service state is set to enable
        assert_script_run("systemctl show -p UnitFileState hawk.service | grep UnitFileState=enabled");

        # Test the Hawk port
        assert_script_run "ss -nap | grep '.*LISTEN.*:$hawk_port\[[:blank:]]*'";

        # Test Hawk connection
        assert_script_run "nc -zv localhost $hawk_port";
    }
    else {
        # Hawk is broken in SLE-15-SP1 we have an opened bug, so record it and continue in that case
        if (is_sle('=15-sp1')) {
            record_soft_failure 'Hawk is known to fail in 15-SP1 - bsc#1116209';
        }
        else {
            record_info 'Hawk', 'Hawk is failing! Analysis is requiring and consider to open a bug if needed!';
        }
    }

    # Keep a screenshot for this test
    save_screenshot;

    barrier_wait("HAWK_CHECKED_$cluster_name");

    # If testing HAWK GUI, also wait for those barriers
    if (get_var('HAWKGUI_TEST_ROLE')) {
        check_hawk_cpu(idle_check => 1);
        barrier_wait("HAWK_GUI_INIT_$cluster_name");
        check_hawk_cpu;
        barrier_wait("HAWK_GUI_CHECKED_$cluster_name");
    }

    # This module is the last one scheduled in cluster verification migration tests. Since node one
    # handles the barriers when not using support server, we need to give it more time for the other
    # nodes to finish
    sleep bmwqemu::scale_timeout(10) if (is_node(1) and get_var('TEST') =~ /verify/ and !get_var('USE_SUPPORT_SERVER'));
}

# Specific test_flags for this test module
sub test_flags {
    return {milestone => 1};
}

1;
