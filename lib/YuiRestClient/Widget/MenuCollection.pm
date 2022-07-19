# SUSE's openQA tests

package YuiRestClient::Widget::MenuCollection;

use strict;
use warnings;

use parent 'YuiRestClient::Widget::Base';
use YuiRestClient::Action;

sub select {
    my ($self, $path) = @_;

    $self->action(action => YuiRestClient::Action::YUI_SELECT, value => $path);

    return $self;
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Widget::MenuCollection - handle YMenuButton, YMenuBar

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE YaST <qa-sle-yast@suse.de>

=head1 SYNOPSIS

$self->{menu_btn_add}->select('&From List');

=head1 DESCRIPTION

=head2 Overview

Selects menu items by using their menu path description.

      {
        "class": "YMenuButton",
        "debug_label": "test",
        "icon_base_path": "",
        "id": "test_id",
        "items": [
          {
            "label": "button1"
          },
          {
            "label": "button2"
          },
          {
            "label": "button3"
          }
        ],
        "items_count": 3,
        "label": "button group"
        }

=head2 Class and object methods

B<select($path)> - select menu item specified by path

Path descriptions can be strings like '&From List' or '&File|Open File...' for 
nested menu items.

=cut
