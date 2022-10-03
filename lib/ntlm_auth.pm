# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic variable setting for ntlm auth installer
# Maintainer: QE Security <none@suse.de>

package ntlm_auth;

use base Exporter;

use strict;
use warnings;
use testapi;
use utils;

our @EXPORT = qw(
  $ntlm_user
  $ntlm_paswd
  $proxy_server
  $listen_port
  $ntlm_proxy
);

if (get_var("NTLM_AUTH_INSTALL")) {
    our $ntlm_user = get_required_var("NTLM_USER");
    our $ntlm_paswd = get_required_var("NTLM_PASSWD");
    our $proxy_server = get_required_var("PROXY_SERVER");
    our $listen_port = get_required_var("LISTEN_PORT");
    our $ntlm_proxy = "proxy=http://$ntlm_user:$ntlm_paswd\@$proxy_server:$listen_port";
}

1;
