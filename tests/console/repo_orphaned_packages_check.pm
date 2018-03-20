# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for packages orphaned from present repos
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'consoletest';
use strict;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';

    # Pipe-separated list of packages we whitelist for orphan checking
    my $orphan_whitelist = get_var('ORPHAN_WHITELIST', 'gpg-pubkey');
    zypper_call('ref');
    my $script = 'ret=0
for name in $(rpmquery -a --qf "%{NAME}\n" | grep -v -E ^"' . $orphan_whitelist . '"$)
do
  if ! zypper --no-refresh info $name | grep -wq ^Repository; then
    echo "ERROR: $name package is not present in available repos"
    ret=1
  fi
done
if [ $ret -ne 0 ]; then false; fi
';
    my $script_name = 'repo_orphaned_packages_check.sh';
    save_tmp_file($script_name, $script);
    assert_script_run('curl -O ' . autoinst_url . "/files/$script_name");
    assert_script_run("sh $script_name", 600);
    assert_script_run("rm $script_name");
}

1;
# vim: set sw=4 et:
