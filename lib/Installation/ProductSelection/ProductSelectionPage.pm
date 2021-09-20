# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Handles Product Selection page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ProductSelection::ProductSelectionPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{rb_SLES}         = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Linux Enterprise Server 15/});
    $self->{rb_HPC}          = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Linux Enterprise High Performance Computing 15/});
    $self->{rb_SLES_for_SAP} = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Linux Enterprise Server for SAP Applications 15/});
    $self->{rb_SLED}         = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Linux Enterprise Desktop 15/});
    $self->{rb_SMGR_Server}  = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Manager Server/});
    $self->{rb_SMGR_Proxy}   = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Manager Proxy/});
    $self->{rb_SMGR_Retail}  = $self->{app}->radiobutton({type => 'YRadioButton', label => qr/SUSE Manager Retail Branch Server/});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rb_SLES}->exist();
}

sub install_product {
    my ($self, $product) = @_;
    $self->{"rb_$product"}->select();
}

1;
