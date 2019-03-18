# SUSE's openQA tests
#
# Copyright (c) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure clvmd or lvmlockd
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use version_utils 'is_sle';
use utils qw(zypper_call systemctl);
use testapi;
use lockapi;
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;
    my $lvm_conf     = '/etc/lvm/lvm.conf';
    my $lock_mgr     = 'clvm';

    # lvmlockd is only available in SLE15+
    if (get_var("USE_LVMLOCKD")) {
        die 'lvmlockd can be only used on SLE15+' unless is_sle('15+');
        $lock_mgr = 'lvmlockd';
    }

    # Wait until clvmd/lvmlockd test is initialized
    barrier_wait("LOCK_INIT_$cluster_name");

    # DLM process/resource needs to be started
    ensure_dlm_running;

    # lvm2-lockd package should be installed by default
    if ($lock_mgr eq 'lvmlockd') {
        die 'lvm2-lockd package is not installed' unless is_package_installed 'lvm2-lockd';
    }
    else {
        # In SLE15, lvmlockd is installed by default, not clvmd/cmirrord
        zypper_call 'in lvm2-clvm lvm2-cmirrord' if is_sle('15+');
    }

    # Configure LVM for HA cluster
    lvm_add_filter('r', '/dev/.\*/by-partuuid/.\*');
    if ($lock_mgr eq 'lvmlockd') {
        assert_script_run "sed -ie 's/^\\([[:blank:]]*use_lvmetad[[:blank:]]*=\\).*/\\1 1/' $lvm_conf";     # Set use_lvmetad=1, lvmlockd supports lvmetad
        assert_script_run "sed -ie 's/^\\([[:blank:]]*locking_type[[:blank:]]*=\\).*/\\1 1/' $lvm_conf";    # Set locking_type=1 for lvmlockd
        assert_script_run "sed -ie 's/^\\([[:blank:]]*use_lvmlockd[[:blank:]]*=\\).*/\\1 1/' $lvm_conf";    # Enable lvmlockd
    }
    else {
        assert_script_run "sed -ie 's/^\\([[:blank:]]*use_lvmetad[[:blank:]]*=\\).*/\\1 0/' $lvm_conf";     # Set use_lvmetad=0, clvmd doesn't support lvmetad
        assert_script_run "sed -ie 's/^\\([[:blank:]]*locking_type[[:blank:]]*=\\).*/\\1 3/' $lvm_conf";    # Set locking_type=3 for clvmd
        systemctl 'stop lvm2-lvmetad.socket';                                                               # Stop lvmetad
        systemctl 'disable lvm2-lvmetad.socket';                                                            # Disable lvmetad
    }

    # Show important configuration options in case of debugging
    script_run "grep -E '^[[:blank:]]*use_lvmetad|^[[:blank:]]*locking_type|^[[:blank:]]*use_lvmlockd' $lvm_conf";

    # Add clvmd/lvmlockd into the cluster configuration
    if (is_node(1)) {
        # Add clvmd/lvmlockd to base-group if it's not already done
        if (script_run "crm resource status $lock_mgr") {
            assert_script_run "EDITOR=\"sed -ie '\$ a primitive $lock_mgr ocf:heartbeat:$lock_mgr'\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie 's/^\\(group base-group.*\\)/\\1 $lock_mgr/'\" crm configure edit";

            # Wait to get clvmd/lvmlockd running on all nodes
            sleep 5;
        }
    }
    else {
        diag 'Wait until clvmd/lvmlockd resource is created...';
    }

    # Wait until clvmd/lvmlockd resource is created
    barrier_wait("LOCK_RESOURCE_CREATED_$cluster_name");

    # Do a check of the cluster with a screenshot
    save_state;
}

1;
