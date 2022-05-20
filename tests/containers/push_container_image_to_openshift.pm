# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Push a container image to the Google Cloud Registry
#
# Maintainer: Ivan Lausuch <ilausuch@suse.com>, qa-c team <qa-c@suse.de>

# use Mojo::Base 'publiccloud::basetest';
use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
# use containers::urls 'get_image_uri';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $url = get_required_var('CONTAINER_OC_BINARY_URL');
    assert_script_run("wget --no-check-certificate $url");
    assert_script_run('ls -lh');
}

# sub post_fail_hook {
#     my ($self) = @_;
# }

# sub post_run_hook {
#     my ($self) = @_;
# }

# sub test_flags {
# }

1;
