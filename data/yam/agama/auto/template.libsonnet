local base_lib = import 'lib/base.libsonnet';
local scripts_post_lib = import 'lib/scripts_post.libsonnet';
local scripts_pre_lib = import 'lib/scripts_pre.libsonnet';
local storage_lib = import 'lib/storage.libsonnet';

function(bootloader=false, user=true, root=true, storage='', product='', registration_code='', scripts_pre='',
  scripts_post='', encrypted=false) {
  [if bootloader == true then 'bootloader']: base_lib['bootloader'],
  [if product != '' then 'product']: {
    id: product,
    [if registration_code != '' then 'registrationCode']: registration_code,
  },
  [if root == true then 'root']: base_lib['root'],
  [if scripts_pre != '' || scripts_post != '' then 'scripts']: {
    [if scripts_post != '' then 'post']: [ scripts_post_lib[x] for x in std.split(scripts_post, ',') ],
    [if scripts_pre != '' then 'pre']: [ scripts_pre_lib[x] for x in std.split(scripts_pre, ',') ],
  },
  [if storage != '' then 'storage']: storage_lib(storage, encrypted),
  [if user == true then 'user']: base_lib['user'],
}
