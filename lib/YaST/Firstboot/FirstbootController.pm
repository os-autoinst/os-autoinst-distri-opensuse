# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Controller for firstboot wizard.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::FirstbootController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Firstboot::GenericPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{GenericPage} = YaST::Firstboot::GenericPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_generic_page {
    my ($self) = @_;
    $self->{GenericPage};
}

sub press_next {
    my ($self) = @_;
    $self->get_generic_page->press_next();
}

1;
