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

sub teardown_libyui {
    assert_screen('startshell', timeout => 100);
    type_string "exit\n";
}

sub is_libyui_rest_api {
    return get_var('YUI_REST_API');
}

1;
