# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add new add-owns using maintenance test repo URLs.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub create_repo_name {
    my ($repo_id, $addon) = $_[0] =~ (/(\d+)\/(.*)\//);
    my $name = $addon . "_" . $repo_id;
    return $name;
}

sub run {
    my @repos = split(/,/, get_var('MAINT_TEST_REPO'));

    $testapi::distri->get_add_on_product()->confirm_like_additional_add_on();

    my $maintrepo = shift @repos;
    my $reponame = create_repo_name($maintrepo);
    $testapi::distri->get_add_on_product()->accept_current_media_type_selection();
    save_screenshot;
    $testapi::distri->get_repository_url()->add_repo({url => $maintrepo, name => $reponame});
    save_screenshot;

    for my $repo (@repos) {
        $testapi::distri->get_add_on_product_installation()->add_add_on_product();
        $testapi::distri->get_add_on_product()->accept_current_media_type_selection();
        my $name = create_repo_name($repo);
        $testapi::distri->get_repository_url()->add_repo({url => $repo, name => $name});
        save_screenshot;
    }
    $testapi::distri->get_add_on_product_installation()->accept_add_on_products();
}

1;
