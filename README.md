Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK 
============================================================================

> Overview

This project is inspired by [tete1030/openwrt-fastbuild-actions](https://github.com/tete1030/openwrt-fastbuild-actions/) and [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)

This project utilizes [tete1030/openwrt-fastbuild-actions](https://github.com/tete1030/openwrt-fastbuild-actions/) to build custom OpenWRT images with GitHub Action.

Building OpenWrt in Github Actions can be very convenient for users who want to upgrade or modify their routers frequently. Despite convenience, users have to wait for hours for even slight changes, because cache from previous buildings is not recycled.

By storing cache in docker images, BuildWrt significantly decreases compiling duration in Github Actions. You can use Docker Hub or other Docker registries as the storage.

- [Features Overview](#features-overview)
- [Usage](#usage)
  - [Setup](#setup)
    - [Secrets page](#secrets-page)
  - [Examples](#examples)
  - [Building](#building)
  - [Advanced usage](#advanced-usage)
    - [Re-create builder](#re-create-builder)
    - [Rebase your builder](#rebase-your-builder)
  - [Trigger methods](#trigger-methods)
  - [Building options](#building-options)
    - [Examples of using building options](#examples-of-using-building-options)
  - [Multiple target profiles](#multiple-target-profiles)
    - [Default profile](#default-profile)
  - [Manually adding packages](#manually-adding-packages)
- [Details](#details)
  - [Building process explained](#building-process-explained)
    - [First-time building](#first-time-building)
    - [Following buildings](#following-buildings)
  - [Squashing Strategy](#squashing-strategy)
- [Debugging and manually configuring](#debugging-and-manually-configuring)
  - [Important directories](#important-directories)
- [FAQs](#faqs)
  - [Why all targets seem triggered when only some are intended?](#why-all-targets-seem-triggered-when-only-some-are-intended)
- [Todo](#todo)
- [Acknowledgments](#acknowledgments)
- [License](#license)


- [OpenWRT Builder Action Steps](#steps-to-build-openwrt-images)
  - [Step01 - Init build env](#step01)
  - [Step02 - Check if skip this job](#step02)
  - [Step03 - Clean up for extra space if not in TEST mode](#step03)
  - [Step03a - Set up QEMU](#step03a)
  - [Step03b - Set up Docker Buildx](#step03b)
  - [Step04 - Configure docker](#step04)
  - [Step05 - Check status of builders](#step05)
  - [Step05a - Wait for SSH](#step05a)
  - [Step06 - Get Docker Builder Image](#step06)
  - [Step07 - Clone/update OpenWrt](#step07)
  - [Step08 - Apply customizations](#step08)
  - [Step08a - Debug/Menuconfig Wait for SSH connection (timeout 30min)](#step08a)
  - [Step09 - Prepare config file](#step09)
  - [Step11 - Compile w/ Multiple threads](#step11)
  - [Step12 - Compile w/ Single threads](#step12)
  - [Step12a - Failure/Debug Wait for SSH connection (timeout 30min)](#step12a)
  - [Step13 - Upload builder](#step13)
  - [Step14 - Organize files](#step14)


## Steps to build OpenWRT Images

### <a id="step01"/>Step01 - Init build env
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Init build env
  participant Host1 as Host<br>01-init_env.sh
  participant Host2 as Host<br>init_runner.sh
  participant Docker

  ActionStep ->> Host1: run "scripts/cisteps/build-openwrt/01-init_env.sh"
  Host1 ->> Host2: scripts/host/init_runner.sh" main build
  Host2 ->> Host2: main $@
  Host2 ->> Host2: install_commands
    note over Host2: Install extra commands
  Host2 ->> Host2: setup_envs
    note over Host2: Setup some OPENWRT_XXX env vars
  Host2 ->> Host2: check_test
    note over Host2: assign var TEST=1 if $BUILD_MODE=test
  Host2 ->> Host2: load_task
    note over Host2: Load building action
  Host2 ->> Host2: prepare_target
    note over Host2: Combine user/default/* and user/$TARGET/*<br> into user/current folder
  Host2 ->> Host2: load_options
    note over Host2: Load options of $BUILD_OPTS
  Host2 ->> Host2: update_builder_info
  Host2 ->> Host2: check_validity
  Host2 ->> Host2: prepare_dirs

```
---
<br><br>


### <a id="step02"/>Step - Check if skip this job
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Check if skip this job
  participant Host1 as Host<br>02-check_target.sh
  participant Docker

  ActionStep ->> Host1: run "scripts/cisteps/build-openwrt/02-check_target.sh"
```
---
<br><br>


### <a id="step03"/>Step - Clean up for extra space if not in TEST mode
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Clean up for extra space if not in TEST mode
  participant Host1 as Host<br>03-clean_up.sh
  participant Docker

  ActionStep ->> Host1: run "scripts/cisteps/build-openwrt/03-clean_up.sh"
```
---
<br><br>


### <a id="step03a"/>Step - Set up QEMU
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Set up QEMU
  participant Host1 as Host<br>uses: docker/setup-qemu-action@v1
  participant Docker

  ActionStep ->> Host1: if SKIP_TARGET == '0'
```
---
<br><br>


### <a id="step03b"/>Step - Set up Docker Buildx
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Set up Docker Buildx
  participant Host1 as Host<br>uses: docker/setup-buildx-action@v1
  participant Docker

  ActionStep ->> Host1: if SKIP_TARGET == '0'
```
---
<br><br>


### <a id="step04"/>Step - Configure docker
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Configure docker
  participant Host1 as Host<br>04-configure_docker.sh
  participant Docker

  ActionStep ->> Host1: if SKIP_TARGET == '0'<br>run: scripts/cisteps/build-openwrt/04-configure_docker.sh
  Host1 ->> Host1: docker login
```
---
<br><br>


### <a id="step05"/>Step - Check status of builders
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Check status of builders
  participant Host1 as Host<br>05-check_builders.sh
  participant Docker

  ActionStep ->> Host1: if SKIP_TARGET == '0'<br>run: scripts/cisteps/build-openwrt/05-check_builders.sh
```

And the flowchart of 05-check_builders.sh is:
```mermaid
flowchart LR
  subgraph sub_check_builder ["scripts/cisteps/build-openwrt/05-check_builders.sh"]
    direction TB
    check_rebuild -->|No| export_env
    check_rebuild -->|YES, Rebuild| docker_buildx_inc
    docker_buildx_inc -->|$OPT_REBASE==1 OR docker cmd failed| docker_buildx_rebase
    docker_buildx_inc -->|$OPT_REBASE==0 AND docker cmd ok| export_env
    docker_buildx_rebase -->|docker cmd failed| set_rebuild_opt
    docker_buildx_rebase -->|docker cmd ok| create_remote_tag_alias
    set_rebuild_opt --> export_env
    create_remote_tag_alias --> export_env
     

    check_rebuild{{"$OPT_REBUILD == 1 ?"}}
    docker_buildx_inc("docker buildx imagetools inspect<br>$BUILDER_IMAGE_ID_INC")
    docker_buildx_rebase("docker buildx imagetools inspect<br>$BUILDER_IMAGE_ID_BASE")
    create_remote_tag_alias("docker buildx imagetools create<br>$BUILDER_IMAGE_ID_BASE $BUILDER_IMAGE_ID_INC")
    set_rebuild_opt("set OPT_REBUILD=1")
    export_env("persistent_env_set OPT_REBUILD")
  end
  
```
---
<br><br>


### <a id="step05a"/>Step - Wait for SSH
Wait for SSH if  env.SKIP_TARGET == '0' && env.OPT_DEBUG == '1' && env.TEST != '1'
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - [Debug] Wait for SSH connection (timeout 5min)
  participant Host1 as Host<br>uses: tete1030/safe-debugger-action@dev
  participant Docker

  ActionStep ->> Host1: if SKIP_TARGET == '0'
```
---
<br><br>


### <a id="step06"/>Step - Get Docker Builder Image
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Get Docker Builder Image
  participant Host1 as Host<br>06-get_builder.sh
  participant Docker

  ActionStep ->> Host1: if SKIP_TARGET == '0'<br>run: scripts/cisteps/build-openwrt/06-get_builder.sh
```

And the flowchart of 06-get_builder.sh is:
```mermaid
flowchart LR
  subgraph sub_get_builder ["scripts/cisteps/build-openwrt/06-get_builder.sh"]
    direction TB
    init_docker --> check_rebuild
    check_rebuild -->|No| docker_run
    check_rebuild -->|YES, Rebuild| pull_image
    pull_image --> squash_image_when_necessary --> docker_run
    docker_run --> docker_exec

    init_docker("scripts/host/docker.sh")
    check_rebuild{{"$OPT_REBUILD == 1"}}
    pull_image("docker pull $BUILDER_IMAGE_ID_INC")
    squash_image_when_necessary("squash_image_when_necessary")
    docker_run("docker run ...")
    docker_exec(<div style='text-align: left'><h3>docker_exec scripts/init_env.sh:</h3><ul><li>apt-get install the required packages</li></ul><br></div>)
  end
```
---
<br><br>

### <a id="step07"/>Step - Clone/update OpenWrt
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Clone/update OpenWrt
  participant Host1 as Host<br>07-download_openwrt.sh
  participant Docker1 as Docker<br>scripts/update_ib_sdk.sh
  participant Docker2 as Docker<br>scripts/update_repo.sh
  participant Docker3 as Docker<br>scripts/update_feeds.sh

  ActionStep ->> Host1: if SKIP_TARGET == '0' run: <br>scripts/cisteps/build-openwrt/07-download_openwrt.sh
  Host1 ->> Docker1: docker_exec "${BUILDER_CONTAINER_ID}"<br> "${BUILDER_WORK_DIR}/scripts/update_ib_sdk.sh"
  Host1 ->> Docker2: docker_exec "${BUILDER_CONTAINER_ID}"<br> "${BUILDER_WORK_DIR}/scripts/update_repo.sh"
  Host1 ->> Docker3: docker_exec "${BUILDER_CONTAINER_ID}"<br> "${BUILDER_WORK_DIR}/scripts/update_feeds.sh"
```

And the flowchart of 07-download_openwrt.sh is:
```mermaid
flowchart LR
  subgraph sub_download_openwrt ["scripts/cisteps/build-openwrt/07-download_openwrt.sh"]
    direction TB
    update_ib_sdk --> update_repo --> update_feeds
    update_ib_sdk("docker_exec scripts/update_ib_sdk.sh")
    update_repo("docker_exec scripts/update_repo.sh")
    update_feeds("docker_exec scripts/update_feeds.sh")
  end
```
---
<br><br>

### <a id="step08"/>Step - Apply customizations
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Apply customizations
  participant Host1 as Host<br>08-customize.sh
  participant Docker1 as Docker<br>scripts/customize.sh

  ActionStep ->> Host1: if SKIP_TARGET == '0' run: <br>scripts/cisteps/build-openwrt/08-customize.sh
  Host1 ->> Docker1: docker_exec "${BUILDER_CONTAINER_ID}"<br> "${BUILDER_WORK_DIR}/scripts/customize.sh

```

And the flowchart of scripts/customize.sh is:
```mermaid
flowchart TB
  subgraph sub_customize_openwrt ["scripts/customize.sh"]
    direction TB
    apply_patches --> rsync_files --> sub_user_current_custom --> sub_scripts_custom_ib_sdk --> check_cache
    check_cache -->|Not Equal| sync_built_source
    check_cache -->|Equal| finish
    sync_built_source --> rm_built_source --> update_env --> finish
    
    apply_patches("Apply patches in user/current/patches")
    rsync_files("rsync user/current/{files,key-build*} to ${OPENWRT_CUR_DIR}/")
    check_cache{{"$OPENWRT_CUR_DIR != $OPENWRT_COMPILE_DIR ?"}}
    sync_built_source("rsync ${OPENWRT_CUR_DIR}/ $OPENWRT_COMPILE_DIR/")
    rm_built_source("rm -rf $OPENWRT_CUR_DIR")
    update_env("OPENWRT_CUR_DIR=${OPENWRT_COMPILE_DIR}<br>_set_env OPENWRT_CUR_DIR")
    finish(("END"))
  end

  subgraph sub_user_current_custom ["user/current/custom.sh"]
    direction TB
  end

  subgraph sub_scripts_custom_ib_sdk ["scripts/custom_ib_sdk.sh"]
    direction TB
  end
```
---
<br><br>


### <a id="step08a"/>Step - [Debug/Menuconfig] Wait for SSH connection (timeout 30min)
Wait for SSH if  env.SKIP_TARGET == '0' && env.OPT_DEBUG == '1' && env.TEST != '1'
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - [Debug/Menuconfig] Wait for SSH connection (timeout 30min)'
  participant Host1 as Host<br>uses: tete1030/safe-debugger-action@dev <br>TMATE_DOCKER_CONTAINER: ${{env.BUILDER_CONTAINER_ID}}
  participant Docker

  ActionStep ->> Host1: if SKIP_TARGET == '0'
```
---
<br><br>


### <a id="step09"/>Step - Prepare config file
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Prepare config file
  participant Host1 as Host<br>09-prepare_config.sh
  participant Docker1 as Docker<br>scripts/config.sh

  ActionStep ->> Host1: if SKIP_TARGET == '0' run: <br>scripts/cisteps/build-openwrt/09-prepare_config.sh
  Host1 ->> Docker1: docker_exec "${BUILDER_CONTAINER_ID}"<br> "${BUILDER_WORK_DIR}/scripts/config.sh
  Host1 ->> Docker1: docker_exec "${BUILDER_CONTAINER_ID}"<br> "${BUILDER_WORK_DIR}/scripts/diffconfig.sh
  Docker1 ->> Host1: pipe to "nc termbin.com 9999"<br>for URL to download config file.
```

And the flowchart of scripts/config.sh is:
```mermaid
flowchart TB
  subgraph sub_config_openwrt ["scripts/config.sh"]
    direction TB
    chdir_to_src --> make_defconfig --> make_oldconfig
    chdir_to_src("cd ${OPENWRT_CUR_DIR}")
    make_defconfig("make defconfig")
    make_oldconfig("make oldconfig")
  end
```
---
<br><br>


### <a id="step12a"/>Step - [Failure/Debug] Wait for SSH connection (timeout 30min)
Wait for SSH if env.SKIP_TARGET == '0' && !cancelled() && (job.status == 'failure' || (env.OPT_DEBUG == '1' && env.TEST != '1'))
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - [Debug/Menuconfig] Wait for SSH connection (timeout 30min)'
  participant Host1 as Host<br>uses: tete1030/safe-debugger-action@dev <br>TMATE_DOCKER_CONTAINER: ${{env.BUILDER_CONTAINER_ID}}
  participant Docker

  ActionStep ->> Host1: if SKIP_TARGET == '0'
```
---
<br><br>
   

### <a id="step13"/>Step - Upload builder
Upload builder if env.SKIP_TARGET == '0' && !cancelled() && (job.status == 'success' || env.OPT_PUSH_WHEN_FAIL == '1')
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Upload builder
  participant Host1 as Host<br>13-upload_builder.sh
  participant Docker1 as Docker<br>scripts/pre_commit.sh

  ActionStep ->> Host1: if SKIP_TARGET == '0' run: <br>scripts/cisteps/build-openwrt/13-upload_builder.sh
  Host1 ->> Docker1: docker_exec "${BUILDER_CONTAINER_ID}"<br> "${BUILDER_WORK_DIR}/pre_commit.sh
  Host1 ->> Host1: docker commit -a tete1030/openwrt-fastbuild-actions <br> ${BUILDER_CONTAINER_ID} ${BUILDER_IMAGE_ID_INC}"
  Host1 ->> Host1: docker container rm -fv "${BUILDER_CONTAINER_ID}"
  Host1 ->> Host1: docker container prune -f
  Host1 ->> Host1: docker system prune -f --volumes
  Host1 ->> Host1: if [ "x${OPT_REBUILD}" != 'x1' ] <br>  squash_image_when_necessary "${BUILDER_IMAGE_ID_INC}"
  Host1 ->> Host1: docker push "${BUILDER_IMAGE_ID_INC}"
  Host1 ->> Host1: if [ "x${OPT_REBUILD}" = "x1" ] <br> create_remote_tag_alias "${BUILDER_IMAGE_ID_INC}" "${BUILDER_IMAGE_ID_BASE}"
```

And the flowchart of scripts/pre_commit.sh is:
```mermaid
flowchart TB
  subgraph sub_pre_commit ["scripts/pre_commit.sh"]
    direction TB
    check_source_dir -->|Exists| rm_rf_source

    check_source_dir{{"[ -d ${OPENWRT_SOURCE_DIR} ] ?"}}
    rm_rf_source("rm -rf ${OPENWRT_SOURCE_DIR}")
  end
```
---
<br><br>

  
### <a id="step14"/>Step - Organize files
Organize filesif env.SKIP_TARGET == '0' && !cancelled()
```mermaid
sequenceDiagram
  autonumber
  actor ActionStep as Step - Organize files
  participant Host1 as Host<br>14-organize_files.sh
  participant Docker1 as Docker<br>scripts/pre_commit.sh

  ActionStep ->> Host1: if SKIP_TARGET == '0' run: <br>scripts/cisteps/build-openwrt/14-organize_files.sh
  Host1 ->> Docker1: docker_exec "${BUILDER_CONTAINER_ID}"<br> "${BUILDER_WORK_DIR}/pre_commit.sh
  Host1 ->> Host1: docker commit -a tete1030/openwrt-fastbuild-actions <br> ${BUILDER_CONTAINER_ID} ${BUILDER_IMAGE_ID_INC}"
  Host1 ->> Host1: docker container rm -fv "${BUILDER_CONTAINER_ID}"
  Host1 ->> Host1: docker container prune -f
  Host1 ->> Host1: docker system prune -f --volumes
  Host1 ->> Host1: if [ "x${OPT_REBUILD}" != 'x1' ] <br>  squash_image_when_necessary "${BUILDER_IMAGE_ID_INC}"
  Host1 ->> Host1: docker push "${BUILDER_IMAGE_ID_INC}"
  Host1 ->> Host1: if [ "x${OPT_REBUILD}" = "x1" ] <br> create_remote_tag_alias "${BUILDER_IMAGE_ID_INC}" "${BUILDER_IMAGE_ID_BASE}"
```

And the flowchart of scripts/pre_commit.sh is:
```mermaid
flowchart TB
  subgraph sub_pre_commit ["scripts/pre_commit.sh"]
    direction TB
    check_source_dir -->|Exists| rm_rf_source

    check_source_dir{{"[ -d ${OPENWRT_SOURCE_DIR} ] ?"}}
    rm_rf_source("rm -rf ${OPENWRT_SOURCE_DIR}")
  end
```
---
<br><br>

  
## Directory Hierarchy
```
user                                                                                                 #step01  scripts/host/init_runner.sh
├── default                                 # Default profile settings
│   ├── ib                                  # Files for ImageBuilder                                   
│   │   ├── config.diff                     # Extra options for .config                              #step09  scripts/config.sh
│   │   ├── disabled-services.ssv           # SpaceSeparatedVars for services to be disabed          #step09  scripts/config.sh
│   │   ├── packages.ssv                    # SpaceSeparatedVars for packages to be installed        #step09  scripts/config.sh
│   │   ├── profile.ssv                     # SpaceSeparatedVars for device profile (e.g. xiaomi_mi-router-ax3000t)
│   │   ├── feeds.conf                      # Extra feeds to be added                                #step08  scripts/custom_ib_sdk.sh  update_ib_repositories_conf
│   │   ├── custom.sh                       # Script before make                                     #step08  scripts/custom_ib_sdk.sh
│   │   ├── prepare_rootfs_hook.d           # Hook scripts before IB prepares rootfs                 #step11/12  scripts/compile.sh 
│   │   ├── files                           # Files to be added to ImageBuilder base folder          #step01  used by IB make rules
│   │   │   └── some dirs and files         
│   │   └── patches                         # Patches to be applied to IB                            #step08  scripts/custom_ib_sdk.sh  apply_patches_for_ib
│   │       └── *.patch
│   ├── sdk
│   │   ├── config.diff                     # Extra options for .config                              #step09  scripts/config.sh 
│   │   ├── feeds.conf                      # Extra feeds to be added                                #step08  scripts/custom_ib_sdk.sh  generate_sdk_feeds_conf 
│   │   ├── custom.sh                       # Script for customization (before config)               #step08  scripts/custom_ib_sdk.sh
│   │   ├── files                           # Files to be added to SDK                               #step01  used by SDK make rules
│   |   │   └── package                     # Files to be added to SDK/package/
│   │   │       └── some dirs and files         
│   │   └── patches                         # Patches to be applied to SDK                           #step08  scripts/custom_ib_sdk.sh  apply_patches_for_sdk
│   │       └── *.patch
│   └── source
│       ├── config.diff                     # Extra options for .config                              #step08  scripts/customize.sh
│       ├── feeds.conf                      # Extra feeds to be added                                #step07  scripts/update_feeds.sh  generate_source_feeds_conf
│       ├── packages.txt                    # Extra for packages to be added                         #step07  scripts/update_feeds.sh
│       ├── custom.sh                       # Script for customization (before config)               #step08  scripts/customize.sh
│       ├── files                           # Files to be added to Git Source                        #step01  used by Source make rules
│       │   └── package                     # Files to be added to SOURCE/package/
│       │       └── some dirs and files       
│       └── patches                         # Patches to be applied to Git Source                    #step08  scripts/customize.sh
│           └── *.patch
├── target1                                 # First target
│   ├── settings.ini                        # Settings                                               #step01  scripts/host/init_runner.sh
|   └── ...                                 # SAME HIERACHY AS user/default
└── target2                                 # Second target
│   ├── settings.ini                        # Settings                                               #step01  scripts/host/init_runner.sh
|   └── ...                                 # SAME HIERACHY AS user/default
└── targetN ...                             # More targets

```

In #step01 (scripts/host/init_runner.sh) will combine user/default and user/$BUILD_TARGET into user/current.

## Directories
```
BUILDER_WORK_DIR="/home/builder"
BUILDER_TMP_DIR="/tmp/builder"
HOST_TMP_DIR="/tmp/builder"
HOST_BIN_DIR="/home/builder/openwrt_bin"
HOST_WORK_DIR=${{github.workspace}}
BUILDER_BIN_DIR="${BUILDER_WORK_DIR}/openwrt_bin"      --> /home/builder/openwrt_bin
BUILDER_PROFILE_DIR="${BUILDER_WORK_DIR}/user/current" --> /home/builder/user/current
OPENWRT_COMPILE_DIR="${BUILDER_WORK_DIR}/openwrt"      -->  /home/builder/openwrt
OPENWRT_SOURCE_DIR="${BUILDER_TMP_DIR}/openwrt"        -->  /tmp/builder/openwrt

OPENWRT_CUR_DIR is Where Office OpenWRT GIT is cloned, which could be
  OPENWRT_CUR_DIR="${OPENWRT_SOURCE_DIR}"               -->  /tmp/builder/openwrt
  OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"              -->  /home/builder/openwrt  (Fresh build)

KOUHJ_SRC_DIR="${BUILDER_WORK_DIR}/kouhj_src"          --> /home/builder/kouhj_src  (gh repo clone kouhj/kouhj_openwrt_packages)

MY_DOWNLOAD_DIR="${BUILDER_WORK_DIR}/kbuilder/download"         -->  /home/builder/kbuilder/download    (Where IB & SDK are downloaded)
OPENWRT_MF_FILE="${MY_DOWNLOAD_DIR}/${MF_FILE}"                    -->  /home/builder/kbuilder/download/openwrt-XXX-XXX.manifest
OPENWRT_IB_DIR="${MY_DOWNLOAD_DIR}/${OPENWRT_IB_FILE%.tar.xz}"     -->  /home/builder/kbuilder/download/openwrt-imagebuilder-XXX.Linux-x86_64
OPENWRT_SDK_DIR="${MY_DOWNLOAD_DIR}/${OPENWRT_SDK_FILE%.tar.xz}"   -->  /home/builder/kbuilder/download/openwrt-sdk-XXX_gcc-X.X.X_musl.Linux-x86_64

```

Docker Directory Mappings:
| Host Directory                                      | Docker Directory                                       |
| --------------------------------------------------- | ------------------------------------------------------ |
| ${HOST_WORK_DIR}/                                   | ${BUILDER_WORK_DIR}/                                   |
|  /home/runner/work/openwrt_builder/openwrt_builder/ |  /home/builder/                                        |
| ${HOST_WORK_DIR}/kbuilder                           | ${BUILDER_WORK_DIR}/kbuilder  (/home/builder/scripts)  |
| ${HOST_WORK_DIR}/kouhj_src                          | ${BUILDER_WORK_DIR}/kouhj_src  (/home/builder/scripts) |
| ${HOST_WORK_DIR}/scripts                            | ${BUILDER_WORK_DIR}/scripts  (/home/builder/scripts)   |
| ${HOST_WORK_DIR}/user                               | ${BUILDER_WORK_DIR}/user   (/home/builder/user)        |
| ${HOST_BIN_DIR} (/home/builder/openwrt_bin)         | ${BUILDER_BIN_DIR}  (/home/builder/openwrt_bin)        |
| ${HOST_TMP_DIR} (/tmp/builder)                      | ${BUILDER_TMP_DIR}  (/tmp/builder)                     |
| ${GITHUB_ENV}                                       | ${GITHUB_ENV}                                          |




## Supported Devices

This repository currently supports the following device targets:

| Target Name | Device | Target Board | Subtarget | Architecture | Profile |
|-------------|--------|--------------|-----------|--------------|---------|
| x64 | Generic x86_64 | x86 | 64 | x86_64 | - |
| ax6s | Xiaomi Redmi Router AX6S | mediatek | mt7622 | aarch64_cortex-a53 | xiaomi_redmi-router-ax6s |
| ax3000t | Xiaomi Mi Router AX3000T | mediatek | mt7981 | aarch64_cortex-a53 | xiaomi_mi-router-ax3000t |
| cr6609 | Xiaomi Mi Router CR6609 | ramips | mt7621 | mipsel_24kc | xiaomi_mi-router-cr6609 |

To add a new target, create a directory under `user/<target_name>/` with the same structure as existing targets and update the workflow file.
