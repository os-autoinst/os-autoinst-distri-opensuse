# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient;
use strict;
use warnings;

use constant API_VERSION => 'v1';

use testapi;
use utils 'type_string_slow';
use YuiRestClient::App;

our $interval = 1;
our $timeout  = 10;
our $app;

sub set_interval {
    $interval = shift;
}

sub set_timeout {
    $timeout = shift;
}

sub set_app {
    $app = shift;
}

sub get_app {
    return $app;
}

sub wait_until {
    my (%args) = @_;
    $args{timeout}  //= $timeout;
    $args{interval} //= $interval;
    $args{message}  //= '';

    die "No object passed to the method" unless $args{object};

    my $counter = $args{timeout} / $args{interval};
    my $result;
    while ($counter--) {
        eval { $result = $args{object}->() };
        return $result if $result;
        sleep($interval);
    }

    my $error = "Timed out: @{[$args{message}]}\n";
    $error .= "\n$@" if $@;
    die $error;
}

sub setup_libyui {
    record_info('PORT',   "Used port for libyui: " . get_var('YUI_PORT'));
    record_info('SERVER', "Connecting to: " . get_var('YUI_SERVER'));
    assert_screen('startshell', timeout => 500);
    type_string_slow "extend libyui-rest-api\n";
    type_string_slow "exit\n";
    my $port = get_var('YUI_PORT');
    my $host = get_var('YUI_SERVER');
    my $app  = YuiRestClient::App->new({port => $port, host => $host});
    # As we start installer, REST API is not instantly available
    $app->connect(timeout => 500, interval => 10);
    set_app($app);
}

1;
