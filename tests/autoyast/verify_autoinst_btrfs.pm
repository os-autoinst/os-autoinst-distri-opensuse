# Copyright (C) 2017-2018 SUSE LLC
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
#
# Summary: Test verifies that generated autoinst.xml btrfs configuration matches
# expected settings. Mount options and subvolume configuration are verified.
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use base 'basetest';
use testapi;
use version_utils 'is_sle';
use XML::LibXML;

#Xpath parser
my $dom;
my $xpc;


sub run {
    # Accumulate errors in this variable if any
    my $errors;
    # Copy file content to variable
    my $autoinst = script_output("cat /root/autoinst.xml");
    # Init parser
    $dom = XML::LibXML->load_xml(string => $autoinst);
    # Init xml namespace
    $xpc = XML::LibXML::XPathContext->new($dom);
    $xpc->registerNs('ns', 'http://www.suse.com/1.0/yast2ns');

    ### Verify mount options enable_snapshots
    my $result_str = verify_option('//ns:partitioning/ns:drive[ns:device="/dev/vda"]/ns:enable_snapshots', 'true');
    $errors .= "enable_snapshots option check failed: $result_str\n" if ($result_str);

    ### Verify mount options btrfs_set_default_subvolume_name, this is valid only for SLE12, with storage-ng subvolumes_prefix is used
    if (is_sle '15+') {
        # Verify empty subvolume prefix for '/' mount point
        $result_str = verify_option('//ns:partition[ns:mount="/"]/ns:subvolumes_prefix', '');
        $errors .= "subvolumes_prefix option check failed: $result_str\n" if ($result_str);
    }
    else {
        $result_str = verify_option('//ns:btrfs_set_default_subvolume_name', 'false');
        $errors .= "btrfs_set_default_subvolume_name option check failed: $result_str\n" if ($result_str);
    }

    ### Verify mount options
    $result_str = verify_mount_opts("/", "rw,relatime,space_cache");
    $errors .= "Mount options verification failed for /: $result_str\n" if ($result_str);

    $result_str = verify_mount_opts("/var/log", "rw,relatime,nobarrier,nodatacow");
    $errors .= "Mount options verification failed for /: $result_str\n" if ($result_str);

    ### Verify subvolumes
    $result_str = verify_subvolumes("/var/log", ());
    $errors .= "Subvolumes verification failed for /var/log: $result_str\n" if ($result_str);

    ### Verify subvolumes
    $result_str = verify_subvolumes('/', (opt => 'true', 'usr/local' => 'true', tmp => 'false'));
    $errors .= "Subvolumes verification failed for /: $result_str\n" if ($result_str);

    $result_str = verify_subvolumes("/var/log", ());
    $errors .= "Subvolumes verification failed for /var/log: $result_str\n" if ($result_str);

    ### Fail test in case of any failed checks
    die $errors if ($errors);
}

sub verify_option {
    my ($xpath, $expected_val) = @_;

    my $nodeset = $xpc->findnodes($xpath);
    for my $node ($nodeset->get_nodelist) {
        print $node->to_literal;
    }
    my @nodes = $nodeset->get_nodelist;
    ## Verify that there is node found by xpath and it's single one
    if (scalar @nodes != 1) {
        return "Generated autoinst.xml contains unexpected number of nodes for xpath: $xpath. Found: " . scalar @nodes . ", expected: 1.";
    }
    if ($nodes[0]->to_literal ne $expected_val) {
        return "Unexpected value for xpath $xpath. Expected: '$expected_val', got: '$nodes[0]'";
    }

    return '';

}

sub verify_subvolumes {
    my ($mount_path, %subvolume_opts) = @_;
    # Path to subvolumes differs on SLE 15 and SLE 12
    my $subvolumes_path = "//ns:partition[ns:mount=\"$mount_path\"]/ns:subvolumes/ns:" . (is_sle('15+') ? 'subvolume' : 'listentry');
    my $nodeset = $xpc->findnodes($subvolumes_path);

    ##Verify that is no subvolumes are expected, there are no entries
    if (!%subvolume_opts && $nodeset) {
        return "Expected no subvolumes configured, got " . $nodeset->get_nodelist->size;
    }
    my @nodes = $nodeset->get_nodelist;

    # Check that sets of subvolumes match expectation
    my @exp_keys = keys %subvolume_opts;
    if (scalar @nodes != scalar @exp_keys) {
        return "Got unexpected number of subvolumes in autoinst.xml. Expected: " . @exp_keys . " actual: " . scalar @nodes;
    }

    # Verify copy_on_write option for subvolumes
    for my $node (@nodes) {
        my $expected_cow = $subvolume_opts{$node->getChildrenByTagName("path")->to_literal};
        my $actual_cow   = $node->getChildrenByTagName("copy_on_write")->to_literal;
        if ($expected_cow ne $actual_cow) {
            return "Unexpected copy_on_write value for mount on path $mount_path:" . " expected $expected_cow, actual $actual_cow";
        }
    }

    return '';
}

sub verify_mount_opts {
    my ($mount_path, $mount_opts) = @_;
    my $nodeset = $xpc->findnodes("//ns:partition[ns:mount=\"$mount_path\"]/ns:fstopt");

    my @nodes = $nodeset->get_nodelist;
    ## Verify that there is node found by xpath and it's single one
    if (scalar @nodes != 1) {
        return
          "Generated autoinst.xml contains unexpected number of partitions with same mount path for"
          . $mount_path
          . "Found: "
          . scalar @nodes
          . ", expected: 1.";
    }
    ## Verify that value matches expectation
    for my $node (@nodes) {
        if ($node->to_literal ne $mount_opts) {
            return " Node value doesn't match mount options for $mount_path Expected : $mount_opts; Actual: " . $node->to_literal;
        }
    }

    return '';
}

1;
