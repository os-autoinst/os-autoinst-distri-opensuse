local addons_lib = import 'lib/addons.libsonnet';
local base_lib = import 'lib/base.libsonnet';
local dasd_lib = import 'lib/dasd.libsonnet';
local iscsi_lib = import 'lib/iscsi.libsonnet';
local scripts_post_lib = import 'lib/scripts_post.libsonnet';
local scripts_post_partitioning_lib = import 'lib/scripts_post_partitioning.libsonnet';
local scripts_pre_lib = import 'lib/scripts_pre.libsonnet';
local software_lib = import 'lib/software.libsonnet';
local storage_lib = import 'lib/storage.libsonnet';
local security_lib = import 'lib/security.libsonnet';
local answers_lib = import 'lib/answers.libsonnet';

function(bootloader=true,
         bootloader_timeout=false,
         bootloader_extra_kernel_params='',
         dasd=false,
         extra_repositories=false,
         files=false,
         iscsi=false,
         localization='',
         packages='',
         patterns='',
         patterns_to_add='',
         patterns_to_remove='',
         product='',
         registration_code='',
         registration_code_ha='',
         registration_packagehub=false,
         registration_url='',
         root_password=true,
         scripts_pre='',
         scripts_post_partitioning='',
         scripts_post='',
         software_only_required=false,
         ssl_certificates=false,
         storage='',
         decrypt_password='',
         user=true) (
        base_lib.bootloader(bootloader, bootloader_timeout, bootloader_extra_kernel_params) +
        {
          [if dasd == true then 'dasd']: dasd_lib.dasd(),
          [if files == true then 'files']: base_lib['files'],
          [if iscsi == true then 'iscsi']: iscsi_lib.iscsi(),
          [if localization == true then 'localization']: base_lib['localization'],
          [if patterns != '' || packages != '' || extra_repositories ||
            patterns_to_add != '' || patterns_to_remove != '' ||
            software_only_required then 'software']: std.prune({
            patterns: if patterns_to_add != '' || patterns_to_remove != ''
              then software_lib.modify_patterns(patterns_to_add, patterns_to_remove)
              else if patterns != '' then std.split(patterns, ','),
            packages: if packages != '' then std.split(packages, ','),
            extraRepositories: if extra_repositories then software_lib['extraRepositories'],
            onlyRequired: if software_only_required then true,
          }),
          [if product != '' then 'product']: {
            [if registration_code_ha != '' || registration_packagehub then 'addons']: std.prune([
              if registration_code_ha != '' then addons_lib.addon_ha(registration_code_ha),
              if registration_packagehub then addons_lib.addon_packagehub(),
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
          [if decrypt_password != '' || registration_packagehub then 'questions']: {
            answers: std.prune([
              if decrypt_password != '' then answers_lib.questions_decrypt(decrypt_password),
              if registration_packagehub then answers_lib.questions_import_gpg(),
            ]),
          },
          [if storage != '' then 'storage']: storage_lib[storage],
          [if user == true then 'user']: base_lib['user'],
        })
