# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Clone system and use the autoyast file in chained tests
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "console_yasttest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_opensuse);
use utils 'zypper_call';
use repo_tools 'get_repo_var_name';

sub run {
    my $self = shift;
    select_console 'root-console';

    # Install for TW and generate profile
    zypper_call "in autoyast2";
    script_run("yast2 clone_system; echo yast2-clone-system-status-\$? > /dev/$serialdev", 0);

    # workaround for bsc#1013605
    my $timeout = 600;
    assert_screen([qw(dhcp-popup yast2_console-finished)], $timeout);
    if (match_has_tag('dhcp-popup')) {
        wait_screen_change { send_key 'alt-o' };
        assert_screen 'yast2_console-finished', $timeout;
    }
    wait_serial('yast2-clone-system-status-0') || die "'yast2 clone_system' didn't finish";

    $self->select_serial_terminal;
    # Replace unitialized email variable - bsc#1015158
    assert_script_run 'sed -i "/server_email/ s/postmaster@/\0suse.com/" /root/autoinst.xml';

    # Check and upload profile for chained tests
    upload_asset "/root/autoinst.xml";

    unless (is_opensuse) {
        my $devel_repo = get_required_var(is_sle('>=15') ? get_repo_var_name("MODULE_DEVELOPMENT_TOOLS") : 'REPO_SLE_SDK');
        zypper_call "ar -c $utils::OPENQA_FTP_URL/" . $devel_repo . " devel-repo";
    }

    zypper_call '--gpg-auto-import-keys ref';
    zypper_call 'install jing';

    my $rc_jing    = script_run 'jing /usr/share/YaST2/schema/autoyast/rng/profile.rng /root/autoinst.xml';
    my $rc_xmllint = script_run 'xmllint --noout --relaxng /usr/share/YaST2/schema/autoyast/rng/profile.rng /root/autoinst.xml';

    if (($rc_jing) || ($rc_xmllint)) {
        if (is_sle('<15')) {
            record_soft_failure 'bsc#1103712';
        }
        else {
            die "autoinst.xml does not validate for unknown reason";
        }
    }

    # Remove for autoyast_removed test - poo#11442
    assert_script_run "rm /root/autoinst.xml";
    # Return from VirtIO console
    select_console 'root-console';
}

1;
