# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package hacluster;
use base 'opensusebasetest';
use testapi;
use autotest;
use lockapi;
use strict;

# Check if we are on $node_number
sub is_node {
    my ($self, $node_number) = @_;

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Return true if HOSTNAME contains $node_number at his end
    return (get_var('HOSTNAME') =~ /$node_number$/);
}

# Check if we are on $node_number
sub choose_node {
    my ($self, $node_number) = @_;
    my $tmp_hostname = get_var('HOSTNAME');

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Replace the digit of HOSTNAME to create the new hostname
    $tmp_hostname =~ s/([a-z]*).*$/$1$node_number/;

    # And return it
    return ($tmp_hostname);
}

# Return the cluster name
sub cluster_name {
    return get_var('CLUSTER_NAME');
}

# Print the state of the cluster and do a screenshot
sub save_state {
    type_string "crm_mon -R -1\n";
    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;
    # clear screen to make screen content ready for next test
    #    $self->clear_and_verify_console;
}

1;
# vim: set sw=4 et:
