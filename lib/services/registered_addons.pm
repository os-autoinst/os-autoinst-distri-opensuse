# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
    if ($pro eq 'HPC') {
        $pro = 'SLE_' . $pro;
    }
    elsif ($pro eq 'SLES4SAP') {
        $pro = 'SLES_SAP';
    }
    suseconnect_ls($pro);
    my $ver = $system =~ s/\-SP/./r;
    script_run("SUSEConnect -s | grep " . $ver, die_on_timeout => 0);
}

sub check_registered_addons {
    my ($addonlist) = @_;
    $addonlist //= get_var('SCC_ADDONS');
    my @my_addons = grep { defined $_ && $_ } split(/,/, $addonlist);
    my @unique_addons = uniq @my_addons;
    foreach my $addon (@unique_addons) {
        $addon =~ s/(^\s+|\s+$)//g;
        my $name = get_addon_fullname($addon);
        $name = 'LTSS' if ($name =~ /LTSS/);
        $name = 'SLE_HPC-ESPOS' if ($name =~ /ESPOS/);
        next if ($name eq '');
        suseconnect_ls($name);
    }
}

sub check_upgraded_addons {
    my ($addonls) = @_;
    $addonls //= get_var('SCC_ADDONS');
    $addonls =~ s/ltss,?//g;
    # Check auto-select modules after migration base is <15 and upgrade system is 15+
    $addonls = $addonls . ",base,desktop,sdk,lgm,serverapp,wsm" if (is_sle('<15', get_var('HDDVERSION')) and is_sle('15+', get_var('VERSION')));
    check_registered_addons($addonls);
}

sub check_suseconnect {
    my $output = script_output("SUSEConnect -s", 120);
    my @out = grep { $_ =~ /identifier/ } split(/\n/, $output);
    @addons = ();
    if (@out) {
        my $json = Mojo::JSON::decode_json($out[0]);
        foreach (@$json) {
            my $iden = $_->{identifier};
            my $status = $_->{status};
            if ($iden eq 'sle-module-packagehub-subpackages') {
                record_soft_failure('bsc#1176901 - openQA test fails in system_prepare - \'sle-module-packagehub-subpackages\' is not registered ');
                next;
            }
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
        next if ($addons[$i] =~ /^SLE(S|D|_HPC|S_SAP)$|^sle-module-packagehub-subpackages$/);
        diag "$addons[$i]";
        die "$addons[$i] is not existed at SUSEConnect --list-extensions" if ($ls_out !~ /Deactivate(.*)$addons[$i]/);
        die "$addons[$i] is not existed at SUSEConnect --status-text" if ($status_out !~ /$addons[$i]/);
    }
}

sub full_registered_check {
    my (%hash) = @_;
    my $stage = $hash{stage};
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
