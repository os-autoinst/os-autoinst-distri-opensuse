# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for Warning Popups
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Popups::PopupController;
use strict;
use warnings;
use YuiRestClient;
use Installation::Popups::OkPopup;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{Popup} = Installation::Popups::OkPopup->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_popup {
    my ($self) = @_;
    return $self->{Popup};
}

sub get_text {
    my ($self) = @_;
    $self->get_popup->text();
}

sub accept {
    my ($self) = @_;
    $self->get_popup->press_ok();
}

1;
