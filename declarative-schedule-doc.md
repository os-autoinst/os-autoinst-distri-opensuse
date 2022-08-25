# Declarative Schedule
- [Introduction](#introduction)
- [Overview](#overview)
- [Getting started](#getting-started)
	- [1. Create declarative schedule](#1-create-declarative-schedule)
		- [name](#name)
		- [description](#description)
		- [vars](#vars)
		- [conditional_schedule](#conditional_schedule)
		- [schedule](#schedule)
		- [test_data](#test_data)
        - [importing](#importing)
	- [2. Enable scheduler in settings](#2-enable-scheduler-in-settings)
	- [3. Enable scheduler in main file](#3-enable-scheduler-in-main-file)
	- [4. Use different schedules for the same scenario](#4-use-different-schedules-for-the-same-scenario)
	- [5. Use YAML_SCHEDULE_DEFAULT and YAML_SCHEDULE_FLOWS along with YAML schedule](#5-use-default-flow-to-yaml-schedule)
- [Other uses](#other-uses)

## Introduction

This is the documentation for declarative scheduling of test modules
which allows testers to schedule existing test modules in a more flexible way replacing main.pm mechanism.
However it is still work-in-progress due to it missing some features to be a full working solution
to replace it.

## Overview

 Declarative schedule is using a [YAML](https://en.wikipedia.org/wiki/YAML) file to specify all the information related with a test suite:
 - Test suite name and description
 - Test variables
 - Sequence of test modules

## Getting started

Prerequisites to use this mechanism are the following:

### 1. Create declarative schedule

The file to be created should look as follows:
```yaml
name:           test_suite_name
description:    >
    Test suite description.
    Further info about the test suite
vars:
    setting1_string: value1
    setting2_num: 2
    setting3_string: value3
    ...
conditional_schedule:
    module1:
        VAR1:
            <valueA>:
                - path/to/module/moduleA1
                - path/to/module/moduleA2
            <valueB>:
                - path/to/module/moduleB1
    ...

schedule:
    - '{{module1}}'
    - path/to/module/module2
    ...
test_data:
  list:
    - item1
    - item2
  hash:
    key1: value1
    key2: value2  
```
Previous structure contains the following sections:

#### name
Name of the test suite

#### description
Description of the test suite.

#### vars
Most of your settings could be migrated from openQA WebUI to this declarative way, for instance:
  - `BOOTFROM: c`
  - `BOOT_HDD_IMAGE: 1`

There are a few exceptions:
  - `DESKTOP`: it produces wrong .json in openQA WebUI
  - `HDD_1`: if added, openQA will not publish the image in openQA WebUI due to it depends on os-autoinst.
  - `START_AFTER_TEST`: if added, openQA will not link dependencies on the corresponding tab in openQA WebUI due to it depends on os-autoinst.
-   `UEFI_PFLASH_VARS`: if added, openQA will not publish in UI

#### conditional_schedule
Depending on different values of an environmental variable we can schedule different set of modules.
For instance, depending on the value of DISTRI setting we can schedule an ordered sequence of different tests for openSUSE or SLE.

```yaml
  conditional_schedule:
      addons_repos:
          DISTRI:
              opensuse:
                  - installation/online_repos
                  - installation/installation_mode
                  - installation/logpackages
              sle:
                  - installation/scc_registration
                  - installation/addon_products_sle
                  - installation/addon_products_sle
```

#### schedule
Refers to a sequence of test modules to be executed in the test suite. For the moment it was chosen this format `'{{...}}''`
to indicate that the module or modules executed at this position is conditional to some variable as described in [conditional_schedule](#conditional_schedule).

NOTE: Please, do not forget to wrap conditional schedule in quotes as `{` and `}` are special symbols and can affect parsing.

**NOTE:**
 - [conditional_schedule](#conditional_schedule) does not allow at the moment to represent complex logic like combination of 'and' or 'or' and it does intend to do it due to potentially it would create the same problem that occurs with main.pm. Other kind of logic like a simple exclusion list could be feasible in the near future, for example "run for all except when this variable value is set to some specific value". Reusing of blocks needs to be re-thinked as well and what would be a readable syntax for this. At the moment if the scenario you intend to migrate has complex conditional logic it would require changes in your test modules.
 - Nested conditional schedules (eg. referencing another conditional schedule from within a conditional schedule) are possible now.
 - The only section that is mandatory is [schedule](#schedule). The rest of the sections in the YAML file can be skipped.

#### test_data
As vars.json has quite limited capabilities due to the design, in the yaml files
it's possible to define any structure, which can be described using plain yaml
format. This data can be accessed when calling `get_test_suite_data()`
method from `lib/scheduler.pm`. This feature is designed to store test related
data for data driven tests and provide better structure for the test suite settings.

The whole section is parsed with perl structures, so in case you have following
settings:
```
...
test_data:
  list:
    - item1
    - item2
  hash:
    key1: value1
    key2: value2
...
```
Your test code will look like:
```
sub run {
    my $test_data = get_test_suite_data();
    foreach my $item (@{$test_data->{list}}) {
        diag $item;
    }

    while (($key, $value) = each (%{$test_data->{hash}})) {
        diag "$key: $value";
    }
}
```

#### importing
Besides having the whole data in the same yaml file for scheduling, it is possible to import some parts of it.
[YAML::PP::Schema::Include](https://metacpan.org/pod/YAML::PP::Schema::Include) and
[YAML::PP::Schema::Merge](https://metacpan.org/pod/YAML::PP::Schema::Merge) are used for this purpose.

Please see the example for `test_data` below (which also can be applied to other sections):

For instance, there is a test data file named `scenario_name_test_data.yaml` containing data as follows:

 ```
 disks:
  - name: vda
    partitions:
      - size: 2mb
  ...
```
And it is possible to include that data into `scenario_name.yaml` using `<<:`(merge feature) and `!include` with the path to the file:
```
name:           scenario_name_test_data.yaml
description:    >
  ...
vars:
...
schedule:
  - path/to/module
...
test_data:
  <<: !include schedule/path/to/scenario_name_test_data.yaml
```
-  it is allowed to use multiple `!include` in yaml scheduling
   file. For example:

```
...
test_data:
  <<: !include path/to/first_test_data.yaml
  <<: !include path/to/second_test_data.yaml
```

- included data can be mixed with the test data that is defined in
  scheduling file directly:

> **_IMPORTANT:_** Test data in scheduling file has priority over the
> same data from the imported file (i.e. it allows to override imported
> data). Latest included data has priority over previous included data.
```
...
test_data:
  disks:
    - name: vdb
      partitions:
        - size: 3mb
  <<: !include path/to/test_data.yaml
```
Test data sometimes is more related to a particular schedule, sometimes  
to other test data shared with other test suites and sometimes it is a mix.  
In those cases, `YAML_TEST_DATA` setting can be used to give us the flexibility  
to avoid duplicate schedule files just because they have different data and due  
to it will be pointing to a test data file. Only for this particular case,  
the possibility to use `$include` functionality in test data file is allowed. For instance:

In your yaml for your Job Group configuration for one product you could have:
```
- test_suite_name:
        machine: 64bit
        priority: 30
        settings:
          YAML_SCHEDULE: schedule/path/to/schedule.yaml
          YAML_TEST_DATA=path/to/test_data_product_A.yaml

```
And for the other product and the same test suite:
```
- test_suite_name:
        machine: 64bit
        priority: 30
        settings:
          YAML_SCHEDULE: schedule/path/to/schedule.yaml
          YAML_TEST_DATA=path/to/test_data_product_B.yaml
```
In one of those data file we could find:
```
disks:
  - name: vda
    partitions:
      - size: 2mb
<<: !include path/to/test_data/shared/among/test_suites.yaml
  ...
```
In the other data file we could have:
```
disks:
  - name: vdb
    partitions:
      - size: 5mb
<<: !include path/to/test_data/shared/among/test_suites.yaml
  ...
```

> **_IMPORTANT:_** Test data from data file only when `YAML_TEST_DATA` is used has priority over `test_data` from
> schedule file. Test data in data file has priority over the same data from the imported file (i.e. it
> allows to override imported data). Latest included data has priority over previous included data in test
> data file.

Additionally in the test_data structure for your scenario you can expand variables from vars.json, for instance:
```
test_data:
  repos:
    - name:  SLES-%VERSION%
      alias: SLES
      enabled: No
```

### 2. Enable scheduler in settings

It is required to add in openQA WebUI in the test suite configuration a new setting `YAML_SCHEDULE` pointing to .yaml file path, for instance:
`YAML_SCHEDULE=schedule/test-suite-name.yaml`


### 3. Enable scheduler in main file

This functionality needs to be imported in corresponding main.pm for your product.
Only if `YAML_SCHEDULE` setting is set, information contained in .yaml file will be loaded and
execution of main.pm will be exited earlier and in turn the old main.pm mechanism will not be executed.
It is recommended to call the function after all variables have been set in main.pm.
 ```perl
 use scheduler 'load_yaml_schedule';
...
return 1 if load_yaml_schedule;
```

### 4. Use different schedules for the same scenario

Due to the fact that different backends need extra steps and that we want to abstract from the details,
we might want to use single scenario even when there are distinct.
For example, RAID 0 on UEFI will require different partitioning then in case of legacy boot.
Since we got Job template YAML feature, we can easily manage small and big discrepancies.

Consider example with RAID 0, assume we have multiple architectures to test on, then our scenarios section
can look like following:

```yaml
scenarios:
  aarch64:
    medium:
    - RAID0:
        settings:
          YAML_SCHEDULE: schedule/yast/raid/raid0_sle_gpt_uefi.yaml
  ppc64le:
    medium:
    - RAID0:
      settings:
        YAML_SCHEDULE: schedule/yast/raid/raid0_sle_gpt_prep_boot.yaml
  ppc64le:
    medium:
    - RAID0:
      settings:
        YAML_SCHEDULE: schedule/yast/raid/raid0_sle_gpt_prep_boot.yaml
  x86_64:
    medium:
    - RAID0_gpt:
      settings:
        YAML_SCHEDULE: schedule/yast/raid/raid0_sle_gpt.yaml
```

You have differences due to backend implementation? Not a problem, you can override
settings per machine:

```yaml
scenarios:
  x86_64:
    medium:
    - minimal+base_yast:
      machine: 64bit
      settings:
        YAML_SCHEDULE: schedule/yast/minimal+base/minimal+base@yast.yaml
    - minimal+base_yast:
      machine: svirt-xen-hvm
      settings:
        YAML_SCHEDULE: schedule/yast/minimal+base/minimal+base@yast-xen.yaml
    - minimal+base_yast:
      machine: svirt-hyperv
      settings:
        YAML_SCHEDULE: schedule/yast/minimal+base/minimal+base@yast-svirt-hyperv.yaml
```

And on top of that you can use aliases to avoid duplication. For more details, check output
[official documentation of openQA](http://open.qa/docs/)

### 5. Use YAML_SCHEDULE_DEFAULT and YAML_SCHEDULE_FLOWS to YAML schedule


We have 3 variables to help YAML scheduler to avoid conditional schedule and repetition. They are YAML_SCHEDULE_DEFAULT, YAML_SCHEDULE_FLOWS, YAML_SCHEDULE. We have the possibility to combine these 3 variables to customize your loading modules, but individually they don't solve the problem, in particular YAML_SCHEDULE doesn't.

Please be noted that conditional schedule does not work when scheduler is using DEFAULT and FLOWS. And flows are optional, you can have a default and on top the yaml schedule and not use flows.

YAML_SCHEDULE_DEFAULT should point to a "default"(product defaults + testing defaults) schedule that has sections.  You can find them in schedule/yast/sle/flows/default.yaml. Sections can have "normal yaml schedule lines" or an empty list which act as a hook where you can have more granularity when overwriting (indicated by "[]").

```yaml
# Default ordered sequence of steps to be optionally overwritten for this product
bootloader:
  - installation/bootloader_start
setup_libyui:
  - installation/setup_libyui
access_beta: []
product_selection:
  - installation/product_selection/install_SLES
license_agreement:
  - installation/licensing/accept_license

```

YAML_SCHEDULE_FLOW is a comma-separated list of "flow" modules. like schedule/yast/sle/flows

Example: desktop.yaml:
```yaml
---
# Register Desktop Applications Module in Extension and Module Selection
# Select SLES with GNOME in System Role
extension_module_selection:
  - installation/module_registration/register_module_desktop
system_role:
  - installation/system_role/accept_selected_role_SLES_with_GNOME
```
So, in default.yaml we have

```yaml
extension_module_selection:
  - installation/module_registration/skip_module_registration
```
And when applying the "flow" desktop.yaml, this will be replaced by:

```yaml
extension_module_selection:
  - installation/module_registration/register_module_desktop
```
General rule is: 
Every list of modules under a key (e.g extension_module_selection) in the flow will overwrite the corresponding list in "default".
When all flows are applied, we finally apply on top (overwriting default+flows) "YAML_SCHEDULE" which then defines the individual test modules for the test suite.

Example: guided_ext4/ext4.yaml:
```yaml
name:           guided_ext4
description:    >
  Guided Partitioning installation with ext4 filesystem.
vars:
  FILESYSTEM: ext4
  YUI_REST_API: 1
schedule:
  guided_filesystem:
    - installation/partitioning/guided_setup/select_filesystem_option_ext4
  default_systemd_target:
    - installation/installation_settings/validate_default_target
  system_validation:
    - console/validate_partition_table_via_blkid
    - console/validate_blockdevices
    - console/validate_free_space
test_data:
  guided_partitioning:
    filesystem_options:
      root_filesystem_type: ext4
  <<: !include test_data/yast/ext4/ext4.yaml
```

When combining the three layers
YAML_SCHEDULE_DEFAULT (the default)
YAML_SCHEDULE_FLOWS   (overwrite the above)
YAML_SCHEDULE         (overwrite the above)
We end up with a final yaml schedule that should not look different from what we're used so far.
YAML_SCHEDULE_DEFAULT is usually defined in the job group, the defaults, YAML_SCHEDULE_FLOW and YAML_SCHEDULE are defined in the job group on test suite level.

And last, please take care of the difference between job groups and the YAML schedule . For they are all stored in schedule directory. Job groups are a layer above that control what tests are executed in what way for specific platform/product combinations, which were controlled by YAML schedule.

## Other uses

Even if you don't intend to migrate your scenario right now, you can play with it for debugging purposes. Instead of relying in the complex path of execution that main.pm creates, if you just need to put some test in some particular order, perhaps a new scenario you just created, you can speed up your development using this approach.
