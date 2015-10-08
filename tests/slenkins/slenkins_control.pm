# Copyright (C) 2015 SUSE Linux GmbH
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

use strict;
use base 'basetest';
use testapi;
use lockapi;
use mmapi;
use mm_network;
use ttylogin;

sub run {
    my $self = shift;

    script_output("
        mkdir /root/.ssh
        curl -f -v " . autoinst_url . "/data/slenkins/ssh/id_rsa > /root/.ssh/id_rsa
        chmod 600 /root/.ssh/*
        chmod 700 /root/.ssh

        zypper -n --no-gpg-checks ar '" . get_var('SLENKINS_TESTSUITES_REPO') . "' slenkins_testsuites
        zypper -n --no-gpg-checks ar '" . get_var('SLENKINS_REPO') . "' slenkins

        # slenkins-engine-tests is required for /usr/lib/slenkins/lib/slenkins-functions.sh below
        zypper -n --no-gpg-checks in " . get_var('SLENKINS_CONTROL') . " slenkins-engine-tests slenkins
    ", 100);

    my $parents = get_parents();
    my %settings;

    # wait for parents (nodes)
    for my $p (@$parents) {
        $settings{$p} = get_job_info($p)->{settings};

        my $node = $settings{$p}->{SLENKINS_NODE};

        die "parent has no SLENKINS_NODE variable defined" unless $node;
        mutex_lock($node);
    }

    # parse dhcpd.leases - now it should contain entries for all nodes
    my %dhcp_leases;
    my $dhcp_leases_file = script_output("cat /var/lib/dhcp/db/dhcpd.leases");

    my $lease_ip;
    for my $l (split /\n/, $dhcp_leases_file) {
        if ($l =~ /^lease\s+([0-9.]+)/) {
            $lease_ip = $1;
        }
        elsif ($l =~ /client-hostname\s+"(.*)"/) {
            $dhcp_leases{$1} = $lease_ip;
        }
    }

    # generate configuration
    my $conf = "";

    for my $p (@$parents) {
        my $node = $settings{$p}->{SLENKINS_NODE};
        my $ip   = $settings{$p}->{SLENKINS_IP};

        if (!$ip || $ip eq 'dhcp') {
            $ip = $dhcp_leases{$node};
        }

        $conf .= "EXTERNAL_IP_" . uc($node) . "=$ip\n";
    }
    print "$conf\n";

    script_output('
        #FIXME: can we move the following line to script_output function?
        trap "echo SCRIPT_FINISHED" EXIT

        # the logger apparently has some hardcoded colors
        setterm -background white --foreground black

        source /usr/lib/slenkins/lib/slenkins-functions.sh

        # include generated configuration
        ' . $conf . '

        # we already have the correct control pkg installed, guess these vars from it
        export PROJECT_NAME=`echo /var/lib/slenkins/*/*/nodes | cut -d / -f 5`
        export CONTROL_PKG=`echo /var/lib/slenkins/*/*/nodes | cut -d / -f 6`

        # Create workspace
        export WORKSPACE=/tmp/slenkins
        echo "Creating workspace in $WORKSPACE"
        create-workspace
        echo

        # Parse nodes file
        NETWORKS=""
        NODES=""
        echo "Parsing nodes file"
        parse-nodes-file
        echo

        # Start test environment file
        export REPORT="${WORKSPACE}/junit-results.xml"
        set-test-environment
        echo

        # Node preparations
        for node_name in $NODES; do
          echo "Preparations for node $node_name"
          node=${node_name^^}

          #FIXME: support multiple networks
          eval "EXTERNAL_IP=\$EXTERNAL_IP_${node}"
          INTERNAL_IP=$EXTERNAL_IP
          # Define node-related environment file/variables
          echo "Setting environment variables for the node $node_name"
          set-node-environment $node_name eth0
          echo
        done

        # End test environment file
        echo "</testenv>" >> $WORKSPACE/testenv.xml

        # Get the tests table
        TESTS_DIR="/var/lib/slenkins/${PROJECT_NAME}/${CONTROL_PKG}/bin"
        declare -a TESTS_TABLE
        echo "Trying to read tests table"
        get-tests-table
        echo

        # Prepare logs files
        FAILURES="${WORKSPACE}/failed.txt"
        LOGFILE="${WORKSPACE}/junit-results.log"
        echo "Preparing logs files"
        prepare-logs
        echo

        # Run one test after the other
        for current_test in ${TESTS_TABLE[@]}; do
          echo "Trying to run test ${current_test}"
          run-tests $current_test
          echo
        done

        # Finish log files
        echo "Finishing log files"
        finish-logs
        echo

        # Check for failures
        echo "Checking for failed tests"
        check-failures
    ', 2000);

    type_string("ls -l /tmp/slenkins/\n");
    parse_junit_log("/tmp/slenkins/junit-results.xml");
    save_screenshot;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
