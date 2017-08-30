# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Build kiwi image and register it in pillar
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use utils 'zypper_call';


sub run {
  my ($self) = @_;
  if (check_var('SUMA_SALT_MINION', 'branch')) {
    select_console 'root-console';

    assert_script_run 'mkdir -p /usr/share/kiwi/image/saltboot/root/etc/salt/minion.d';

    # FIXME: the default 'salt' should be resolvable
    assert_script_run 'echo "master: 10.0.2.10" > /usr/share/kiwi/image/saltboot/root/etc/salt/minion.d/master.conf';

    #FIXME: use SUMA repos

    assert_script_run '( cd /usr/share/kiwi/image/jeos-6.0.0/ ; mkdir -p repo ; cd repo ; wget http://10.0.2.10/pub/rhn-org-trusted-ssl-cert-1.0-1.noarch.rpm )';

    # set std openqa password
    assert_script_run 'sed -i -e "s|pwd=[^ ]*|pwd=\"lQxldvDc9mR/o\"|"  /usr/share/kiwi/image/jeos-6.0.0/config.xml';

    script_output 'kiwi -b jeos-6.0.0 -d /built-image  ' .
      ' --add-repo http://smt.suse.cz/repo/SUSE/Products/SLE-SERVER/12-SP2/x86_64/product/ --add-repotype rpm-md ' .
      ' --add-repo http://smt.suse.cz/repo/SUSE/Updates/SLE-SERVER/12-SP2/x86_64/update/ --add-repotype rpm-md ' .
      ' --add-repo http://smt.suse.cz/repo/SUSE/Products/SLE-POS/12-SP2/x86_64/product/ --add-repotype rpm-md ' .
      ' --add-repo http://smt.suse.cz/repo/SUSE/Updates/SLE-POS/12-SP2/x86_64/update/ --add-repotype rpm-md '
      , 2000;
    script_output 'ls -l /built-image';

    barrier_wait('build_image');
    barrier_wait('image_registered');
    barrier_wait('image_synced');

    assert_script_run 'test -f /srv/tftpboot/boot/initrd.gz';
    assert_script_run 'test -f /srv/tftpboot/boot/linux';

  } 
  elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
    barrier_wait('build_image');
  }
  else {
    select_console 'root-console';
    
    assert_script_run "mkdir -p /etc/salt/master.d ; echo 'file_recv_max_size: 10000' >/etc/salt/master.d/openqa_test_image.conf";
    assert_script_run 'systemctl restart salt-master';
    barrier_create('image_registered', 2);
    barrier_create('image_synced', 2);
    barrier_wait('build_image');
    
    assert_script_run 'salt -t 1000 suma-branch\* cp.push /built-image/POS_Image_JeOS5.x86_64-6.0.0', 1000;
    assert_script_run 'salt -t 1000 suma-branch\* cp.push /built-image/initrd-netboot-suse-SLES12.x86_64-2.1.1.gz', 1000;
    assert_script_run 'salt -t 1000 suma-branch\* cp.push /built-image/initrd-netboot-suse-SLES12.x86_64-2.1.1.kernel', 1000;
    script_output 'find /var/cache/salt/master/minions -type f ';
    assert_script_run 'cp -r /var/cache/salt/master/minions/suma-branch*/files/built-image /srv/www/htdocs/pub/';

    # share one pillar file between tests, each test appends its own config
    script_output 'cat >> /srv/pillar/suma_test.sls << EOT
images:
  JeOS:
    - 6.0.0:
        url: ftp://ftp/image/POS_Image_JeOS5.x86_64-6.0.0
        name: POS_Image_JeOS5
        fstype: ext3
        size: `stat -c%s /srv/www/htdocs/pub/built-image/POS_Image_JeOS5.x86_64-6.0.0`
        hash: `sha256sum /srv/www/htdocs/pub/built-image/POS_Image_JeOS5.x86_64-6.0.0 |cut -d \' \' -f 1`
        boot_image: default
        sync:
          url: http://10.0.2.10/pub/built-image/POS_Image_JeOS5.x86_64-6.0.0

boot_images:
  default:
    name: initrd-netboot-suse-SLES12
    initrd:
        version: 2.1.1
        hash: `sha256sum /srv/www/htdocs/pub/built-image/initrd-netboot-suse-SLES12.x86_64-2.1.1.gz |cut -d \' \' -f 1`
        url: ftp://ftp/boot/default/initrd-netboot-suse-SLES12.x86_64-2.1.1.gz
    kernel:
        version: `echo /srv/www/htdocs/pub/built-image/initrd-netboot-suse-SLES12.x86_64-2.1.1.kernel* |sed -e \'s|^.*kernel.||\'`
        hash: `sha256sum /srv/www/htdocs/pub/built-image/initrd-netboot-suse-SLES12.x86_64-2.1.1.kernel* |cut -d \' \' -f 1`
        url: ftp://ftp/boot/default/`echo /srv/www/htdocs/pub/built-image/initrd-netboot-suse-SLES12.x86_64-2.1.1.kernel* |sed -e \'s|^.*/||\'`
    sync:
        initrd_url: http://10.0.2.10/pub/built-image/initrd-netboot-suse-SLES12.x86_64-2.1.1.gz
        kernel_url: http://10.0.2.10/pub/built-image/`echo /srv/www/htdocs/pub/built-image/initrd-netboot-suse-SLES12.x86_64-2.1.1.kernel* |sed -e \'s|^.*/||\'`
        local_path: default

EOT
';

    assert_script_run 'echo "base:
  \'*\':
    - suma_test" > /srv/pillar/top.sls';
    script_output 'cat /srv/pillar/*';
    script_output 'salt suma-branch\* pillar.items';
    barrier_wait('image_registered');

    $self->check_and_add_repo();
    zypper_call("in image-sync-formula");
    script_output 'salt -t 1000 suma-branch\* state.show_sls image-sync';
    script_output 'salt -t 1000 suma-branch\* state.apply image-sync';

    select_console 'x11', tags => 'suma_welcome_screen';
    barrier_wait('image_synced');
  }
}

sub test_flags() {
    return {milestone => 1};
}


1;
