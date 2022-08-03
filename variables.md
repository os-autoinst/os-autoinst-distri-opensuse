
## Supported list of variables which control test suites

Below you can find the list of variables which control tests behavior, including schedule.
Please, find [os-autoinst backend variables](https://github.com/os-autoinst/os-autoinst/blob/master/doc/backend_vars.asciidoc) which complement the list of variables below.

NOTE: This list is not complete and may contain outdated info. If you face such a case, please, create pull request with required changes.

For a better overview some domain-specific values have been moved to their own section:

* [Publiccloud](#publiccloud-specific-variables)

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
AARCH64_MTE_SUPPORTED | boolean | false     | Set to 1 if your machine supports Memory Tagging Extension (MTE)
ADDONS          | string    |               | Comma separated list of addons to be added using DVD. Also used to indicate addons in the SUT.
ADDONURL        | string    |               | Comma separated list of addons. Includes addon names to get url defined in ADDONURL_*. For example: ADDONURL=sdk,we ADDONURL_SDK=https://url ADDONURL_WE=ftp://url
ADDONURL_*      | string    |               | Define url for the addons list defined in ADDONURL
ASSERT_BSC1122804 | boolean | false | In some scenarios it is necessary to check if the mistyped full name still happens.
ASSERT_Y2LOGS   | boolean   | false         | If set to true, we will parse YaST logs after installation and fail test suite in case unknown errors were detected.
AUTOCONF        | boolean   | false         | Toggle automatic configuration
AUTOYAST        | string    |               | Full url to the AY profile or relative path if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data). If value starts with `aytests/`, these profiles are provided by suport server, source code is available in [aytests repo](https://github.com/yast/aytests-tests). If value is a folder ending in `/` rules and classes will be used.
AUTOYAST_PREPARE_PROFILE | boolean | false | Enable variable expansion in the autoyast profile.
AUTOYAST_VERIFY_TIMEOUT  | boolean | false | Enable validation of pop-up windows timeout.
AY_EXPAND_VARS | string | | Commas separated list of variable names to be expanded in the provided autoyast profile. For example: REPO_SLE_MODULE_BASESYSTEM,DESKTOP,... Provided variables will replace `{{VAR}}` in the profile with the value of given variable. See also `AUTOYAST_PREPARE_PROFILE`.
BASE_VERSION | string | | |
BETA | boolean | false | Enables checks and processing of beta warnings. Defines current stage of the product under test.
BCI_DEVEL_REPO | string | | This parameter is given to the bci-tests to inject a different SLE_BCI repository url to the container image instead of the default one. Used by `bci_test.pm`.
BCI_TEST_ENVS | string | | The list of environments to be tested, e.g. `base,init,dotnet,python,node,go,multistage`. Used by `bci_test.pm`.
BCI_TESTS_REPO | string | | Location of the bci-tests repository to be cloned. Used by `bci_prepare.pm`.
BCI_TESTS_BRANCH | string | | Branch to be cloned from bci-tests. Used by `bci_prepare.pm`.
BCI_TIMEOUT | string | | Timeout given to the command to test each environment. Used by `bci_test.pm`.
BTRFS | boolean | false | Indicates btrfs filesystem. Deprecated, use FILESYSTEM instead.
BUILD | string  |       | Indicates build number of the product under test.
CASEDIR | string | | Path to the directory which contains tests.
CHECK_RELEASENOTES | boolean | false | Loads `installation/releasenotes` test module.
CHECKSUM_* | string | | SHA256 checksum of the * medium. E.g. CHECKSUM_ISO_1 for ISO_1.
CHECKSUM_FAILED | string | | Variable is set if checksum of installation medium fails to visualize error in the test module and not just put this information in the autoinst log file.
CLUSTER_TYPES | string | false | Set the type of cluster that have to be analyzed (example: "drbd hana"). This variable belongs to PUBLIC_CLOUD_.
CONTAINER_RUNTIME | string | | Container runtime to be used, e.g.  `docker`, `podman`, or both `podman,docker`. In addition, it is also used for other container tests, like  `kubectl`, `helm`, etc.
CONTAINERS_K3S_VERSION | string |  | If defined, install the provided version of k3s
CONTAINERS_NO_SUSE_OS | boolean | false | Used by main_containers to see if the host is different than SLE or openSUSE.
CONTAINERS_UNTESTED_IMAGES | boolean | false | Whether to use `untested_images` or `released_images` from `lib/containers/urls.pm`.
CONTAINERS_CRICTL_VERSION | string | v1.23.0 | The version of CriCtl tool.
CONTAINERS_NERDCTL_VERSION | string | 0.16.1 | The version of NerdCTL tool.
CPU_BUGS | boolean | | Into Mitigations testing
DESKTOP | string | | Indicates expected DM, e.g. `gnome`, `kde`, `textmode`, `xfce`, `lxde`. Does NOT prescribe installation mode. Installation is controlled by `VIDEOMODE` setting
DEPENDENCY_RESOLVER_FLAG| boolean | false      | Control whether the resolve_dependecy_issues will be scheduled or not before certain modules which need it.
DEV_IMAGE | boolean | false | This setting is used to set veriables properly when SDK or Development-Tools are required.
DISABLE_ONLINE_REPOS | boolean | false | Enables `installation/disable_online_repos` test module, relevant for openSUSE only. Test module explicitly disables online repos not to be used during installation.
DISABLE_SECUREBOOT | boolean | false | Disable secureboot in firmware of the SUT or in hypervisor's guest VM settings
DISABLE_SLE_UPDATES | boolean | false | Disables online updates for the installation.
DISTRI | string | | Defines distribution. Possible values: `sle`, `opensuse`, `microos`.
DOCRUN | boolean | false |
DUALBOOT | boolean | false | Enables dual boot configuration during the installation.
DUD | string | | Defines url or relative path to the DUD file if in [data directory of os-autoinst-distri-opensuse repo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data)
DUD_ADDONS | string | | Comma separated list of addons added using DUD.
DVD |||
ENCRYPT | boolean | false | Enables or indicates encryption of the disks. Can be combined with `FULL_LVM_ENCRYPT`, `ENCRYPT_CANCEL_EXISTING`, `ENCRYPT_ACTIVATE_EXISTING` and `UNENCRYPTED_BOOT`.
ENCRYPT_CANCEL_EXISTING | boolean | false | Used to cancel activation of the encrypted partitions |
SOFTLOCKUP_PANIC_DISABLED | boolean | false | Disables panicking on softlockup, provides a stack trace once a softlockup has been detected (see POO#50345)
ETC_PASSWD | string | | Sets content for /etc/passwd, can be used to mimic existing users. Is used to test import of existing users on backends which have no shapshoting support (powerVM, zVM). Should be used together with `ENCRYPT_ACTIVATE_EXISTING` and `ETC_SHADOW`.
ETC_SHADOW | string | | Sets content for /etc/shadow, can be used to mimic existing users. Is used to test import of existing users on backends which have no shapshoting support (powerVM, zVM). Should be used together with `ENCRYPT_ACTIVATE_EXISTING` and `ETC_PASSWD`.
EVERGREEN |||
EXIT_AFTER_START_INSTALL | boolean | false | Indicates that test suite will be finished after `installation/start_install` test module. So that all the test modules after this one will not be scheduled and executed.
EXPECTED_INSTALL_HOSTNAME | string | | Contains expected hostname YaST installer got from the environment (DHCP, 'hostname=', as a kernel cmd line argument)
EXTRABOOTPARAMS | string | | Concatenates content of the string as boot options applied to the installation bootloader.
EXTRABOOTPARAMS_BOOT_LOCAL | string | | Boot options applied during the boot process of a local installation.
EXTRABOOTPARAMS_DELETE_CHARACTERS | string | | Characters to delete from boot prompt.
EXTRABOOTPARAMS_DELETE_NEEDLE_TARGET | string | | If specified, go back with the cursor until this needle is matched to delete characters from there. Needs EXTRABOOTPARAMS_BOOT_LOCAL and should be combined with EXTRABOOTPARAMS_DELETE_CHARACTERS.
EXTRATEST | boolean | false | Enables execution of extra tests, see `load_extra_tests`
FIRST_BOOT_CONFIG | string | combustion+ignition | The method used for initial configuration of MicroOS images. Possible values are: `combustion`, `ignition`, `combustion+ignition` and `wizard`. For ignition/combustion, the job needs to have a matching HDD attached.
FLAVOR | string | | Defines flavor of the product under test, e.g. `staging-.-DVD`, `Krypton`, `Argon`, `Gnome-Live`, `DVD`, `Rescue-CD`, etc.
FULLURL | string | | Full url to the factory repo. Is relevant for openSUSE only.
FULL_LVM_ENCRYPT | boolean | false | Enables/indicates encryption using lvm. boot partition may or not be encrypted, depending on the product default behavior.
FUNCTION | string | | Specifies SUT's role for MM test suites. E.g. Used to determine which SUT acts as target/server and initiator/client for iscsi test suite
GRUB_PARAM | string | | A semicolon-separated list of extra boot options. Adds 2 grub meny entries per each item in main grub (2nd entry is the "Advanced options ..." submenu). See `add_custom_grub_entries()`.
GRUB_BOOT_NONDEFAULT | boolean | false | Boot grub menu entry added by `add_custom_grub_entries` (having setup `GRUB_PARAM=debug_pagealloc=on;ima_policy=tcb;slub_debug=FZPU`, `GRUB_BOOT_NONDEFAULT=1` selects 3rd entry, which contains `debug_pagealloc=on`, `GRUB_BOOT_NONDEFAULT=2` selects 5th entry, which contains `ima_policy=tcb`). NOTE: ARCH=s390x on BACKEND=s390x is not supported. See `boot_grub_item()`, `handle_grub()`.
GRUB_SELECT_FIRST_MENU | integer | | Select grub menu entry in main grub menu, used together with GRUB_SELECT_SECOND_MENU. GRUB_BOOT_NONDEFAULT has higher preference when both set. NOTE: ARCH=s390x on BACKEND=s390x is not supported. See `boot_grub_item()`, `handle_grub()`.
GRUB_SELECT_SECOND_MENU | integer | | Select grub menu entry in secondary grub menu (the "Advanced options ..." submenu), used together with GRUB_SELECT_FIRST_MENU. GRUB_BOOT_NONDEFAULT has higher preference when both set. NOTE: ARCH=s390x on BACKEND=s390x is not supported. See `boot_grub_item()`, `handle_grub()`.
HASLICENSE | boolean | true if SLE, false otherwise | Enables processing and validation of the license agreements.
HDDVERSION | string | | Indicates version of the system installed on the HDD.
HTTPPROXY  |||
INSTALL_KEYBOARD_LAYOUT | string | | Specify one of the supported keyboard layout to switch to during installation or to be used in autoyast scenarios e.g.: cz, fr
INSTALL_SOURCE | string | | Specify network protocol to be used as installation source e.g. MIRROR_HTTP
INSTALLATION_VALIDATION | string | | Comma separated list of modules to be used for installed system validation, should be used in combination with INSTALLONLY, to schedule only relevant test modules.
INSTALLONLY | boolean | false | Indicates that test suite conducts only installation. Is recommended to be used for all jobs which create and publish images
INSTLANG | string | en_US | Installation locale settings.
IPXE | boolean | false | Indicates ipxe boot.
ISO_MAXSIZE | integer | | Max size of the iso, used in `installation/isosize.pm`.
IS_MM_SERVER | boolean | | If set, run server-specific part of the multimachine job
K3S_SYMLINK | string | | Can be 'skip' or 'force'. Skips the installation of k3s symlinks to tools like kubectl or forces the creation of symlinks 
K3S_BIN_DIR | string | | If defined, install k3s to this provided directory instead of `/usr/local/bin/`
K3S_CHANNEL | string | | Set the release channel to pick the k3s version from. Options include "stable", "latest" and "testing"
KUBECTL_CLUSTER | string | | Defines the cluster used to test `kubectl`. Currently only `k3s` is supported.
KUBECTL_VERSION | string | v1.22.12 | Defines the kubectl version.
KEEP_DISKS | boolean | false | Prevents disks wiping for remote backends without snaphots support, e.g. ipmi, powerVM, zVM
KEEP_ONLINE_REPOS | boolean | false | openSUSE specific variable, not to replace original repos in the installed system with snapshot mirrors which are not yet published.
KEEP_PERSISTENT_NET_RULES | boolean | false | Keep udev rules 70-persistent-net.rules, which are deleted on backends with image support (qemu, svirt) by default.
LAPTOP |||
LINUX_BOOT_IPV6_DISABLE | boolean | false | If set, boots linux kernel with option named "ipv6.disable=1" which disables IPv6 from startup.
LINUXRC_KEXEC | integer | | linuxrc has the capability to download and run a new kernel and initrd pair from the repository.<br> There are four settings for the kexec option:<br> 0: feature disabled;<br> 1: always restart with kernel/initrd from repository (without bothering to check if it's necessary);<br>2: restart only if needed - that is, if linuxrc detects that the booted initrd is outdated (this is the default);<br>3: like kexec=2 but without user interaction.<br> *More details [here](https://en.opensuse.org/SDB:Linuxrc)*.
LIVECD | boolean | false | Indicates live image being used.
LIVE_INSTALLATION | boolean | false | If set, boots the live media and starts the builtin NET installer.
LIVE_UPGRADE | boolean | false | If set, boots the live media and starts the builtin NET installer in upgrade mode.
LIVETEST | boolean | false | Indicates test of live system.
LTP_COMMAND_FILE | string | | The LTP test command file (e.g. syscalls, cve)
LTP_COMMAND_EXCLUDE | string | | This regex is used to exclude tests from LTP command file.
LTP_KNOWN_ISSUES | string | | Used to specify a url for a json file with well known LTP issues. If an error occur which is listed, then the result is overwritten with softfailure.
LTP_REPO | string | | The repo which will be added and is used to install LTP package.
LTP_RUN_NG_BRANCH | string | | Define the branch of the LTP_RUN_NG_REPO.
LTP_RUN_NG_REPO | string | | Define the runltp-ng repo to be used. Default in publiccloud/run_ltp.pm is the upstream master branch from https://github.com/metan-ucw/runltp-ng.git.
LVM | boolean | false | Use lvm for partitioning.
LVM_THIN_LV | boolean | false | Use thin provisioning logical volumes for partitioning,
MACHINE | string | | Define machine name which defines worker specific configuration, including WORKER_CLASS.
MEDIACHECK | boolean | false | Enables `installation/mediacheck` test module.
MEMTEST | boolean | false | Enables `installation/memtest` test module.
MIRROR_{protocol} | string | | Specify source address
MOK_VERBOSITY | boolean | false | Enable verbosity feature of shim. Requires preinstalled `mokutil`.
MOZILLATEST |||
NAME | string | | Name of the test run including distribution, build, machine name and job id.
NAMESERVER | string | | Can be used to specify a name server's IP or FQDN.
NET | boolean | false | Indicates net installation.
NETBOOT | boolean | false | Indicates net boot.
NETDEV | string | | Network device to be used when adding interface on zKVM.
NFSCLIENT | boolean | false | Indicates/enables nfs client in `console/yast2_nfs_client` for multi-machine test.
NFSSERVER | boolean | false | Indicates/enables nfs server in `console/yast2_nfs_server`.
NICEVIDEO |||
NICTYPE_USER_OPTIONS | string | | `hostname=myguest` causes a fake DHCP hostname 'myguest' provided to SUT. It is used as expected hostname if `EXPECTED_INSTALL_HOSTNAME` is not set.
NO_ADD_MAINT_TEST_REPOS | boolean | true |  Do not add again (and duplicate) repositories that were already added during install
NOAUTOLOGIN | boolean | false | Indicates disabled auto login.
NOIMAGES |||
NOLOGS | boolean | false | Do not collect logs if set to true. Handy during development.
OPT_KERNEL_PARAMS | string | Specify optional kernel command line parameters on bootloader settings page of the installer.
PERF_KERNEL | boolean | false | Enables kernel performance testing.
PERF_INSTALL | boolean | false | Enables kernel performance testing installation part.
PERF_SETUP | boolean | false | Enables kernel performance testing deployment part.
PERF_RUNCASE | boolean | false | Enables kernel performance testing run case part.
RMT_SERVER | string | Local server to be used in RMT registration. 
SALT_FORMULAS_PATH | string | | Used to point to a tarball with relative path to [/data/yast2](https://github.com/os-autoinst/os-autoinst-distri-opensuse/tree/master/data/yast2) which contains all the needed files (top.sls, form.yml, ...) to support provisioning with Salt masterless mode.
PKGMGR_ACTION_AT_EXIT | string | "" | Set the default behavior of the package manager when package installation has finished. Possible actions are: close, restart, summary. If PKGMGR_ACTION_AT_EXIT is not set in openQA, test module will read the default value from /etc/sysconfig/yast2.
PXE_PRODUCT_NAME | string | false | Defines image name for PXE booting
QA_TESTSUITE | string | | Comma or semicolon separated a list of the automation cases' name, and these cases will be installed and triggered if you call "start_testrun" function from qa_run.pm
QAM_MINIMAL | string | "full" or "small" | Full is adding patterns x11, gnome-basic, base, apparmor in minimal/install_patterns test. Small is just base.
RAIDLEVEL | integer | | Define raid level to be configured. Possible values: 0,1,5,6,10.
REBOOT_TIMEOUT | integer | 0 | Set and handle reboot timeout available in YaST installer. 0 disables the timeout and needs explicit reboot confirmation.
REGISTRY | string | docker.io | Registry to pull third-party container images from
CONTAINER_IMAGE_VERSIONS | string | | List of comma-separated versions from `get_suse_container_urls()`
CONTAINER_IMAGE_TO_TEST | string | | Single URL string of a specific container image to test.
REGRESSION | string | | Define scope of regression testing, including ibus, gnome, documentation and other.
REMOTE_REPOINST | boolean | | Use linuxrc features to install OS from specified repository (install) while booting installer from DVD (instsys)
REPO_* | string | | Url pointing to the mirrored repo. REPO_0 contains installation iso.
RESCUECD | boolean | false | Indicates rescue image to be used.
RESCUESYSTEM | boolean | false | Indicates rescue system under test.
ROOTONLY | boolean | false | Request installation to create only the root account, no user account.
RESET_HOSTNAME| boolean | false | If set to true content of /etc/hostname file will be erased
SCC_ADDONS | string | | Comma separated list of modules to be enabled using SCC/RMT.
SCC_DOCKER_IMAGE | string | | The content of /etc/zypp/credentials.d/SCCcredentials used by container-suseconnect-zypp zypper service in SLE base container images
SELECT_FIRST_DISK | boolean | false | Enables test module to select first disk for the installation. Is used for baremetal machine tests with multiple disks available, including cases when server still has previous installation.
ENABLE_SELINUX | boolean | false | Explicitly enable SELinux in transactional server environments.
SEPARATE_HOME | three-state | undef | Used for scheduling the test module where separate `/home` partition should be explicitly enabled (if `1` is set) or disabled (if `0` is set). If not specified, the test module is skipped.
SES5_CEPH_QA_HEALTH_OK | string | | URL for repo containing ceph-qa-health-ok package.
SKIP_CERT_VALIDATION | boolean | false | Enables linuxrc parameter to skip certificate validation of the remote source, e.g. when using self-signed https url.
SET_CUSTOM_PROMPT | boolean | false | Set a custom, shorter prompt in shells. Saves screen space but can take time to set repeatedly in all shell sessions.
SLE_PRODUCT | string | | Defines SLE product. Possible values: `sles`, `sled`, `sles4sap`. Is mainly used for SLE 15 installation flow.
SOFTFAIL_BSC1063638 | boolean | false | Enable bsc#1063638 detection.
STAGING | boolean | false | Indicates staging environment.
SPECIFIC_DISK | boolean | false | Enables installation/partitioning_olddisk test module.
SPLITUSR | boolean | false | Enables `installation/partitioning_splitusr` test module.
SUSEMIRROR | string | | Mirror url of the installation medium.
SYSAUTHTEST | boolean | false | Enable system authentication test (`sysauth/sssd`)
SYSCTL_IPV6_DISABLED | boolean | undef | Set automatically in samba_adcli tests when ipv6 is disabled
TEST | string | | Name of the test suite.
TEST_CONTEXT | string | | Defines the class name to be used as the context instance of the test. This is used in the scheduler to pass the `run_args` into the loadtest function. If it is not given it will be undef.
TOGGLEHOME | boolean | false | Changes the state of partitioning to have or not to have separate home partition in the proposal.
TUNNELED | boolean | false | Enables the use of normal consoles like "root-consoles" on a remote SUT while configuring the tunnel in a local "tunnel-console"
TYPE_BOOT_PARAMS_FAST | boolean | false | When set, forces `bootloader_setup::type_boot_parameters` to use the default typing interval.
UEFI | boolean | false | Indicates UEFI in the testing environment.
UPGRADE | boolean | false | Indicates upgrade scenario.
USBBOOT | boolean | false | Indicates booting to the usb device.
USEIMAGES |||
VALIDATE_ETC_HOSTS | boolean | false | Validate changes in /etc/hosts when using YaST network module. Is used in yast2_lan and yast2_lan_restart test modules which test module in ncurses and x11 respectively.
VALIDATE_INST_SRC | boolean | false | Validate installation source in /etc/install.inf
VALIDATE_CHECKSUM | boolean | false | Validate checksum of the mediums. Also see CHECKSUM_*.
VERSION | string | | Contains major version of the product. E.g. 15-SP1 or 15.1
VIDEOMODE | string | | Indicates/defines video mode used for the installation. Empty value uses default, other possible values `text`, `ssh-x` for installation ncurses and x11 over ssh respectivelyю
VIRSH_OPENQA_BASEDIR | string | /var/lib | The OPENQA_BASEDIR configured on the svirt host (only relevant for the svirt backend).
UNENCRYPTED_BOOT | boolean | false | Indicates/defines existence of unencrypted boot partition in the SUT.
WAYLAND | boolean | false | Enables wayland tests in the system.
XDMUSED | boolean | false | Indicates availability of xdm.
XFS_MKFS_OPTIONS | string | | Define additional mkfs parameters. Used only in publiccloud test runs.
XFS_TEST_DEVICE | string | | Define the device used for xfs tests. Used only in publiccloud test runs.
XFS_TESTS_REFLINK | boolean | false | If set to true, the mkfsoption for using reflink will be added. Used only in publiccloud test runs.
YAML_SCHEDULE_DEFAULT | string | | Defines default yaml file to be overriden by test suite schedule.
YAML_SCHEDULE_FLOWS | string | | Defines a comma-separated values representing additional flows which overrides steps on the schedule specified in YAML_SCHEDULE_DEFAULT.
YAML_SCHEDULE | string | | Defines yaml file containing test suite schedule.
YAML_TEST_DATA | string | | Defines yaml file containing test data.
YUI_LOG_LEVEL | string | debug | Allows changing log level for YuiRestClient::Logger. Available options are: debug, info, warning, error, fatal.
YUI_PORT | integer | | Port being used for libyui REST API. See also YUI_SERVER and YUI_START_PORT.
YUI_SERVER | string | | libyui REST API server name or ip address.
YUI_START_PORT | integer | 39000 | Sets starting port for the libyui REST API, on qemu VNC port is then added to this port not to have conflicts.
YUI_REST_API | boolean | false | Is used to setup environment for libyui REST API, as some parameters have to be set before the VM is started.
YUI_PARAMS | string | | libyui REST API params required to open YaST modules
ZDUP | boolean | false | Prescribes zypper dup scenario.
ZDUPREPOS | string | | Comma separated list of repositories to be added/used for zypper dup call, defaults to SUSEMIRROR or attached media, e.g. ISO.
ZFCP_ADAPTERS | string | | Comma separated list of available ZFCP adapters in the machine (usually 0.0.fa00 and/or 0.0.fc00)
LINUXRC_BOOT | boolean | true | To be used only in scenarios where we are booting an installed system from the installer medium (for example, a DVD) with the menu option "Boot Linux System" (not "boot From Hard Disk"). This option uses linuxrc.
ZYPPER_WHITELISTED_ORPHANS | string | empty | Whitelist expected orphaned packages, do not fail if any are found. Upgrade scenarios are expecting orphans by default. Used by console/orphaned_packages_check.pm
PUBLIC_CLOUD_CONTAINER_IMAGES_REPO | string | | The Container images repository in CSP
PREPARE_TEST_DATA_TIMEOUT | integer | 300 | Download assets in the prepare_test_data module timeout
ZFS_REPOSITORY | string | | Optional repository used to test zfs from
TRENTO_HELM_VERSION | string | 3.8.2 | Helm version of the JumpHost
TRENTO_CYPRESS_VERSION | string | 4.4.0 | used as tag for the docker.io/cypress/included registry
TRENTO_VM_IMAGE | string | SUSE:sles-sap-15-sp3-byos:gen2:latest | used as --image parameter during the Azure VM creation
TRENTO_VERSION | string | (implicit 1.0.0) | Optional. Used as reference version string for the installed Trento
TRENTO_REGISTRY_CHART | string | registry.suse.com/trento/trento-server | Helm chart registry
TRENTO_REGISTRY_CHART_VERSION | string |  | Optional. Tag for the chart image
TRENTO_REGISTRY_IMAGE_RUNNER | string |  | Optional. Overwrite the trento-runner image in the helm chart
TRENTO_REGISTRY_IMAGE_RUNNER_VERSION | string |  | Optional. Version tag for the trento-runner image
TRENTO_REGISTRY_IMAGE_WEB | string |  | Optional. Overwrite the trento-web image in the helm chart
TRENTO_REGISTRY_IMAGE_WEB_VERSION | string |  | Optional. Version tag for the trento-web image
TRENTO_GITLAB_REPO | string | gitlab.suse.de/qa-css/trento | Repository for the deployment scripts
TRENTO_GITLAB_BRANCH | string | master | Branch to use in the deployment script repository


### Publiccloud specific variables

The following variables are relevant for publiccloud related jobs. Keep in mind that variables that start with `_SECRET` are secret variables, accessible only to the job but hidden in the webui. They will be not present in cloned jobs outside the original instance.

Variable        | Type      | Default value | Details
---             | ---       | ---           | ---
PUBLIC_CLOUD | boolean | false | All Public Cloud tests have this variable set to true. Contact: qa-c@suse.de
PUBLIC_CLOUD_ACCOUNT | string | "" | For GCE will set account via `gcloud config set account ' . $self->account`.
PUBLIC_CLOUD_ACCNET | boolean | false | If set, az_accelerated_net test module is added to the job.
PUBLIC_CLOUD_HDD2_SIZE | integer | "" | If set, the instance will have an additional disk with the given capacity in GB
PUBLIC_CLOUD_HDD2_TYPE | string | "" | If PUBLIC_CLOUD_ADDITIONAL_DISK_SIZE is set, this defines the additional disk type (optional). The required value depends on the cloud service provider.
PUBLIC_CLOUD_ARCH | string | "x86_64" | The architecture of created VM.
PUBLIC_CLOUD_AZURE_OFFER | string | "" | Specific to Azure. Allow to query for image based on offer and sku. Should be used together with PUBLIC_CLOUD_AZURE_SKU.
PUBLIC_CLOUD_AZURE_SKU | string | "" | Specific to Azure.
PUBLIC_CLOUD_BUILD | string | "" | The image build number. Used only when we use custom built image.
PUBLIC_CLOUD_BUILD_KIWI | string | "" | The image kiwi build number. Used only when we use custom built image.
PUBLIC_CLOUD_CHECK_BOOT_TIME | boolean | false | If set, boottime test module is added to the job.
PUBLIC_CLOUD_GOOGLE_CLIENT_ID | string | "" | In GCE one of the variables used to authenticate  user.
PUBLIC_CLOUD_CONFIDENTIAL_VM | boolean | false | GCE Confidential VM instance
PUBLIC_CLOUD_UPLOAD_IMG | boolean | false | If set, `publiccloud/upload_image` test module is added to the job.
PUBLIC_CLOUD_CONSOLE_TESTS | boolean | false | If set, console tests are added to the job.
PUBLIC_CLOUD_CONTAINERS | boolean | false | If set, containers tests are added to the job.
PUBLIC_CLOUD_DOWNLOAD_TESTREPO | boolean | false | If set, it schedules `publiccloud/download_repos` job.
PUBLIC_CLOUD_TOOLS_CLI | boolean | false | If set, it schedules `publiccloud_tools_cli` job group.
PUBLIC_CLOUD_EC2_UPLOAD_AMI | string | "" | Needed to decide which image will be used for helper VM for upload some image. When not specified some predefined value will be used. Overwrite the value for `ec2uploadimg --ec2-ami`.
PUBLIC_CLOUD_EC2_UPLOAD_SECGROUP | string | "" | Allow to instruct ec2uploadimg script to use some existing security group instead of creating new one. If given, the parameter `--security-group-ids` is passed to `ec2uploadimg`.
PUBLIC_CLOUD_EC2_UPLOAD_VPCSUBNET | string | "" | Allow to instruct ec2uploadimg script to use some existing VPC instead of creating new one.
PUBLIC_CLOUD_FIO | boolean | false | If set, storage_perf test module is added to the job.
PUBLIC_CLOUD_FIO_RUNTIME | integer | 300 | Set the execution time for each FIO tests.
PUBLIC_CLOUD_FIO_SSD_SIZE | string | "100G" | Set the additional disk size for the FIO tests.
PUBLIC_CLOUD_GOOGLE_UPLOAD_GUEST_FEATURES | string | "" | The list of features given to upload VM
PUBLIC_CLOUD_IGNORE_EMPTY_REPO | boolean | false | Ignore empty maintenance update repos
PUBLIC_CLOUD_IMAGE_ID | string | "" | The image ID we start the instance from
PUBLIC_CLOUD_IMAGE_LOCATION | string | "" | The URL where the image gets downloaded from. The name of the image gets extracted from this URL.
PUBLIC_CLOUD_IMAGE_PROJECT | string | "" | Google Compute Engine image project
PUBLIC_CLOUD_IMG_PROOF_TESTS | string | false | Tests run  by img-proof. (We use 'default')
PUBLIC_CLOUD_INSTANCE_TYPE | string | "" | Specify the instance type. Which instance types exists depends on the CSP. (default-azure: Standard_A2, default-ec2: t2.large )
PUBLIC_CLOUD_KEY | string | "" | Private key data for gce, similar to `PUBLIC_CLOUD_KEY_SECRET`.
PUBLIC_CLOUD_KEY_ID | string | "" | The CSP credentials key-id to used to access API.
PUBLIC_CLOUD_KEY_SECRET | string | "" | The CSP credentials secret used to access API.
PUBLIC_CLOUD_LTP | boolean | false | If set, the run_ltp test module is added to the job.
PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE | boolean | false | Do not remove the instance when the test fails.
PUBLIC_CLOUD_PERF_DB_URI | string | "" | Optional variable. If set, the bootup times get stored in the influx database. The database name is 'publiccloud'. (e.g. PUBLIC_CLOUD_PERF_DB_URI=http://openqa-perf.qa.suse.de:8086)
PUBLIC_CLOUD_PREPARE_TOOLS | boolean | false | Activate prepare_tools test module by setting this variable.
PUBLIC_CLOUD_GOOGLE_PROJECT_ID | string | "" | GCP only, used to specify the project id.
PUBLIC_CLOUD_PROVIDER | string | "" | The type of the CSP (e.g. AZURE, EC2, GCE).
PUBLIC_CLOUD_QAM | boolean | false | Previously used to recognize maintenance jobs - now deprecated - should be removed.
PUBLIC_CLOUD_REBOOT_TIMEOUT | integer | 600 | Number of seconds we wait for instance to reboot.
PUBLIC_CLOUD_REGION | string | "" | The region to use. (default-azure: westeurope, default-ec2: eu-central-1, default-gcp: europe-west1).
PUBLIC_CLOUD_RESOURCE_GROUP | string | "qashapopenqa" | Allows to specify resource group name on SLES4SAP PC tests.
PUBLIC_CLOUD_RESOURCE_NAME | string | "openqa-vm" | The name we use when creating our VM.
PUBLIC_CLOUD_SKIP_MU | boolean | false | Debug variable used to run test without maintenance updates repository being applied.
PUBLIC_CLOUD_REDOWNLOAD_MU | boolean | false | Debug variable used to redownload the maintenance repositories (as they might be downloaded by parent test)
PUBLIC_CLOUD_GOOGLE_ACCOUNT | string | "" | GCE only, used to specify the account id.
PUBLIC_CLOUD_GOOGLE_SERVICE_ACCOUNT | string | "" | GCE only, used to specify the service account.
PUBLIC_CLOUD_AZURE_TENANT_ID | string | "" | Used to create the service account file together with `PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID`.
PUBLIC_CLOUD_TOOLS_REPO | string | false | The URL to the cloud:tools repo (optional). (e.g. http://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Tumbleweed/Cloud:Tools.repo).
PUBLIC_CLOUD_TTL_OFFSET | integer | 300 | This number + MAX_JOB_TIME equals the TTL of created VM.
PUBLIC_CLOUD_SLES4SAP | boolean | false | If set, sles4sap test module is added to the job.
PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID | string | "" | Used to create the service account file together with `PUBLIC_CLOUD_AZURE_TENANT_ID`.
PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY | string | "" | Name for public cloud registry for the container images used on kubernetes tests.
PUBLIC_CLOUD_K8S_CLUSTER | string | "" | Name for the kubernetes cluster.
PUBLIC_CLOUD_AZURE_K8S_RESOURCE_GROUP | string | "" | Name for the resource group which is subscribed the kubernetes cluster.
PUBLIC_CLOUD_CREDENTIALS_URL | string | "" | Base URL where to get the credentials from. This will be used to compose the full URL together with `PUBLIC_CLOUD_NAMESPACE`.
PUBLIC_CLOUD_NAMESPACE | string | "" | The Public Cloud Namespace name that will be used to compose the full credentials URL together with `PUBLIC_CLOUD_CREDENTIALS_URL`.
PUBLIC_CLOUD_USER | string | "" | The public cloud instance system user.
PUBLIC_CLOUD_XEN | boolean | false | Indicates if this is a Xen test run.
PUBLIC_CLOUD_STORAGE_ACCOUNT | string | "" | Storage account used e.g. for custom disk and container images
PUBLIC_CLOUD_TERRAFORM_FILE | string | "" | If defined, use this terraform file (from the `data/` directory) instead the CSP default
TERRAFORM_TIMEOUT | integer | 1800 | Set timeout for terraform actions
PUBLIC_CLOUD_INSTANCE_IP | string | "" | If defined, no instance will be created and this IP will be used to connect to
_SECRET_PUBLIC_CLOUD_INSTANCE_SSH_KEY | string | "" | The `~/.ssh/id_rsa` existing key allowed by `PUBLIC_CLOUD_INSTANCE_IP` instance
