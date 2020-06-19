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
use List::MoreUtils 'uniq';

my @addons;

sub suseconnect_ls {
    my ($search) = @_;
    $search //= '';
    die "$search is not registered" unless (grep(/^$search$/, @addons));
}

sub check_registered_system {
    my ($system) = @_;
    my $pro = uc get_var('SLE_PRODUCT');
    $pro = 'SLE_' . $pro if ($pro eq 'HPC');
    suseconnect_ls($pro);
    my $ver = $system =~ s/\-SP/./r;
    script_run("SUSEConnect -s | grep " . $ver);
}

sub check_registered_addons {
    my ($addonlist) = @_;
    $addonlist //= get_var('SCC_ADDONS');
    my @my_addons     = grep { defined $_ && $_ } split(/,/, $addonlist);
    my @unique_addons = uniq @my_addons;
    foreach my $addon (@unique_addons) {
        $addon =~ s/(^\s+|\s+$)//g;
        my $name = get_addon_fullname($addon);
        $name = 'LTSS' if ($name =~ /LTSS/);
        next if ($name eq '');
        suseconnect_ls($name);
    }
}

sub check_upgraded_addons {
    my ($addonls) = @_;
    $addonls //= get_var('SCC_ADDONS');
    $addonls =~ s/ltss,?//g;
    # Check auto-select modules after migration base is <15 and upgrade system is 15+
    $addonls = $addonls . ",base,desktop,sdk,lgm,python2,serverapp,wsm" if (is_sle('<15', get_var('HDDVERSION')) and is_sle('15+', get_var('VERSION')));
    check_registered_addons($addonls);
}

sub check_suseconnect {
    my $output = script_output("SUSEConnect -s", 120);
    my @out    = grep { $_ =~ /identifier/ } split(/\n/, $output);
    @addons = ();
    if (@out) {
        my $json = Mojo::JSON::decode_json($out[0]);
        foreach (@$json) {
            my $iden   = $_->{identifier};
            my $status = $_->{status};
            push(@addons, $iden);
            die "$iden register status is: $status" if ($status ne 'Registered');
        }
    }
    else {
        die "Cannot get register status: $output";
    }
    diag "@addons";
}

sub check_suseconnect_cmd {
    my $ls_out = script_output("SUSEConnect --list-extensions", 120);
    diag "$ls_out";
    my $status_out = script_output("SUSEConnect --status-text", 120);
    diag "$status_out";
    for (my $i = 0; $i < @addons; $i = $i + 1) {
        next if ($addons[$i] =~ /^SLE(S|D|_HPC)$/);
        diag "$addons[$i]";
        die "$addons[$i] is not existed at SUSEConnect --list-extensions" if ($ls_out     !~ /Deactivate(.*)$addons[$i]/);
        die "$addons[$i] is not existed at SUSEConnect --status-text"     if ($status_out !~ /$addons[$i]/);
    }
}

sub full_registered_check {
    my ($stage) = @_;
    $stage //= '';
    check_suseconnect();
    check_suseconnect_cmd();
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
