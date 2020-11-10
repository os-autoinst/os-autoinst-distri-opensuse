# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::App;
use strict;
use warnings;

use YuiRestClient;
use YuiRestClient::Http::HttpClient;
use YuiRestClient::Http::WidgetController;
use YuiRestClient::Widget::Button;
use YuiRestClient::Widget::MenuCollection;
use YuiRestClient::Widget::Table;
use YuiRestClient::Widget::Tree;

sub new {
    my ($class, $args) = @_;

    return bless {
        port              => $args->{port},
        host              => $args->{host},
        widget_controller =>
          YuiRestClient::Http::WidgetController->new({
                port => $args->{port}, host => $args->{host}
          })
    }, $class;
}

sub connect {
    my ($self, %args) = @_;
    my $uri = YuiRestClient::Http::HttpClient::compose_uri(host => $self->{host}, port => $self->{port});
    YuiRestClient::wait_until(object => sub {
            my $response = YuiRestClient::Http::HttpClient::http_get($uri);
            return 1 if $response;
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

sub table {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::Table->new({
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

sub menucollection {
    my ($self, $filter) = @_;
    return YuiRestClient::Widget::MenuCollection->new({
            widget_controller => $self->{widget_controller},
            filter            => $filter
    });
}

1;
