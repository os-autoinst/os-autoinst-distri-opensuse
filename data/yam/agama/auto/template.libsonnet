local base_lib = import 'lib/base.libsonnet';
local addons_lib = import 'lib/addons.libsonnet';
local dasd_lib = import 'lib/dasd.libsonnet';
local scripts_post_lib = import 'lib/scripts_post.libsonnet';
local scripts_post_partitioning_lib = import 'lib/scripts_post_partitioning.libsonnet';
local scripts_pre_lib = import 'lib/scripts_pre.libsonnet';
local storage_lib = import 'lib/storage.libsonnet';
local security_lib = import 'lib/security.libsonnet';

function(bootloader=false,
         dasd=false,
         localization='',
         packages='',
         patterns='',
         product='',
         registration_code='',
         registration_code_ha='',
         registration_url='',
         root_password=true,
         scripts_pre='',
         scripts_post_partitioning='',
         scripts_post='',
         ssl_certificates=false,
         storage='',
         user=true) {
  [if bootloader == true then 'bootloader']: base_lib['bootloader'],
  [if dasd == true then 'dasd']: dasd_lib.dasd(),
  [if localization == true then 'localization']: base_lib['localization'],
  [if patterns != '' || packages != '' then 'software']: std.prune({
    patterns: if patterns != '' then std.split(patterns, ','),
    packages: if packages != '' then std.split(packages, ','),
  }),
  [if product != '' then 'product']: {
    [if registration_code_ha != '' then 'addons']: std.prune([
      if registration_code_ha != '' then addons_lib.addon_ha(registration_code_ha),
    ]),
    id: product,
    [if registration_code != '' then 'registrationCode']: registration_code,
    [if registration_url != '' then 'registrationUrl']: registration_url,
  },
  root: base_lib.root(root_password),
  [if ssl_certificates == true then 'security']: security_lib.sslCertificates(),
  [if scripts_pre != '' || scripts_post != '' || scripts_post_partitioning != '' then 'scripts']: {
    [if scripts_post != '' then 'post']: [ scripts_post_lib[x] for x in std.split(scripts_post, ',') ],
    [if scripts_post_partitioning != '' then 'postPartitioning']: [ scripts_post_partitioning_lib[x] for x in std.split(scripts_post_partitioning, ',') ],
    [if scripts_pre != '' then 'pre']: [ scripts_pre_lib[x] for x in std.split(scripts_pre, ',') ],
  },
  [if std.startsWith(storage, 'raid') then 'storage']: storage_lib[storage],
  [if storage == 'lvm' then 'storage']: storage_lib['lvm'],
  [if storage == 'lvm_encrypted' then 'storage']: storage_lib['lvm_encrypted'],
  [if storage == 'lvm_tpm_fde' then 'storage']: storage_lib['lvm_tpm_fde'],
  [if storage == 'root_filesystem_ext4' then 'storage']: storage_lib['root_filesystem_ext4'],
  [if storage == 'root_filesystem_xfs' then 'storage']: storage_lib['root_filesystem_xfs'],
  [if storage == 'resize' then 'storage']: storage_lib['resize'],
  [if storage == 'whole_disk_and_boot_unattended' then 'storage']: storage_lib['whole_disk_and_boot_unattended'],
  [if user == true then 'user']: base_lib['user'],
}
