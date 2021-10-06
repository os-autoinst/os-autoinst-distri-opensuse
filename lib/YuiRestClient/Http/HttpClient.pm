# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Http::HttpClient;
use strict;
use warnings;

use Mojo::UserAgent;
use YuiRestClient::Logger;

my $ua = Mojo::UserAgent->new;

sub http_get {
    my $url = Mojo::URL->new(shift);
    sleep(1);
    my $res = $ua->get($url)->result;
    return $res if $res->is_success;
    # Die if non OK response code
    YuiRestClient::Logger->get_instance()->error('Widget not found by url: ' . $url);
    die $res->message . "\n" . $res->body . "\n$url";
}

sub http_post {
    my $url = Mojo::URL->new(shift);
    sleep(1);
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
    $url->path($args{path})    if $args{path};
    $url->query($args{params}) if $args{params};
    return $url;
}
