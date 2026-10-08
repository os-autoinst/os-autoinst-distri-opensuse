# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
package wicked::TestContext;
use Mojo::Base 'OpenQA::Test::RunArgs';

has iface => undef;
has iface2 => undef;

1;
