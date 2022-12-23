# SUSE's openQA tests

package YuiRestClient::Http::WidgetController;
use strict;
use warnings;

use YuiRestClient::Logger;
use YuiRestClient::Wait;
use YuiRestClient::Http::HttpClient;

sub new {
    my ($class, $args) = @_;

    return bless {
        api_version => $args->{api_version},
        host => $args->{host},
        port => $args->{port},
        timeout => $args->{timeout},
        interval => $args->{interval}
    }, $class;
}

sub set_timeout {
    my ($self, $timeout) = @_;
    $self->{timeout} = $timeout;
}

sub set_interval {
    my ($self, $interval) = @_;
    $self->{interval} = $interval;
}

sub set_host {
    my ($self, $host) = @_;
    $self->{host} = $host;
}

sub set_port {
    my ($self, $port) = @_;
    $self->{port} = $port;
}

sub find {
    my ($self, $args) = @_;
    my $timeout = $args->{timeout} // $self->{timeout};
    my $interval = $args->{interval} // $self->{interval};

    my $uri = YuiRestClient::Http::HttpClient::compose_uri(
        host => $self->{host},
        port => $self->{port},
        path => $self->{api_version} . '/widgets',
        params => $args->{filter}
    );

    YuiRestClient::Logger->get_instance()->debug('Finding widget by url: ' . $uri);

    YuiRestClient::Wait::wait_until(object => sub {
            my $response = YuiRestClient::Http::HttpClient::http_get(
                uri => $uri, add_delay => $timeout);
            return $response->json if $response; },
        timeout => $timeout,
        interval => $interval
    );
}

sub send_action {
    my ($self, $args) = @_;
    my $timeout = $args->{timeout} // $self->{timeout};
    my $interval = $args->{interval} // $self->{interval};

    my $uri = YuiRestClient::Http::HttpClient::compose_uri(
        host => $self->{host},
        port => $self->{port},
        path => $self->{api_version} . '/widgets',
        params => $args
    );

    YuiRestClient::Logger->get_instance()->debug('Sending action to widget by url: ' . $uri);

    YuiRestClient::Wait::wait_until(object => sub {
            my $response = YuiRestClient::Http::HttpClient::http_post(
                uri => $uri, add_delay => $timeout);
            return $response if $response; },
        timeout => $timeout,
        interval => $interval
    );
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Http::WidgetController - Class to communicate with the REST server

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

  return $self->{widget_controller}->find($self->{filter}->get_filter());
  $self->{widget_controller}->send_action($params);

=head1 DESCRIPTION

=head2 Overview

A class that provides a controller to retrieve widgets from the REST server
or send actions to the server.

=head2 Class and object methods

Class attributes:

=over 4

=item B<{api_version}> - The version of the YUI Rest API

=item B<{host}> - The hostname or IP of the REST server

=item B<{port}> - The port of the REST server

=item B<{timeout}> - The timeout for communication with the server

=item B<{interval}> - Interval time to try to reach the server

=back

Class methods:

B<new($args)> - create a new WidgetController instance

Arguments in $args use the same names as the class attributes described above.

B<set_timeout($timeout)> - change timeout setting

Allows adjustments of timeout settings after the instance is created.

B<set_interval($interval> - change interval time

Allows adjustments to the interval time after the instance is created.

B<set_host()> - change host name or IP address

Allows adjustments to the host parameter after the instance is created.

B<set_port()> - changes the port

Allows adjustments to the port number after the instance is created.

B<find($args)> - retrieve JSON data for UI widget

The widget is defined by $args. Args is a hash that identifies a widget.
The JSON data is retrieved using http_get() from Http::HttpClient.

B<send_action($args)> - sends action to an UI widget

The widget is defined by $args. Args is a hash that identifies the widget.
The action is submitted to the server by using http_post() from Http::HttpClient.

=cut
