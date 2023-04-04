# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for apache2 service tests
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package services::apache;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;
use version_utils 'is_sle';

sub install_service {
    my $apache = get_var('APACHE2_PKG', "apache2");
    zypper_call("in $apache $apache-utils");
}

sub enable_service {
    systemctl 'enable apache2';
}

sub start_service {
    systemctl 'start apache2';
}

# check service is running and enabled
sub check_service {
    systemctl 'is-enabled apache2.service';
    systemctl 'is-active apache2';
}

# check httpd function
sub check_function {
    # verify httpd serves index.html
    enter_cmd "echo Lorem ipsum dolor sit amet > /srv/www/htdocs/index.html";
    assert_script_run(
        "curl -f http://localhost/ | grep 'Lorem ipsum dolor sit amet'",
        timeout => 90,
        fail_message => 'Could not access local apache2 instance'
    );
}

# check apache service before and after migration
# stage is 'before' or 'after' system migration.
sub full_apache_check {
    my (%hash) = @_;
    my $stage = $hash{stage};
    my $type = $hash{service_type};
    my $pkg = $hash{srv_pkg_name};
    if ($stage eq 'before') {
        install_service();
        common_service_action($pkg, $type, 'enable');
        common_service_action($pkg, $type, 'start');
    }
    common_service_action($pkg, $type, 'is-enabled');
    common_service_action($pkg, $type, 'is-active');
    check_function();
}

1;
