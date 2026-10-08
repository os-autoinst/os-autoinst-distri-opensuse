# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: common functions for FIPS web browser tests
# Maintainer: QE Security <none@suse.de>

package web_browser;

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use registration qw(add_suseconnect_product register_product);

our @EXPORT = qw(
  setup_web_browser_env
  run_web_browser_text_based
);

=head1 WEB_BROWSER

=head1 SYNOPSIS

 use lib::web_browser;

=cut

=head2 setup_web_brwoser_env

 setup_web_browser_env();

Setup test envs: register PackageHub and check FIPS pattern installed

=cut

sub setup_web_browser_env {
    my $ret = 0;

    if (is_sle) {
        # Check the register status for reference
        script_run("SUSEConnect --list-extension | grep 'SUSE Package Hub' | grep '(Activated)'");
        $ret = script_run("output=`SUSEConnect -s | grep 'PackageHub'`; echo \${output##*PackageHub} | cut -d ':' -f4 | grep 'Registered'");
        # Workaround: in some cases extensions may be in false "Activated" status,
        # then just re-register it and do not check the return value
        if ($ret ne 0) {
            register_product();
            my $version = get_required_var('VERSION') =~ s/([0-9]+)-SP([0-9]+)/$1.$2/r;
            my $arch = get_required_var('ARCH');
            script_run("SUSEConnect -d -p PackageHub/$version/$arch", 300);
            script_run("SUSEConnect -p PackageHub/$version/$arch", 300);
        }
    }
}

=head2 run_web_browser_text_based

 run_web_browser_text_based($browser, $options);

Run text based web browser with options
$browser: The name of text based web browser: w3m/links/lynx
$options: command line options

=cut

sub run_web_browser_text_based {
    my ($browser, $options) = @_;

    my %https_url = (
        tuta => "https://tuta.com/",
        suse => "https://www.suse.com/",
    );

    for my $p (keys %https_url) {
        enter_cmd "clear";

        if ($browser ne "links") {
            validate_script_output("$browser $options $https_url{$p}", sub { m/.*200 OK.*(?i)Strict-Transport-Security.*/s });
        } else {
            my $output_file = "webpage.txt";
            assert_script_run "$browser $options $https_url{$p} > $output_file";
            assert_script_run "grep -i $p $output_file";
            script_run "rm $output_file";
        }
    }
}

1;
