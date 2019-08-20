# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validation module to check encrypted volume.
# Scenarios covered:
# - Verify whether '/etc/crypttab' (encrypted device table) file exists;
# - Verify the crypted volumes are active;
# - Verify storing and restoring for binary backups of LUKS header and keyslot areas.
#
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

sub run {

    record_info('crypttab file', 'Verify whether \'/etc/crypttab\' (encrypted device table) file exists.');
    assert_script_run('test -f /etc/crypttab', fail_message => 'No /etc/crypttab found!');

    record_info('crypt vol status', 'Verify the crypted volumes are active');
    my @crypted_volumes = script_output q[cat /etc/crypttab | awk '{print $1}'];
    foreach (@crypted_volumes) {
        assert_script_run qq[cryptsetup status $_ | grep "is active"];
    }

    record_info('Verify LUKS', 'Verify binary backups of LUKS header and keyslot areas storing and restoring');
    foreach (@crypted_volumes) {
        my $bkp_file = '/root/bkp_luks_header';

        my $device = script_output q[cat /etc/crypttab | awk '{print $2}'];
        next if (script_run('cryptsetup -v isLuks ' . $device) != 0);
        assert_script_run('cryptsetup -v luksUUID ' . $device);
        assert_script_run('cryptsetup -v luksDump ' . $device);
        assert_script_run('cryptsetup -v luksHeaderBackup ' . $device . ' --header-backup-file ' . $bkp_file);
        validate_script_output("file $bkp_file", sub { m/\bLUKS\sencrypted\sfile\b/ });
        assert_script_run('cryptsetup -v --batch-mode luksHeaderRestore ' . $device . ' --header-backup-file ' . $bkp_file);
    }
}

1;
