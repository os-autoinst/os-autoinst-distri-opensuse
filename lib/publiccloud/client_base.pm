# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base helper class for public cloud connection clients
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::client_base;
use Mojo::Base -base;
use testapi;

# Reference to a list of all regions specified via job variable/settings
# At least one region is present from PUBLIC_CLOUD_REGION
has _regions => sub {
    my @list = (get_required_var('PUBLIC_CLOUD_REGION'));
    if (my $alt = get_var('PUBLIC_CLOUD_ALTERNATE_REGIONS')) {
        push @list, split(/\s*,\s*/, $alt);
    }
    return \@list;
};

# List of regions blacklisted by the user during the test execution.
# The default must be a coderef (sub { {} }) and NOT a bare hashref ({}).
# A bare {} is evaluated once at compile time and shared across all instances,
# so blacklisting a region on one object would corrupt every other object.
# Wrapping in sub {} makes Mojo::Base call it fresh for each new instance,
# giving every object its own independent hash.
has _blacklisted_regions => sub { {} };

# Setter for the blacklist. The test code can call this function
# to add a region name to the blacklis; it usually happens
# when a terraform deployment fails for a specific error.
sub blacklist_region {
    my ($self, $region) = @_;
    $self->_blacklisted_regions->{$region} = 1;
    return $self;    # allows chaining
}

# Getter, return the first not blacklisted region or die
sub region {
    my ($self) = @_;
    my $blacklist = $self->_blacklisted_regions;
    for my $r (@{$self->_regions}) {
        return $r unless $blacklist->{$r};
    }
    die "No available regions — all blacklisted: " . join(', ', @{$self->_regions});
}

1;
