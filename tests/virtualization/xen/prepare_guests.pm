# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Installation of HVM and PV guests
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';

use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    my $self = shift;

    # Ensure additional package is installed
    zypper_call '-t in libvirt-client';

    assert_script_run "mkdir -p /var/lib/libvirt/images/xen/";

    if (is_sle('<=12-SP1')) {
        script_run "umount /home";
        assert_script_run qq(sed -i 's/\\/home/\\/var\\/lib\\/libvirt\\/images\\/xen/g' /etc/fstab);
        script_run "mount /var/lib/libvirt/images/xen/";
    }

    assert_script_run qq(echo 'log_level = 1
    log_filters="3:remote 4:event 3:json 3:rpc"
    log_outputs="1:file:/var/log/libvirt/libvirtd.log"' >> /etc/libvirt/libvirtd.conf);
    systemctl 'restart libvirtd';

    if (script_run("virsh net-list --all | grep default") != 0) {
        assert_script_run qq(echo "<network>
<name>default</name>
<uuid>9a05da11-e96b-47f3-8253-a3a482e445f5</uuid>
<forward mode='nat'/>
<bridge name='virbr0' stp='on' delay='0'/>
<mac address='52:54:00:0a:cd:21'/>
<ip address='192.168.122.1' netmask='255.255.255.0'>
<dhcp><range start='192.168.122.2' end='192.168.122.254'/></dhcp>
</ip>
        </network>" > ~/default.xml);
        assert_script_run "virsh net-define --file ~/default.xml";
    }
    assert_script_run "virsh net-start default || true";
    assert_script_run "virsh net-autostart default";

    # Show all guests
    assert_script_run 'virsh list --all';
    wait_still_screen 1;

    # Install every defined guest
    foreach my $guest (keys %xen::guests) {
        $self->create_guest($guest, 'virt-install');
    }

    script_run 'history -a';
    script_run('cat ~/virt-install* | grep ERROR', 30);
}

1;
