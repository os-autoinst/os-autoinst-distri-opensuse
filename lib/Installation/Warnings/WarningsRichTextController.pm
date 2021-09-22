# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces business actions for rich text Warning Popups
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Warnings::WarningsRichTextController;
use strict;
use warnings;
use YuiRestClient;
use Installation::Warnings::ConfirmationWarningRichText;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{ConfirmationWarningRichText} = Installation::Warnings::ConfirmationWarningRichText->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_confirmation_warning_rich_text {
    my ($self) = @_;
    return $self->{ConfirmationWarningRichText};
}

sub get_text {
    my ($self) = @_;
    $self->get_confirmation_warning_rich_text->text();
}

sub accept_warning {
    my ($self) = @_;
    $self->get_confirmation_warning_rich_text->press_ok();
}

1;
