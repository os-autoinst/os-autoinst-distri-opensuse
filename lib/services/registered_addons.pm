# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check registered system and addons status
#
# Maintainer: Yutao Wang <yuwang@suse.com>

package services::registered_addons;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;
use version_utils 'is_sle';
use registration 'get_addon_fullname';
use Mojo::JSON;

sub zypper_lr {
    my ($search) = @_;
    $search //= '';
    my $output;
    if ($search ne '') {
        $output = script_output("zypper lr --uri | grep -i " . $search);
    }
    else {
        $output = script_output("zypper lr --uri");
    }
    diag("zypper lr output: " . $output);
}

sub check_registered_system {
    my ($system) = @_;
    my $version = get_var('SLE_PRODUCT') . $system;
    zypper_lr($version);
}

sub check_registered_addons {
    my ($addonlist) = @_;
    $addonlist //= get_var('SCC_ADDONS');
    my @addons = grep { defined $_ && $_ } split(/,/, $addonlist);
    foreach my $addon (@addons) {
        $addon =~ s/(^\s+|\s+$)//g;
        my $name = get_addon_fullname($addon);
        $name = 'LTSS' if ($name =~ /LTSS/);
        zypper_lr($name);
        # If has WE addon, need check nvidia repo
        zypper_lr('NVIDIA') if ($name =~ /sle-we/);
    }
}

sub check_upgraded_addons {
    my ($addonls) = @_;
    $addonls //= get_var('SCC_ADDONS');
    $addonls =~ s/ltss,?//g;
    # Check auto-select modules after migration only for sle15-sp1
    $addonls = $addonls . ",base,desktop,sdk,lgm,python2,serverapp,wsm" if (is_sle('=15-sp1'));
    check_registered_addons($addonls);
}

sub check_suseconnect {
    my $output = script_output("SUSEConnect -s", 120);
    my @out = grep { $_ =~ /identifier/ } split(/\n/, $output);
    if (@out) {
        my $json = Mojo::JSON::decode_json($out[0]);
        foreach (@$json) {
            my $iden   = $_->{identifier};
            my $status = $_->{status};
            die "$iden register status is: $status" if ($status ne 'Registered');
        }
    }
    else {
        die "Cannot get register status: $output";
    }
}

sub full_registered_check {
    my ($stage) = @_;
    $stage //= '';
    check_suseconnect();
    zypper_lr();
    if ($stage eq 'before') {
        check_registered_system(get_var('ORIGIN_SYSTEM_VERSION'));
        check_registered_addons();
    }
    else {
        check_registered_system(get_var('VERSION'));
        check_upgraded_addons();
    }
}

1;
