# SUSE's openQA tests

package YuiRestClient::Action;

use strict;
use warnings;

use constant {
    YUI_PRESS => 'press',
    YUI_TOGGLE => 'toggle',
    YUI_CHECK => 'check',
    YUI_UNCHECK => 'uncheck',
    YUI_SELECT => 'select',
    YUI_ENTER_TEXT => 'enter_text'
};

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Action - Define actions for widgets 

=head1 COPYRIGHT

Copyright 2020  SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 DESCRIPTION

=head2 Overview

This class defines constants to use for actions:

=over 4

=item * YUI_PRESS      - action to press a button

=item * YUI_TOGGLE     - action to toggle a checkbox

=item * YUI_CHECK      - action to check a checkbox

=item * YUI_UNCHECK    - action to uncheck a checkbox

=item * YUI_SELECT     - action to select an item

=item * YUI_ENTER_TEXT - action to enter text

=back

=cut
