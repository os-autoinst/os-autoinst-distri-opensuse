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

# List of disallowed regions during the test execution.
# The default must be a coderef (sub { {} }) and NOT a bare hashref ({}).
# A bare {} is evaluated once at compile time and shared across all instances,
# so disabling a region on one object would corrupt every other object.
# Wrapping in sub {} makes Mojo::Base call it fresh for each new instance,
# giving every object its own independent hash.
has _disallowed_regions => sub { {} };

# Setter for the _dissallowed_regions. The test code can call this function
# to add a region name to the disallowed list; it usually happens
# when a terraform deployment fails for a specific error.
sub disable_region {
    my ($self, $region) = @_;
    $self->_disallowed_regions->{$region} = 1;
    return $self;    # allows chaining
}

# Getter, return the first not disallowed region or die
sub region {
    my ($self) = @_;
    for my $r (@{$self->_regions}) {
        return $r unless $self->_disallowed_regions->{$r};
    }
    die "No available regions — all disabled: " . join(', ', @{$self->_regions});
}

1;
