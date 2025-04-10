local base_lib = import 'lib/base.libsonnet';
local addons_lib = import 'lib/addons.libsonnet';
local scripts_post_lib = import 'lib/scripts_post.libsonnet';
local scripts_pre_lib = import 'lib/scripts_pre.libsonnet';
local storage_lib = import 'lib/storage.libsonnet';

function(addon_ha_reg_code='',
         bootloader=false,
         user=true,
         root=true,
         storage='',
         packages='',
         patterns='',
         product='',
         registration_code='',
         scripts_pre='',
         scripts_post='') {
  [if bootloader == true then 'bootloader']: base_lib['bootloader'],
  [if patterns != '' || packages != '' then 'software']: std.prune({
    patterns: if patterns != '' then std.split(patterns, ','),
    packages: if packages != '' then std.split(packages, ','),
  }),
  [if product != '' then 'product']: {
    [if addon_ha_reg_code != '' then 'addons']: std.prune([
      if addon_ha_reg_code != '' then addons_lib.addon_ha(addon_ha_reg_code),
    ]),
    id: product,
    [if registration_code != '' then 'registrationCode']: registration_code,
  },
  [if root == true then 'root']: base_lib['root'],
  [if scripts_pre != '' || scripts_post != '' then 'scripts']: {
    [if scripts_post != '' then 'post']: [ scripts_post_lib[x] for x in std.split(scripts_post, ',') ],
    [if scripts_pre != '' then 'pre']: [ scripts_pre_lib[x] for x in std.split(scripts_pre, ',') ],
  },
  [if storage == 'lvm' then 'storage']: storage_lib['lvm'],
  [if storage == 'lvm_encrypted' then 'storage']: storage_lib['lvm_encrypted'],
  [if storage == 'root_filesystem_ext4' then 'storage']: storage_lib['root_filesystem_ext4'],
  [if storage == 'root_filesystem_xfs' then 'storage']: storage_lib['root_filesystem_xfs'],
  [if user == true then 'user']: base_lib['user'],
}
