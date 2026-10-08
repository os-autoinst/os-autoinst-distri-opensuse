# SUSE's openQA tests

package YuiRestClient::App;
use strict;
use warnings;

use YuiRestClient::Filter;
use YuiRestClient::Http::HttpClient;
use YuiRestClient::Http::WidgetController;
use YuiRestClient::Wait;

use YuiRestClient::Widget::Button;
use YuiRestClient::Widget::CheckBox;
use YuiRestClient::Widget::ComboBox;
use YuiRestClient::Widget::Label;
use YuiRestClient::Widget::MenuCollection;
use YuiRestClient::Widget::ProgressBar;
use YuiRestClient::Widget::RadioButton;
use YuiRestClient::Widget::RichText;
use YuiRestClient::Widget::SelectionBox;
use YuiRestClient::Widget::ItemSelector;
use YuiRestClient::Widget::Table;
use YuiRestClient::Widget::Textbox;
use YuiRestClient::Widget::Tree;
use YuiRestClient::Widget::Tab;

sub new {
    my ($class, $args) = @_;

    return bless {
        port => $args->{port},
        host => $args->{host},
        api_version => $args->{api_version},
        timeout => $args->{timeout},
        interval => $args->{interval},
        widget_controller =>
          YuiRestClient::Http::WidgetController->new($args)
    }, $class;
}

sub get_widget_controller {
    my ($self) = @_;
    return $self->{widget_controller};
}

sub get_port {
    my ($self) = @_;
    return $self->{port};
}

sub get_host {
    my ($self) = @_;
    return $self->{host};
}

sub check_connection {
    my ($self, %args) = @_;
    my $uri = YuiRestClient::Http::HttpClient::compose_uri(
        host => $self->{host},
        port => $self->{port},
        path => $self->{api_version} . '/widgets');

    YuiRestClient::Logger->get_instance()->debug("Check connection to the app by url: $uri");
    YuiRestClient::Wait::wait_until(object => sub {
            my $response = YuiRestClient::Http::HttpClient::http_get(uri => $uri);
            return $response->json if $response;
        },
        message => "Connection to YUI REST server failed",
        %args);
}

sub button {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Button->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub checkbox {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::CheckBox->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub combobox {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::ComboBox->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub itemselector {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::ItemSelector->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub label {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Label->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub menucollection {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::MenuCollection->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub progressbar {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::ProgressBar->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub radiobutton {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::RadioButton->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub richtext {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::RichText->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub selectionbox {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::SelectionBox->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub table {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Table->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub textbox {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Textbox->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub tree {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Tree->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

sub tab {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Tab->new({
            widget_controller => $self->{widget_controller},
            filter => YuiRestClient::Filter->new($filter)
    });
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::App - Class to create a UI widget object

=head1 COPYRIGHT

Copyright 2021 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS
  
   $app = YuiRestClient::App->new({
            port        => $port,
            host        => $host,
            api_version => API_VERSION,
            timeout     => $timeout,
            interval    => $interval});
   $app->get_widget_controller()->set_host($yuihost);
   $app->get_widget_controller()->set_host($yuiport); 
   YuiRestClient::get_app()->check_connection(); 
   $self->{btn_guided_setup} = $self->{app}->button({id => 'guided'});       
   $self->{ch_autologin} = $self->{app}->checkbox({id => 'autologin'});
   $self->{cb_filesystem}       = $self->{app}->combobox({id => '"Y2Partitioner::Widgets::BlkDeviceFilesystem"'});
   $self->{isel_keyboard_layout} = $self->{app}->itemselector({id => 'layout_list'});
   $self->{lbl_settings_root_part} = $self->{app}->label({label => 'Settings for the Root Partition'});
   $self->{menu_btn_add} = $self->{app}->menucollection({label => 'Add...'});
   $self->{rb_operating_system} = $self->{app}->radiobutton({id => 'system'});
   $self->{txt_overview} = $self->{app}->richtext({id => 'proposal'});
   $self->{lst_target_disks} = $self->{app}->selectionbox({
            id => '"Y2Partitioner::Dialogs::PartitionTableClone::DevicesSelector"'
    });
   $self->{tbl_available_devices} = $self->{app}->table({id => '"unselected"'});
   $self->{tb_password} = $self->{app}->textbox({id => 'pw1'});
   $self->{tree_system_view}       = $self->{app}->tree({id => '"Y2Partitioner::Widgets::OverviewTree"'});
   $self->{tab_cwm} = $self->{app}->tab({id => '_cwm_tab'});

=head1 DESCRIPTION

=head2 Overview

This class is a generic representation of the UI widget tree. The 
class is using the WidgetController class to communicate with the 
REST-Server and is providing methods to create 'handles' for the 
various UI elements (buttons, checkboxes, text etc.).

=head2 Class and object methods

Class attributes:

=over 4

=item B<{api_version}> - The version of the YUI Rest API

=item B<{host}> - The hostname or IP of the REST server

=item B<{port}> - The port of the REST server

=item B<{timeout}> - The timeout for communication with the server

=item B<{interval}> - Interval time to try to reach the server

=item B<{widget_controller}> - The instance of the widget controller to communicate with the server

=back

Class methods:

A: Methods for communicating with the REST server

B<new(%args)> - create new app

The argument %args is a hash of named parameters C<{port}>, C<{host}>, C<{api_version}>, C<{timeout}> and
C<{interval}>. With this the constructor creates a WidgetController.

B<get_widget_controller()> - Get reference to the widget controller assigned to 
the instance of app.

B<get_port()> - get port used for the communication with the REST server

B<get_host()> - get name or IP address for communication with REST server

B<check_connection()> - checks if connection to REST server is working

B: Methods for creating references to UI objects

All these methods have in common that the method name describes what kind 
of UI object is referenced. Every method has an argument $filter which 
describes the identification of the UI element.

B<button($filter)> - creates reference to a button

B<checkbox($filter)> - creates a reference to a checkbox

B<combobox($filter)> - creates a reference to a combobox

B<itemselector($filter)> - creates a reference to an itemselector

B<label($filter)> - creates a reference to a label

B<menucollection($filter)> - creates a reference to a menucollection

B<radiobutton($filter)> - creates a reference to a radiobutton

B<richttext($filter)> - creates a reference to a richtext

B<selectionbox($filter)> - creates a reference to a selectionbox

B<table($filter)> - creates a reference to a table

B<textbox($filter)> - creates a reference to a textbox

B<tree($filter)> - creates a reference to a tree

B<tab($filter)> - creates a reference to a tab

=cut
