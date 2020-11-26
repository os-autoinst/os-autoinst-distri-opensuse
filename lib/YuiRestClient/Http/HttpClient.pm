# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient::Http::HttpClient;
use strict;
use warnings;

use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new;

sub http_get {
    my $url = Mojo::URL->new(shift);
    sleep(1);
    my $res = $ua->get($url)->result;
    return $res if $res->is_success;
    # Die if non OK response code
    die $res->message . "\n" . $res->body . "\n$url";
}

sub http_post {
    my $url = Mojo::URL->new(shift);
    sleep(1);
    my $res = $ua->post($url)->result;
    return $res if $res->is_success;
    # Die if non OK response code
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
