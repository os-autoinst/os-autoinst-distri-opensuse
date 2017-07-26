# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create basic barrier locks
# Maintainer: Ondrej Holecek <oholecek@suse.com>

use 5.018;
use parent "basetest";
use lockapi;

sub run {
  # this is for master to wait for minion
}

sub test_flags {
  return {fatal => 1}
}

1;
