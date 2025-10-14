*** Settings ***
Resource    zarhus-lib.robot


*** Keywords ***
Flash Bootstrap USB
    [Documentation]    Flash Bootstrap USB
    [Arguments]    ${bootstrap_file}
    Boot Dasharo Tools Suite    iPXE
    Enter Shell In DTS

    # Send bootstrap image directly to USB stick
    ${device}=    Get First USB Stick In Linux
    Execute Command In Terminal    systemctl start sshd
    Send File To DUT Directly    ${bootstrap_file}    /dev/${device}

    # Add boot menu to make sure it's default boot option
    Execute Command In Terminal Should Succeed
    ...    mount -o remount,rw efivarfs
    ...    Failed to remount efivarfs as read-writable
    Execute Command In Terminal Should Succeed
    ...    efibootmgr --disk "/dev/${device}" --part 1 --create --label "Zarhus Bootstrap" --loader '\\EFI\\BOOT\\bootx64.efi'
    ...    Failed to create new Boot Entry for bootstrap USB stick

Install ZPB OS
    [Documentation]    Install Zarhus Provisioning Box OS via ZPB bootstrap USB
    ...
    ...    === Requirements ===
    ...    - ``${ZARHUS_BOOTSTRAP_FILE}`` defined with path to Zarhus OS
    ...    \ Bootstrap image. Flashed directly on USB.
    ...
    ...    === Arguments ===
    ...    - ``${disk}``: ``string`` - device on which to install Zarhus OS
    ...
    ...    === Return Value ===
    ...
    ...    === Effects ===
    ...    - Flashes ``${ZARHUS_BOOTSTRAP_FILE}`` to USB stick on hardware
    ...    - Runs `install.sh` script from bootstrap image which installs ZPB
    ...    \ OS on ``${disk}`` and flashes pre-configured firmware image
    [Arguments]    ${disk}=nvme0n1
    OperatingSystem.File Should Exist    ${ZARHUS_BOOTSTRAP_FILE}

    VAR    ${os_username_old}=    ${DEVICE_OS_USERNAME}
    VAR    ${os_password_old}=    ${DEVICE_OS_PASSWORD}
    VAR    ${DEVICE_OS_USERNAME}=    root    scope=Test
    VAR    ${DEVICE_OS_PASSWORD}=    ${EMPTY}    scope=Test
    IF    '${MANUFACTURER}' == 'QEMU'
        Boot Dasharo Tools Suite    iPXE
    ELSE
        Make Sure That Flash Locks Are Disabled
        Set UEFI Option    MeMode    Disabled (HAP)
        Flash Bootstrap USB    ${ZARHUS_BOOTSTRAP_FILE}
        # Boot into bootstrap USB stick
        Execute Reboot Command
        Set DUT Response Timeout    2m
        Wait For Checkpoint    ${DTS_CHECKPOINT}
    END
    Enter Shell In DTS

    # Mount partition containing install script
    Execute Command In Terminal Should Succeed
    ...    mount /dev/disk/by-label/zarhus-dtrpb /mnt

    IF    '${MANUFACTURER}' == 'QEMU'
        Execute Command In Terminal Should Succeed
        ...    gunzip -c /mnt/zarhus-base-image-genericx86-64.rootfs.wic.gz >/dev/${disk}
    ELSE
        # Run install.sh script
        Write Into Terminal    ./mnt/install.sh
        ${selection}=    Read From Terminal Until    Enter selection
        ${selection_lines}=    Split To Lines    ${selection}
        VAR    ${selected_line}=    ${EMPTY}
        FOR    ${line}    IN    ${selection_lines}
            IF    """${disk}""" in """${line}"""
                VAR    ${selected_line}=    ${line}
                BREAK
            END
        END
        IF    """${disk}""" not in """${selected_line}"""
            Fail    Couldn't find ${disk} in output of install.sh script
        END

        # return `<x>` from `<x>) ${device}`
        ${index}=    Replace String Using Regexp
        ...    ${selected_line}    \(\\d+\).*    \\1

        Write Into Terminal    ${index}
        Wait For Checkpoint And Write    Type 'YES' to continue:    YES
        Read From Terminal Until    You can now reboot the platform
        Read From Terminal Until Prompt
        ${rc}=    Execute Command In Terminal    echo $?
        Should Be Equal As Integers    ${rc}    0
    END
    Execute Command In Terminal    sync

    VAR    ${DEVICE_OS_USERNAME}=    ${os_username_old}    scope=Suite
    VAR    ${DEVICE_OS_PASSWORD}=    ${os_password_old}    scope=Suite

    # Make sure we can enter setup menu after flashing
    Execute Reboot Command
    Set DUT Response Timeout    3m
    Enter Setup Menu Tianocore

