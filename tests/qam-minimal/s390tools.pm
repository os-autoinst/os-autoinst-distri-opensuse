# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: s390-tools test
# - bootloader installation (zipl) and re-IPL, without real change as worker has only one dasd
# - lscss, cputype, lsqeth, lsdasd, lsmem, dasd_reload, dasdview, dasdstat, dbginfo.sh
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    zypper_call 'in s390-tools';
    validate_script_output 'zipl -c /boot/zipl/config --dry-run', sub { m/Building|Preparing|Done/ };
    validate_script_output 'lsreipl',                             sub { m/Re-IPL|Device|Loadparm|Bootparms/ };
    assert_script_run 'export DASD_DEVICE=$(lsreipl|awk \'/Device/ {print$2}\')';
    validate_script_output 'chreipl ccw -d $DASD_DEVICE', sub { m/Re-IPL|Device|Loadparm|Bootparms/ };
    validate_script_output 'lscss',                       sub { m/Device|Subchan|DevType|CU|Type|Use|PIM|PAM|POM|CHPIDs/ };
    validate_script_output 'cputype',                     sub { m/IBM zEnterprise/ };
    validate_script_output 'lsqeth',                      sub { m/Device namei|card_type|cdev0|online|state|buffer_count|layer2/ };
    validate_script_output 'lsdasd',                      sub { m/Bus-ID|Status|Name|Device|Type|BlkSz|Size|Blocks/ };
    validate_script_output 'lsmem',                       sub { m/RANGE|SIZE|STATE|REMOVABLE|BLOCK/ };
    # dasd_reload does exit with 4
    assert_script_run 'dasd_reload|grep -E "offline|Activating"';
    validate_script_output 'dasdview -i /dev/dasda',               sub { m/general DASD information|DASD geometry/ };
    validate_script_output 'dasdview -c /dev/dasda',               sub { m/encrypted disk|solid state device/ };
    validate_script_output 'dasdview -x /dev/dasda',               sub { m/extended DASD information|features|characteristics/ };
    validate_script_output 'dasdview -l /dev/dasda',               sub { m/volume label|security byte|formatted_blocks/ };
    validate_script_output 'dasdview -t info /dev/dasda',          sub { m/VTOC info|data set/ };
    validate_script_output 'dasdview -t f4 /dev/dasda',            sub { m/VTOC format 4 label|DS4|res/ };
    validate_script_output 'dasdview -b 2b -s 128 /dev/dasda',     sub { m/HEXADECIMAL|EBCDIC|ASCII/ };
    validate_script_output 'dasdview -b 14b -s 128 -2 /dev/dasda', sub { m/BYTE|E0/ };
    validate_script_output 'dasdstat -e',                          sub { m/enable statistic/ };
    validate_script_output 'dasdstat -l',                          sub { m/dasd I\/O requests/ };
    validate_script_output 'dasdstat -d',                          sub { m/disable statistic/ };
    validate_script_output 'dbginfo.sh',                           sub { m/Debug information script/ };
}
1;
