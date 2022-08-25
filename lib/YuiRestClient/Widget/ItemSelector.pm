# SUSE's openQA tests

package YuiRestClient::Widget::ItemSelector;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;
use YuiRestClient::Sanitizer;

sub select {
    my ($self, $item) = @_;
    my $items = $self->property('items');
    ($item) = grep { YuiRestClient::Sanitizer::sanitize($_) eq $item } map { $_->{label} } @{$items};
    return $self->action(action => YuiRestClient::Action::YUI_SELECT, value => $item);
}

sub selected_items {
    my ($self) = @_;
    my $items = $self->property('items');
    return map { YuiRestClient::Sanitizer::sanitize($_->{label}) } grep { $_->{selected} } @{$items};
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::ItemSelector - handle item selectors

=head1 COPYRIGHT

Copyright 2021 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE YaST <qa-sle-yast@suse.de>

=head1 SYNOPSIS

$self->{rb_skip_registration}->select();
$self->{cb_chunk_size}->select($chunk_size);

return $self->{sel_role}->selected_items();

=head1 DESCRIPTION

=head2 Overview

This class provides methods to select items like radio buttons
or dropdown lists and to read out the current selection.

=head2 Class and object methods 

B<select($item)> - selects an item

If the class object is a radio button then $item can be omitted. If the object is
a multi-selector object you need to provide $item to specify what selection to make.

B<selected_items()> - get a list of selected items

This method returns an array with all the (sanitized) labels of items that are selected in the
current class object. 

=cut
