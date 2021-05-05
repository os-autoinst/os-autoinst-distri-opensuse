# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::App;
use strict;
use warnings;

use YuiRestClient::Http::HttpClient;
use YuiRestClient::Http::WidgetController;
use YuiRestClient::Wait;
use YuiRestClient::Widget::Button;
use YuiRestClient::Widget::CheckBox;
use YuiRestClient::Widget::ComboBox;
use YuiRestClient::Widget::Label;
use YuiRestClient::Widget::MenuCollection;
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
        port              => $args->{port},
        host              => $args->{host},
        api_version       => $args->{api_version},
        timeout           => $args->{timeout},
        interval          => $args->{interval},
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
    YuiRestClient::Wait::wait_until(object => sub {
            my $response = YuiRestClient::Http::HttpClient::http_get($uri);
            return $response->json if $response;
        },
        message => "Connection to YUI REST server failed",
        %args);
}

sub button {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Button->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub checkbox {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::CheckBox->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub combobox {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::ComboBox->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub itemselector {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::ItemSelector->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub label {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Label->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub menucollection {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::MenuCollection->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub radiobutton {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::RadioButton->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub richtext {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::RichText->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub selectionbox {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::SelectionBox->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub table {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Table->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub textbox {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Textbox->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub tree {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Tree->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

sub tab {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Tab->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}


1;
