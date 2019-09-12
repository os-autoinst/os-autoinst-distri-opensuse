package vagrant;
use testapi;
use strict;
use warnings;
use utils;

our @ISA    = qw(Exporter);
our @EXPORT = qw(setup_vagrant_libvirt setup_vagrant_virtualbox);

# - install vagrant and vagrant-libvirt
# - launch the required daemons
sub setup_vagrant_libvirt {
    select_console('root-console');

    zypper_call("in vagrant vagrant-libvirt");
    assert_script_run("systemctl start libvirtd");
    assert_script_run("usermod -a -G libvirt bernhard");
}

# - install vagrant and virtualbox
# - launch the required daemons
sub setup_vagrant_virtualbox {
    select_console('root-console');

    zypper_call("in vagrant virtualbox");
    assert_script_run("systemctl start vboxdrv");
    assert_script_run("systemctl start vboxautostart");
    assert_script_run("usermod -a -G vboxusers bernhard");
}
