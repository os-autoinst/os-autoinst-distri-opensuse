# SUSE's openQA tests

package YuiRestClient::Sanitizer;
use strict;
use warnings;

sub sanitize {
    my ($item) = shift;
    # remove shortcut
    $item =~ s/&//;
    return $item;
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Sanitizer - remove '&' from labels

=head1 COPYRIGHT

Copyright 2021 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

 $item = '&OK';
 $item = YuiRestClient::Sanitizer::sanitize($item); 

=head1 DESCRIPTION

=head2 Overview

This method removes the '&' from widget labels. The '&' is used in
UI widgets to mark the hot key that is assigned to the widget,
for example '&OK' to label an OK button.

=head2 Class and object methods 

B<sanitize($item)> - remove first '&' from item. 

=cut
