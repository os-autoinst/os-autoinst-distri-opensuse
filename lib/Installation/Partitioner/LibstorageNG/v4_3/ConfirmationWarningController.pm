# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for handling confirmation warnings
# in Expert Partitioner.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Partitioner::LibstorageNG::v4_3::ConfirmationWarningController;
use strict;
use warnings;
use YuiRestClient;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{ConfirmationWarning} = Installation::Partitioner::LibstorageNG::v4_3::ConfirmationWarning->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_confirmation_warning {
    my ($self) = @_;
    return $self->{ConfirmationWarning};
}

sub confirm_only_use_if_familiar {
    my ($self) = @_;
    $self->get_confirmation_warning()->confirm_only_use_if_familiar();
}

sub confirm_delete_partition {
    my ($self, $partition) = @_;
    $self->get_confirmation_warning()->confirm_delete_partition($partition);
}

sub confirm_delete_volume_group {
    my ($self, $vg) = @_;
    $self->get_confirmation_warning()->confirm_delete_volume_group($vg);
}

1;
