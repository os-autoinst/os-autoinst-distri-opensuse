# Supportserver generator guide
- [How to generate a supportserver](#How-to-generate-a-supportserver)
- [Using autoyast](#Using-autoyast)
- [Using create_hdd](#Using-create_hdd)
- [Supportserver_generator_from_hdd](#Supportserver_generator_from_hdd)

## How to generate a supportserver

There are two ways to create a supportserver. The first one is using a job called *supportserver_generator* using an Autoyast and the second leveraging the *create_hdd*

We are also obliged to generate two images based on the desktop that the test is used on. Thus we need separate qcow image to support test with gnome and another one for textmode.

## Using autoyast

In this case you need to find and provide an autoyast xml file with the configuration that you need. Some of the existing ones can be found in `os-autoinst-distri-opensuse/data/supportserver/`.

In general you have to make an API request to jobs with the required parameters (alike the isos post, it requires ARCH, FLAVOR, DISTRI, MACHINE, ISO etc), plus AUTOYAST with the xml file of your choice. In addition the PUBLISH_HDD_1 is needed to set the name of the generated cqow image. 

We provide a script to make this easier for textmode images. The script can be used as it is shown in the following example

```bash
./data/supportserver/autoyast_supportserver_generator_sle15.sh 209.2 aarch64 Online
```

where:
- 209.2 is the build number
- aarch64 represents the architecture
- Online is the Flavor (Online,Full)

The above values are the default, thus `./data/supportserver/autoyast_supportserver_generator_sle15.sh` will produce the same image as the command in the example with the parameters.

The producing image will have the name based on the arch. i include the creation date to be able to track when it was last updated. for instance
```
openqa_support_server_sles15sp2_aarch64_textmode_202007.qcow2
```

## Using create_hdd

The disadvantage with the Autoyast is that you need to get a working xml for your needs. The xml might change from build to build. In the other side we have `create_hdd_gnome` and `create_hdd_textmode` which can be used as normal jobs with some extra tweaking, to add particular configuration. The above mentioned job publish an qcow that we can leverage, boot into it and run the configuration that we want, and publish again under the corresponding name.

## supportserver_generator_from_hdd

To accelerate the creation we can chain the jobs between create_hdd_gnome/create_hdd_textmode and a job that is scheduled with the `schedule/supportserver_generator_from_hdd.yaml` yaml scheduler. The chained job has to be in accordance with the DESKTOP variable that it is used in the create_hdd(ex: DESKTOP=gnome if publish image is coming from create_hdd_gnome). The chained job has to have enabled the BOOT_HDD_IMAGE, HDD_1 and BOOTFROM. At the end we need to define the PUBLISH_HDD_1 with the new name of the supportserver.

```bash
openqa-cli api --osd -X POST isos TEST=supportserver_generator_from_hdd YAML_SCHEDULE=schedule/supportserver_generator_from_hdd.yaml PUBLISH_HDD_1=openqa_support_server_sles15sp2_%ARCH%_%BUILD%@%MACHINE%_%DESKTOP%.qcow2 DESKTOP=textmode START_AFTER_TEST=create_hdd_gnome:aarch64 BOOTFROM=c _SKIP_CHAINED_DEPS=1 CONSOLE_JUST_ACTIVATED=0 HDD_1=SLES-15-SP2-%ARCH%-Build%{BUILD}%@%ARCH%-%DESKTOP%.qcow2 {...}
```

where {...} are all the specific variables for the arch, build, etc
