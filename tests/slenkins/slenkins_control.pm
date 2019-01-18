# Copyright (C) 2017 SUSE LLC
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

# Summary: slenkins support
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use warnings;
use base 'basetest';
use testapi;
use lockapi;
use mmapi;
use mm_network;

sub run {
    my $net_conf = parse_network_configuration();

    script_output("
        mkdir /root/.ssh
        curl -f -v " . autoinst_url . "/data/slenkins/ssh/id_rsa > /root/.ssh/id_rsa
        chmod 600 /root/.ssh/*
        chmod 700 /root/.ssh

        # slenkins-engine is required for /usr/lib/slenkins/lib/slenkins-functions.sh below
        zypper -n --no-gpg-checks in " . get_var('SLENKINS_CONTROL') . " slenkins-engine slenkins
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
    my $dhcp_leases_file = script_output("cat /var/lib/dhcp/db/dhcpd.leases\n");

    my $lease_ip;
    for my $l (split /\n/, $dhcp_leases_file) {
        if ($l =~ /^lease\s+([0-9.]+)/) {
            $lease_ip = $1;
        }
        elsif ($l =~ /client-hostname\s+"(.*)"/) {
            my $hostname = lc($1);
            $dhcp_leases{$hostname} //= [];
            push @{$dhcp_leases{$hostname}}, $lease_ip;
        }
    }

    # generate configuration
    my $conf = "";

    my $i = 0;
    for my $p (@$parents) {
        my $node     = $settings{$p}->{SLENKINS_NODE};
        my $networks = $settings{$p}->{NETWORKS} // 'fixed';
        my @external_ip;
        my @internal_ip;
        my @nic;

        my $eth = 0;
        for my $network (split /\s*,\s*/, $networks) {
            if ($net_conf->{$network}->{dhcp}) {
                for my $ip (@{$dhcp_leases{lc($node)}}) {
                    if (check_ip_in_subnet($net_conf->{$network}, $ip)) {
                        push @external_ip, $ip;
                        push @internal_ip, $ip;
                        last;
                    }
                }
            }
            else {
                push @external_ip, "N/A";
                # generate some ip, the test is responsible for configuring it on the node
                push @internal_ip, ip_in_subnet($net_conf->{$network}, $i + 15);
            }
            push @nic, "eth$eth";
            $eth++;
        }
        $conf .= "export EXTERNAL_IP_" . uc($node) . "='" . join(' ', @external_ip) . "'\n";
        $conf .= "export INTERNAL_IP_" . uc($node) . "='" . join(' ', @internal_ip) . "'\n";
        $conf .= "export NIC_" . uc($node) . "='" . join(' ', @nic) . "'\n";
        my $family = uc(join('_', $settings{$p}->{DISTRI}, $settings{$p}->{VERSION}));
        $family =~ s/-/_/g;
        my $system = join('_', $family, $settings{$p}->{FLAVOR}, 'Build' . $settings{$p}->{BUILD});
        $conf .= "export SYSTEM_" . uc($node) . "='$system'\n";
        $conf .= "export FAMILY_" . uc($node) . "='$family'\n";
        $conf .= "export ARCH_" . uc($node) . "='" . $settings{$p}->{ARCH} . "'\n";
        $conf .= "export VARIANT_" . uc($node) . "='default'\n";

        my $disk_name = 'vd';
        $disk_name = 'sd' if ($settings{$p}->{HDDMODEL} || '') eq "virtio-scsi-pci";
        my $disk_size = $settings{$p}->{HDDSIZEGB} || 10;
        my $num_disks = $settings{$p}->{NUMDISKS}  || 1;

        # In SLEnkins DISK_NAME_NODE_DISK0 is used for first additional disk, e.g. /dev/vdb and so on
        # Drive /dev/vda is always in use as bootdrive and has no dedicated variable
        for (my $d = 0; $d < ($num_disks - 1); $d++) {
            $conf .= "export DISK_NAME_" . uc($node) . "_DISK$d='/dev/$disk_name" . chr(ord('b') + $d) . "'\n";
            $conf .= "export DISK_SIZE_" . uc($node) . "_DISK$d='${disk_size}G'\n";
        }
        $i++;
    }
    print "$conf\n";

    script_output('
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

        # Setting new TARGET_TYPE variable (due commit 4128f126f4 in SLEnkins-engine)
        export TARGET_TYPE="ssh"

        # Node preparations - only "default" run is supported (came from multirun slenkins support)
        export RUN_NAME="default"

        # Prepare failures file
        FAILURES="${WORKSPACE}/failed.txt"
        rm -f "$FAILURES"
        touch "$FAILURES"

        # Prepare log files
        export REPORT="${WORKSPACE}/junit-results.xml"
        LOGFILE="${WORKSPACE}/junit-results.log"
        rm -f "$REPORT" "$LOGFILE"
        touch "$LOGFILE"
        set-test-environment
        echo

        # Display nodes file
        display-nodes-file

        # Parse nodes file
        NETWORKS=""
        NODES=""
        echo "Parsing nodes file"
        parse-nodes-file
        echo

        # Node preparations
        for node_name in $NODES; do
          echo "Preparations for node $node_name"
          node=${node_name^^}

          eval "EXTERNAL_IP=( \$EXTERNAL_IP_${node} )"
          eval "INTERNAL_IP=( \$INTERNAL_IP_${node} )"
          eval "NIC=\$NIC_${node}"
          # Another needed variable TARGET added (due commit 4128f126f4 in SLEnkins-engine)
          export TARGET="ssh:$EXTERNAL_IP"
          # Define node-related environment file/variables
          echo "Setting environment variables for the node $node_name"
          define-node-variables "$node_name" "$NIC" ""
          set-node-environment "$node_name"
          echo
        done

        # End test environment file - multirun testenv file handling
        finish-test-environment

        # Get the tests table
        TESTS_DIR="/var/lib/slenkins/${PROJECT_NAME}/${CONTROL_PKG}/bin"
        declare -a TESTS_TABLE
        echo "Trying to read tests table"
        get-tests-table
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

    ', 2000);

    type_string("ls -l /tmp/slenkins/\n");
    parse_junit_log("/tmp/slenkins/junit-results.xml");
    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;