Prepare ZPB OS
    [Documentation]    Install ZPB OS via ZPB bootstrap USB
    ...
    ...    === Requirements ===
    ...    - ``${ZARHUS_BOOTSTRAP_FILE}`` defined with path to Zarhus OS
    ...    \ Bootstrap image. Flashed directly on USB.
    ...
    ...    === Arguments ===
    ...    - ``${disk}``: ``string`` - device on which to install Zarhus OS
    ...    === Return Value ===
    ...
    ...    === Effects ===
    ...    - Flashes ``${ZARHUS_BOOTSTRAP_FILE}`` to USB stick on hardware
    ...    - Runs `install.sh` script from bootstrap image which installs ZPB
    ...    \ OS on ``${disk}`` and flashes pre-configured firmware image
    ...    - Runs first boot setup of Zarhus OS
    [Arguments]    ${disk}=nvme0n1
    IF    '${MANUFACTURER}' == 'QEMU'
        VAR    ${disk}=    sda
        ${storage_1}=    Run    mktemp -p ${TEMPDIR} encrypted_storage.XXXXXXXX
        ${storage_2}=    Run    mktemp -p ${TEMPDIR} encrypted_storage.XXXXXXXX
        Run    dd if=/dev/zero of="${storage_1}" bs=1 count=0 seek=300M
        Run    dd if=/dev/zero of="${storage_2}" bs=1 count=0 seek=300M
        Add USB To Qemu
        ...    ${ZARHUS_BOOTSTRAP_FILE}    bootstrap    read_only=${TRUE}    removable=${TRUE}
        Add USB To Qemu
        ...    ${storage_1}    storage_1    read_only=${FALSE}    removable=${TRUE}
        Add USB To Qemu
        ...    ${storage_2}    storage_2    read_only=${FALSE}    removable=${TRUE}
    END
    Set Zarhus Features
    Install ZPB OS    ${disk}
    Boot Dasharo Tools Suite    iPXE
    Enter Shell In DTS
    # Make sure Zarhus is first boot entry
    Execute Command In Terminal Should Succeed
    ...    mount -o remount,rw efivarfs
    ...    Failed to remount efivarfs as read-writable
    Execute Command In Terminal Should Succeed
    ...    efibootmgr --disk "/dev/${disk}" --part 1 --create --label "ZarhusOS" --loader '\\EFI\\BOOT\\bootx64.efi'
    Execute Reboot Command
    Zarhus First Boot Setup

Setup ZPB
    [Documentation]    Setup Provisioning Box. After this step ZPB should be
    ...    ready to be used for provisioning binaries.
    ...    Load ZPB OS dependencies, provision Intel Boot Guard, Provision
    ...    Secure Boot.
    # TODO.
    No Operation

Teardown ZPB Test Suite
    [Documentation]    Remove USB files if running on QEMU
    IF    '${MANUFACTURER}' == 'QEMU'
        Remove USB from Qemu    bootstrap
        Remove USB from Qemu    storage_1
        Remove USB from Qemu    storage_2
    END
