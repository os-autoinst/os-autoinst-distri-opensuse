# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Controller for firstboot page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Installer::InstallerController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Installer::GenericPage;
# use YaST::Installer::Firstboot::LanPage;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{GenericPage} = YaST::Installer::GenericPage->new({app => YuiRestClient::get_app()});
#    $self->{LanPage} = YaST::Firstboot::LanPage->new({app => YuiRestPage::get_app()});
    return $self;
} 

sub get_generic_page {
    my ($self) = @_;
    $self->{GenericPage};
}

sub get_lan_page {
    my ($self) = @_;
    $self->{LanPage};
}
    
# sub inst_lan {
#     my ($self) = @_;
#     $self->{GenericPage}->assert_page('Network_settings');
#     $self->get_lan_page->is_shown();
#     $self->{GenericPage}->press_next();
# }

sub check_and_skip_page {
    my ($self, $debug_label) = @_;
    $self->get_generic_page->assert_page($debug_label);
    $self->get_generic_page->press_next();
}

1;
