*** Settings ***
Library             Collections
Library             Dialogs
Library             OperatingSystem
Library             Process
Library             String
Library             Telnet    timeout=20 seconds    connection_timeout=120 seconds
Library             SSHLibrary    timeout=90 seconds
Library             RequestsLibrary
Resource            ../keywords.robot
Resource            ../keys.robot
Resource            ../variables.robot
Resource            ../lib/zarhus-provision-lib.robot

Suite Setup         Run Keywords
...                     Prepare Test Suite
...                     AND
...                     Prepare ZPB OS
Suite Teardown      Run Keyword
...                     Log Out And Close Connection
Test Setup          Run Keyword If    ${TESTS_IN_FIRMWARE_SUPPORT}
...                     Restore Initial DUT Connection Method


*** Test Cases ***
ZPB001.206 Make sure that cukinia tests pass
    Boot Zarhus OS
    Execute Command In Terminal With Sudo    cukinia
