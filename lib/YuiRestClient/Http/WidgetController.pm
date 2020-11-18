# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Http::WidgetController;
use strict;
use warnings;

use YuiRestClient;
use YuiRestClient::Wait;
use YuiRestClient::Http::HttpClient;

sub new {
    my ($class, $args) = @_;

    return bless {
        host => $args->{host},
        port => $args->{port},
    }, $class;
}

sub find {
    my ($self, $args) = @_;

    my $uri = YuiRestClient::Http::HttpClient::compose_uri(
        host   => $self->{host},
        port   => $self->{port},
        path   => YuiRestClient::API_VERSION . '/widgets',
        params => $args
    );

    YuiRestClient::Wait::wait_until(object => sub {
            my $response = YuiRestClient::Http::HttpClient::http_get($uri);
            return $response->json if $response; }
    );
}

sub send_action {
    my ($self, $args) = @_;

    my $uri = YuiRestClient::Http::HttpClient::compose_uri(
        host   => $self->{host},
        port   => $self->{port},
        path   => YuiRestClient::API_VERSION . '/widgets',
        params => $args
    );

    YuiRestClient::Wait::wait_until(object => sub {
            my $response = YuiRestClient::Http::HttpClient::http_post($uri);
            return $response if $response; }
    );
}

1;
