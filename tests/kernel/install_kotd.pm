# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module installs the KOTD (kernel of the day) and then reboots.
# Maintainer: Nathan Zhao <jtzhao@suse.com>
use 5.018;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;

=head2 grub_version

    grub_version();

If grub2 is installed, return 2; otherwise, return 1.

=cut

sub grub_version {
    my $ret = script_run('rpm -q grub2');
    if ($ret == 0) {
        return 2;
    }
    return 1;
}


=head2 download_kernel

  download_kernel($url, $package);

Download package $package from $url with wget and save it to /tmp. C<die> if wget returns non-zero value.

=cut

sub download_kernel {
    my ($url, $package) = @_;
    my $kernel = script_output("curl -sk '$url' | grep -oP '$package-[\\d.]+.*?\\.rpm' | head -n1");
    my $file   = "/tmp/$kernel";
    if (substr($url, -1) ne '/') {
        $url = "$url/$kernel";
    }
    else {
        $url = "$url$kernel";
    }
    assert_script_run("wget -O '$file' '$url'", timeout => 1800);
    return $file;
}

=head2 install_kernel

  install_kernel($file);

Install kernel file $file with rpm command and C<die> if it returns non-zero value.

=cut

sub install_kernel {
    my $file = shift;
    assert_script_run("rpm -i --nodeps --oldpackage --nosignature '$file'", timeout => 120);
}

# Set KOTD kernel as default boot option
=head2 set_default

  set_default($file);

Set $file as the default boot option.

=cut

sub set_default {
    my $file = shift;
    my $cmd  = <<'END';
#!/bin/bash
rpm -q grub2 &> /dev/null
if [[ $? -eq 0 ]]; then
    grub_conf='/boot/grub2/grub.cfg'
else
    grub_conf='/boot/grub/menu.lst'
fi

id=$(echo "$1" | awk -F. '{print $(NF-2)}')
vmlinuz=$(find /boot -name "vmlinuz-*$id*")
old_version=$(uname -r)
new_version=$(basename "$vmlinuz" | sed -e 's/vmlinuz-//g')
sed -ie "s/$old_version/$new_version/g" "$grub_conf"
END
    my $script = "set_default.sh";
    open my $fh, ">", 'current_script' or croak("Could not open file. $!");
    print $fh $cmd;
    close $fh;
    assert_script_run("curl -sfv '" . autoinst_url("/current_script") . "' | bash -xs '$file'");
}

sub run {
    my $self = shift;
    $self->wait_boot;

    $self->select_serial_terminal;

    my $url = get_required_var("INSTALL_KOTD");
    if ($url !~ /^https?:\/\//) {
        my $arch = get_required_var("ARCH");
        $url = "http://download.suse.de/ibs/Devel:/Kernel:/$url/standard/$arch/";
    }

    if (grub_version() == 1) {
        my $file = download_kernel($url, 'kernel-default-base');
        install_kernel($file);
    }
    my $file = download_kernel($url, "kernel-default");
    install_kernel($file);
    set_default($file);

    select_console('root-console');
    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Notes

=head2 INSTALL_KOTD

INSTALL_KOTD can be the version of operating system(e.g. openSUSE-42.2, SLE12-SP3) or the entire url of a zypper repo(e.g. http://download.suse.de/ibs/Devel:/Kernel:/SLE12-SP3/standard/)

=cut
