# SUSE's openQA tests

package YuiRestClient::Http::HttpClient;
use strict;
use warnings;

use Mojo::UserAgent;
use YuiRestClient::Logger;

my $ua = Mojo::UserAgent->new;

sub http_get {
    my (%args) = @_;
    $args{add_delay} //= 1;
    my $url = Mojo::URL->new($args{uri});
    sleep(1) if $args{add_delay};
    my $res = $ua->get($url)->result;
    return $res if $res->is_success;
    # Die if non OK response code
    YuiRestClient::Logger->get_instance()->error('Widget not found by url: ' . $url);
    die $res->message . "\n" . $res->body . "\n$url";
}

sub http_post {
    my (%args) = @_;
    $args{add_delay} //= 1;
    my $url = Mojo::URL->new($args{uri});
    sleep(1) if $args{add_delay};
    my $res = $ua->post($url)->result;
    return $res if $res->is_success;
    # Die if non OK response code
    YuiRestClient::Logger->get_instance()->error('Widget not found by url: ' . $url);
    die $res->message . "\n" . $res->body . "\n$url";
}

sub compose_uri {
    my (%args) = @_;
    $args{port} //= 80;

    my $url = Mojo::URL->new();
    $url->scheme('http');
    $url->host($args{host});
    $url->port($args{port});
    $url->path($args{path}) if $args{path};
    $url->query($args{params}) if $args{params};
    return $url;
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Http::HttpClient - Interface to the Rest API on the server 

=head1 COPYRIGHT

Copyright 2020 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

  my $response = YuiRestClient::Http::HttpClient::http_get($uri);
  my $response = YuiRestClient::Http::HttpClient::http_post($uri);
  my $uri = YuiRestClient::Http::HttpClient::compose_uri(
      host => $self->{host},
      port => $self->{port},
      path => $self->{api_version} . '/widgets',
      params => $args
  );

=head1 DESCRIPTION

=head2 Overview

Class to handle the HTTP traffic with the libYUI instance on the SUT. 
Uses Mojo::UserAgent for HTTP protocol. 

=head2 Class and object methods

B<http_get($url)> - perform a HTTP/GET to the specified URL

If the GET is successful (HTTP 200) then the data that was retrieved will be 
returned. If HTTP errors occur the method will log a "Widget not found by url" 
error message and then die with the error message returned by the server.

B<http_post($url)> - perform a HTTP/POST to the specified URL

If the POST is successful (HTTP 200) then the data that was retrieved will be 
returned. If HTTP errors occur the method will log a "Widget not found by url" 
error message and then die with the error message returned by the server.

B<compose_url(%args)> - compose an URL using the named parameter list 

This method uses a hash for a named parameter list. The following parameters can be used:

=over 4

=item * B<{port}> - the port number of the libYUI rest server, defaults to 80.

=item * B<{host}> - The host name or IP address of the libYUI server.

=item * B<{path}> - The access path. This is optional and can be omitted.

=item * B<{params}> - Query parameters that can be used. This is optional and can be omitted.

=back

With those parameters compose_url() will create an URL that looks like this:

http://{host}:{port}/{path}?{params}

=cut
