# SUSE's openQA tests
#
# Copyright (c) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Execute the pacemaker-cts cluster exerciser to test a whole
# cluster.
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use Mojo::JSON 'encode_json';
use lockapi;
use testapi;
use utils qw(systemctl zypper_call exec_and_insert_password);
use hacluster;

sub add_to_known_hosts {
    my $hostname = shift;
    assert_script_run "mkdir -p ~/.ssh";
    assert_script_run "chmod 700 ~/.ssh";
    assert_script_run "ssh-keyscan -H $hostname >> ~/.ssh/known_hosts";
}

sub run {
    my $cts_bin      = '/usr/share/pacemaker/tests/cts/CTSlab.py';
    my $log          = '/tmp/cts_cluster_exerciser.log';
    my $cluster_name = get_cluster_name;
    my $results_file = '/tmp/cts_cluster_exerciser.results';
    my $node_01      = choose_node(1);
    my $node_02      = choose_node(2);
    my $stonith_type = 'external/sbd';
    my $stonith_args = 'pcmk_delay_max=30,pcmk_off_action=reboot,action=reboot';
    my $test_ip      = '10.0.2.20';
    my $timeout      = 60 * 90;

    # Wait until Pacemaker cts test is initialized
    barrier_wait("PACEMAKER_CTS_INIT_$cluster_name");

    zypper_call 'in pacemaker-cts';
    save_screenshot;

    # Pacemaker cts software must be started from the client server
    if (check_var('PACEMAKER_CTS_TEST_ROLE', 'client')) {
        assert_script_run 'ssh-keygen -f /root/.ssh/id_rsa -N ""';

        foreach my $node ($node_01, $node_02) {
            add_to_known_hosts($node);
            exec_and_insert_password("ssh-copy-id -f root\@$node");
        }

        # Don't do stonith test since this one reboots a node randomly
        # and it's very difficult to handle in MM scenario.
        assert_script_run "sed -i '/AllTestClasses.append(StonithdTest)/ s/^/#/' \$(rpm -ql pacemaker-cts|grep CTStests.py)";

        # Start pacemaker cts cluster exerciser
        my $cts_start_time = time;
        assert_script_run "$cts_bin --nodes '$node_01 $node_02' --stonith-type $stonith_type --stonith-args $stonith_args --test-ip-base $test_ip --no-loop-tests --no-unsafe-tests --at-boot 1 --outputfile $log --once", $timeout;
        my $cts_end_time = time;

        # Parse the logs to get a better overview in openQA
        my $output = script_output "awk '(\$5 == \"Test\" && \$6 != \"Summary\") {print}' $log";

        my %results;

        $results{tests}   = [];
        $results{info}    = {};
        $results{summary} = {};

        $results{info}->{timestamp}    = time;
        $results{info}->{distro}       = "";
        $results{info}->{results_file} = "";
        $results{summary}->{num_tests} = 0;
        $results{summary}->{passed}    = 0;
        $results{summary}->{duration}  = $cts_end_time - $cts_start_time;

        foreach my $line (split("\n", $output)) {
            my %aux = ();
            next unless ($line =~ /Test ([^:]+)/);
            $results{summary}->{num_tests}++;
            $aux{name} = lc($1);
            $line =~ /'failure': ([0-9]+)/;
            my $failure = $1;
            $line =~ /'auditfail': ([0-9]+)/;
            my $auditfail = $1;
            $aux{outcome}    = ($failure == 0 and $auditfail == 0) ? 'passed' : 'failed';
            $aux{test_index} = 0;
            push @{$results{tests}}, \%aux;
            $results{summary}->{passed}++ if ($aux{outcome} eq 'passed');
        }

        my $json = encode_json \%results;
        assert_script_run "echo '$json' > $results_file";

        # Upload pacemaker cts log
        parse_extra_log(IPA => $results_file);
        upload_logs $log;
    }

    # Synchronize all the nodes
    barrier_wait("PACEMAKER_CTS_CHECKED_$cluster_name");
}

1;
