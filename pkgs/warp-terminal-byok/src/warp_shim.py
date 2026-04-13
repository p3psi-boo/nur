#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import base64
import hashlib
import html
import json
import os
import re
import subprocess
import shutil
import signal
import sys
import time
import traceback
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Awaitable, Callable, Final, cast
from fnmatch import fnmatch
from urllib.parse import parse_qs, unquote, urljoin, urlparse

from warp_platform import get_runtime_paths, load_secure_storage_json

CURRENT_DIRECTORY = Path(__file__).resolve().parent
WARP_PROTO_DIRECTORY = CURRENT_DIRECTORY / "warp_proto"
DEFAULT_RUNTIME_PATHS = get_runtime_paths()
DEFAULT_WARP_SHIM_CONFIG_PATH = DEFAULT_RUNTIME_PATHS.config_path

if str(WARP_PROTO_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(WARP_PROTO_DIRECTORY))

try:
    from aiohttp import ClientSession, ClientTimeout, WSMsgType, web
    from aiohttp.typedefs import LooseHeaders
    from yarl import URL
except ModuleNotFoundError as error:  # pragma: no cover - import guard
    missing_name = error.name if error.name is not None else "aiohttp"
    print(
        f"Missing dependency: {missing_name}. "
        "请先安装 Warp 一体化运行时依赖后再启动。",
        file=sys.stderr,
    )
    raise SystemExit(1) from error

try:
    import request_pb2
    import response_pb2
    from google.protobuf import struct_pb2
    from google.protobuf import timestamp_pb2
    from google.protobuf.json_format import MessageToDict, ParseDict
except ModuleNotFoundError as error:  # pragma: no cover - import guard
    missing_name = error.name if error.name is not None else "protobuf"
    print(
        f"Missing dependency: {missing_name}. "
        "请先安装 Warp 一体化运行时依赖后再启动。",
        file=sys.stderr,
    )
    raise SystemExit(1) from error

HOP_BY_HOP_HEADERS: Final[set[str]] = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}

INTERESTING_GRAPHQL_OPS: Final[set[str]] = {
    "CreateAgentTask",
    "GetAIConversation",
    "GetAIConversationFormat",
    "ListAIConversations",
}
GRAPHQL_RESPONSE_REWRITE_OPS: Final[set[str]] = {
    "GetFeatureModelChoices",
    "GetConversationUsage",
    "GetRequestLimitInfo",
    "GetUser",
    "GetWorkspacesMetadataForUser",
}
GRAPHQL_DEBUG_CAPTURE_OPS: Final[set[str]] = {
    "GetFeatureModelChoices",
    "GetUser",
}
GRAPHQL_TRUE_OVERRIDE_KEYS: Final[set[str]] = {
    "allowbyoapikeys",
    "byoapikeyenabled",
    "canusebyoapikey",
    "canusewarpcreditswithbyok",
    "hasbyoapikeyaccess",
    "isbyoapikeyenabled",
}
GRAPHQL_FALSE_OVERRIDE_KEYS: Final[set[str]] = {
    "creditlimitreached",
    "hasreachedcreditlimit",
    "isatlimit",
    "isoutofcredits",
    "needsupgrade",
    "outofcredits",
    "paymentrestricted",
    "requiresbuildplan",
    "restrictedduetopaymentissue",
    "showbuycreditsbanner",
    "shouldshowupgradetopromodal",
    "wasquotaexceeded",
}
GRAPHQL_TRUE_OVERRIDE_KEY_PARTIALS: Final[tuple[str, ...]] = (
    "allowbyo",
    "byoapikey",
    "byok",
    "usewarpcreditswithbyok",
)
GRAPHQL_FALSE_OVERRIDE_KEY_PARTIALS: Final[tuple[str, ...]] = (
    "atlimit",
    "creditlimit",
    "needsupgrade",
    "outofcredits",
    "paymentrestricted",
    "quotaexceeded",
    "quota",
    "requiresbuildplan",
    "restrictedduetopayment",
    "shouldshowupgradeto",
    "upgrade",
)
GRAPHQL_FORCE_TRUE_NUMERIC_KEYS: Final[set[str]] = {
    "acceptedautosuggestionslimit",
    "maxcodebaseindices",
    "maxfilesperrepo",
    "requestcreditsgranted",
    "requestcreditsremaining",
    "requestlimit",
    "voicerequestlimit",
    "voicetokenlimit",
}
GRAPHQL_FORCE_ZERO_NUMERIC_KEYS: Final[set[str]] = {
    "acceptedautosuggestionssincelastrefresh",
    "contextwindowusage",
    "creditsspent",
    "currentmonthcreditspurchased",
    "currentmonthspendcents",
    "requestsusedsincelastrefresh",
    "voicerequestsusedsincelastrefresh",
    "voicetokensusedsincelastrefresh",
}
GRAPHQL_FORCE_STRING_VALUES: Final[dict[str, str]] = {
    "apikeyownertype": "USER",
    "principaltype": "USER",
}
GRAPHQL_FORCE_TRUE_SCALAR_KEYS: Final[set[str]] = {
    "editable",
    "enabled",
    "hosted",
    "isactive",
    "isavailable",
    "isbyokavailable",
    "isconfigurable",
    "iseditable",
    "isenabled",
    "isselfhosted",
    "issupported",
    "toggleable",
}
PROVIDER_REQUEST_TIMEOUT_SECONDS: Final[float] = 60.0
MCP_REQUEST_TIMEOUT_SECONDS: Final[float] = 20.0
WEB_SEARCH_TIMEOUT_SECONDS: Final[float] = 20.0
WEB_SEARCH_RESULT_LIMIT: Final[int] = 5
TOKEN_PROXY_FALLBACK_TTL_SECONDS: Final[float] = 45 * 60
SHELL_TOOL_NAME: Final[str] = "shell"
READ_FILES_TOOL_NAME: Final[str] = "read_files"
SEARCH_CODEBASE_TOOL_NAME: Final[str] = "search_codebase"
GREP_TOOL_NAME: Final[str] = "grep"
FILE_GLOB_TOOL_NAME: Final[str] = "file_glob"
FILE_GLOB_V2_TOOL_NAME: Final[str] = "file_glob_v2"
APPLY_FILE_DIFFS_TOOL_NAME: Final[str] = "apply_file_diffs"
SUGGEST_PLAN_TOOL_NAME: Final[str] = "suggest_plan"
SUGGEST_CREATE_PLAN_TOOL_NAME: Final[str] = "suggest_create_plan"
READ_MCP_RESOURCE_TOOL_NAME: Final[str] = "read_mcp_resource"
CALL_MCP_TOOL_NAME: Final[str] = "call_mcp_tool"
WRITE_TO_LONG_RUNNING_SHELL_COMMAND_TOOL_NAME: Final[str] = "write_to_long_running_shell_command"
SUGGEST_NEW_CONVERSATION_TOOL_NAME: Final[str] = "suggest_new_conversation"
ANTHROPIC_WEB_SEARCH_TOOL: Final[dict[str, object]] = {
    "type": "web_search_20250305",
    "name": "web_search",
    "max_uses": 5,
}
SUPPORTED_TOOL_NAMES: Final[tuple[str, ...]] = (
    SHELL_TOOL_NAME,
    READ_FILES_TOOL_NAME,
    SEARCH_CODEBASE_TOOL_NAME,
    GREP_TOOL_NAME,
    FILE_GLOB_TOOL_NAME,
    FILE_GLOB_V2_TOOL_NAME,
    APPLY_FILE_DIFFS_TOOL_NAME,
    SUGGEST_PLAN_TOOL_NAME,
    SUGGEST_CREATE_PLAN_TOOL_NAME,
    READ_MCP_RESOURCE_TOOL_NAME,
    CALL_MCP_TOOL_NAME,
    WRITE_TO_LONG_RUNNING_SHELL_COMMAND_TOOL_NAME,
    SUGGEST_NEW_CONVERSATION_TOOL_NAME,
)
CLIENT_EXECUTED_TOOL_NAMES: Final[set[str]] = {
    SHELL_TOOL_NAME,
    READ_FILES_TOOL_NAME,
    SEARCH_CODEBASE_TOOL_NAME,
    APPLY_FILE_DIFFS_TOOL_NAME,
    SUGGEST_PLAN_TOOL_NAME,
    SUGGEST_CREATE_PLAN_TOOL_NAME,
    GREP_TOOL_NAME,
    FILE_GLOB_TOOL_NAME,
    FILE_GLOB_V2_TOOL_NAME,
    WRITE_TO_LONG_RUNNING_SHELL_COMMAND_TOOL_NAME,
    SUGGEST_NEW_CONVERSATION_TOOL_NAME,
}
READ_ONLY_COMMAND_PREFIXES: Final[tuple[str, ...]] = (
    "cat ",
    "echo ",
    "find ",
    "git diff",
    "git log",
    "git show",
    "head ",
    "ls",
    "pwd",
    "readlink ",
    "rg",
    "sed ",
    "tail ",
    "wc ",
    "which ",
)
PAGER_COMMAND_PREFIXES: Final[tuple[str, ...]] = ("less ", "man ", "more ")
RISKY_COMMAND_TOKENS: Final[tuple[str, ...]] = (
    " rm ",
    " mv ",
    " chmod ",
    " chown ",
    " sudo ",
    " git reset",
    " git checkout ",
)


@dataclass(frozen=True)
class ProviderConfig:
    base_url: str
    api_key: str | None = None


@dataclass(frozen=True)
class ShellToolCall:
    tool_call_id: str
    tool_name: str
    is_read_only: bool
    uses_pager: bool
    is_risky: bool
    command: str | None = None
    arguments: dict[str, object] = field(default_factory=dict)


@dataclass(frozen=True)
class ShellToolResult:
    tool_call_id: str
    tool_name: str
    command: str | None
    output: str
    exit_code: int | None


@dataclass(frozen=True)
class LocalAIRequest:
    model_id: str
    user_text: str
    cwd: str | None
    shell_name: str | None
    os_platform: str | None
    username: str | None
    conversation_id: str | None
    task_id: str | None
    has_user_input: bool
    is_resume_conversation: bool
    pending_tool_results: tuple[ShellToolResult, ...]
    raw_request: request_pb2.Request


@dataclass(frozen=True)
class LocalAIResult:
    text: str
    reasoning: str | None = None
    tool_calls: tuple[ShellToolCall, ...] = ()


@dataclass
class ConversationState:
    provider_name: str
    target_model: str
    system_prompt: str
    messages: list[dict[str, object]]
    mcp_tool_aliases: dict[str, tuple[str, str]]
    mcp_resource_aliases: dict[str, tuple[str, str]]
    awaiting_client_tool_results: bool = False


@dataclass(frozen=True)
class ShimConfig:
    listen_host: str
    listen_port: int
    upstream_http_base: str
    upstream_ws_base: str
    upstream_ai_base: str
    log_path: Path
    capture_dir: Path
    openai: ProviderConfig | None
    anthropic: ProviderConfig | None
    google: ProviderConfig | None
    model_overrides: dict[str, str]
    mcp_servers: dict[str, object]


def merge_runtime_provider_config(
    current_config: ShimConfig,
    refreshed_config: ShimConfig,
) -> ShimConfig:
    return ShimConfig(
        listen_host=current_config.listen_host,
        listen_port=current_config.listen_port,
        upstream_http_base=current_config.upstream_http_base,
        upstream_ws_base=current_config.upstream_ws_base,
        upstream_ai_base=current_config.upstream_ai_base,
        log_path=current_config.log_path,
        capture_dir=current_config.capture_dir,
        openai=refreshed_config.openai,
        anthropic=refreshed_config.anthropic,
        google=refreshed_config.google,
        model_overrides=current_config.model_overrides,
        mcp_servers=current_config.mcp_servers,
    )


@dataclass(frozen=True)
class MCPRemoteTool:
    server_name: str
    tool_name: str
    description: str
    input_schema: dict[str, object]


@dataclass(frozen=True)
class MCPRemoteResource:
    server_name: str
    uri: str
    name: str
    description: str
    mime_type: str


@dataclass
class MCPRemoteServer:
    name: str
    server_url: str
    headers: dict[str, str]
    session_id: str | None = None
    protocol_version: str = "2025-03-26"
    tools: dict[str, MCPRemoteTool] = field(default_factory=dict)
    resources: dict[str, MCPRemoteResource] = field(default_factory=dict)
    refresh_lock: asyncio.Lock = field(default_factory=asyncio.Lock)
    initialization_error: str | None = None


@dataclass(frozen=True)
class TokenProxyCacheEntry:
    status: int
    headers: dict[str, str]
    body: bytes
    expires_at_monotonic: float


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Warp local shim proxy.")
    parser.add_argument("--config", help="JSON config file path (default: XDG config path)")
    return parser


def load_json_config(config_path: str | None) -> dict[str, object]:
    if config_path is None:
        if DEFAULT_WARP_SHIM_CONFIG_PATH.exists():
            config_path = str(DEFAULT_WARP_SHIM_CONFIG_PATH)
        else:
            return {}

    path = Path(config_path).expanduser().resolve()
    with path.open("r", encoding="utf-8") as file_handle:
        loaded = json.load(file_handle)

    if not isinstance(loaded, dict):
        raise ValueError("Config JSON must be an object.")

    return loaded



def resolve_text_value(
    json_config: dict[str, object],
    json_key: str,
    default_value: str | None = None,
) -> str | None:
    """Resolve config value from JSON only."""
    json_value = json_config.get(json_key)
    if isinstance(json_value, str):
        return json_value
    return default_value


def resolve_int_value(
    json_config: dict[str, object],
    json_key: str,
    default_value: int,
) -> int:
    """Resolve config value from JSON only."""
    json_value = json_config.get(json_key)
    if isinstance(json_value, int):
        return json_value
    return default_value


def build_provider_config(base_url: str | None) -> ProviderConfig | None:
    if base_url is None or base_url == "":
        return None
    return ProviderConfig(base_url=base_url.rstrip("/"))


def build_provider_config_with_key(base_url: str | None, api_key: str | None) -> ProviderConfig | None:
    if base_url is None or base_url == "":
        return None
    normalized_api_key = None if api_key is None or api_key == "" else api_key
    return ProviderConfig(base_url=base_url.rstrip("/"), api_key=normalized_api_key)


def load_config(arguments: argparse.Namespace) -> ShimConfig:
    json_config = load_json_config(arguments.config)

    listen_host = resolve_text_value(json_config, "listen_host", "127.0.0.1")
    listen_port = resolve_int_value(json_config, "listen_port", 8911)
    upstream_http_base = resolve_text_value(json_config, "upstream_http_base", "https://app.warp.dev")
    upstream_ws_base = resolve_text_value(json_config, "upstream_ws_base", "wss://rtc.app.warp.dev/graphql/v2")
    upstream_ai_base = resolve_text_value(json_config, "upstream_ai_base", "https://app.warp.dev")
    log_path = resolve_text_value(json_config, "log_path", "./shim-traffic.log")
    capture_dir = resolve_text_value(json_config, "capture_dir", "./shim-captures")
    openai_base_url = resolve_text_value(json_config, "openai_base_url")
    anthropic_base_url = resolve_text_value(json_config, "anthropic_base_url")
    google_base_url = resolve_text_value(json_config, "google_base_url")
    openai_api_key = resolve_text_value(json_config, "openai_api_key")
    anthropic_api_key = resolve_text_value(json_config, "anthropic_api_key")
    google_api_key = resolve_text_value(json_config, "google_api_key")
    model_overrides_raw = json_config.get("model_overrides")
    model_overrides: dict[str, str] = {}
    if isinstance(model_overrides_raw, dict):
        for key, value in model_overrides_raw.items():
            if isinstance(key, str) and isinstance(value, str):
                model_overrides[key] = value

    mcp_servers_raw = json_config.get("mcp_servers")
    mcp_servers: dict[str, object] = {}
    for key, value in warp_mcp_servers.items():
        if isinstance(key, str):
            mcp_servers[key] = value
    if isinstance(mcp_servers_raw, dict):
        for key, value in mcp_servers_raw.items():
            if isinstance(key, str):
                mcp_servers[key] = value

    if (
        listen_host is None
        or upstream_http_base is None
        or upstream_ws_base is None
        or upstream_ai_base is None
        or log_path is None
        or capture_dir is None
    ):
        raise ValueError("Failed to resolve required configuration.")

    return ShimConfig(
        listen_host=listen_host,
        listen_port=listen_port,
        upstream_http_base=upstream_http_base.rstrip("/"),
        upstream_ws_base=upstream_ws_base.rstrip("/"),
        upstream_ai_base=upstream_ai_base.rstrip("/"),
        log_path=Path(log_path).expanduser().resolve(),
        capture_dir=Path(capture_dir).expanduser().resolve(),
        openai=build_provider_config_with_key(openai_base_url, openai_api_key),
        anthropic=build_provider_config_with_key(anthropic_base_url, anthropic_api_key),
        google=build_provider_config_with_key(google_base_url, google_api_key),
        model_overrides=model_overrides,
        mcp_servers=mcp_servers,
    )


def parse_mcp_http_payload(response_text: str, content_type: str) -> dict[str, object]:
    if "text/event-stream" not in content_type:
        payload = json.loads(response_text)
        if not isinstance(payload, dict):
            raise RuntimeError("Invalid MCP JSON response payload.")
        return payload

    for chunk in response_text.split("\n\n"):
        data_lines = [line[6:] for line in chunk.splitlines() if line.startswith("data: ")]
        if not data_lines:
            continue
        payload = json.loads("\n".join(data_lines))
        if isinstance(payload, dict):
            return payload
    raise RuntimeError("Failed to parse MCP SSE response payload.")


def format_exception_message(error: BaseException) -> str:
    message = str(error).strip()
    if message != "":
        return message
    if isinstance(error, asyncio.TimeoutError):
        return "Request timed out"
    return type(error).__name__


async def call_mcp_jsonrpc_once(
    session: ClientSession,
    config: ShimConfig,
    server: MCPRemoteServer,
    method: str,
    params: dict[str, object] | None,
    request_id: int,
) -> dict[str, object]:
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "MCP-Protocol-Version": server.protocol_version,
        **server.headers,
    }
    if server.session_id is not None:
        headers["MCP-Session-Id"] = server.session_id

    payload: dict[str, object] = {
        "jsonrpc": "2.0",
        "id": request_id,
        "method": method,
    }
    if params is not None:
        payload["params"] = params

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "mcp_request",
            "server_name": server.name,
            "method": method,
            "payload": payload,
        },
    )

    try:
        async with session.post(
            server.server_url,
            json=payload,
            headers=headers,
            timeout=ClientTimeout(total=MCP_REQUEST_TIMEOUT_SECONDS),
        ) as response:
            response_text = await response.text()
            if response.status >= 400:
                await append_log(
                    config,
                    {
                        "timestamp": datetime.now(UTC).isoformat(),
                        "kind": "mcp_error",
                        "server_name": server.name,
                        "method": method,
                        "status": response.status,
                        "body": truncate_text(response_text, limit=8000),
                    },
                )
                raise RuntimeError(
                    f"MCP server {server.name} request failed: status={response.status}, body={truncate_text(response_text, limit=1000)}"
                )
            if "MCP-Session-Id" in response.headers:
                server.session_id = response.headers["MCP-Session-Id"]
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "mcp_response",
                    "server_name": server.name,
                    "method": method,
                    "status": response.status,
                    "body": truncate_text(response_text, limit=4000),
                },
            )
            return parse_mcp_http_payload(response_text, response.headers.get("Content-Type", ""))
    except Exception as error:
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "mcp_error",
                "server_name": server.name,
                "method": method,
                "error": format_exception_message(error),
                "error_type": type(error).__name__,
            },
        )
        raise


async def refresh_mcp_server(
    session: ClientSession,
    config: ShimConfig,
    server: MCPRemoteServer,
) -> None:
    async with server.refresh_lock:
        server.session_id = None
        server.tools.clear()
        server.resources.clear()
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "mcp_refresh",
                "server_name": server.name,
            },
        )
        await initialize_mcp_server(session, config, server)


async def call_mcp_jsonrpc(
    session: ClientSession,
    config: ShimConfig,
    server: MCPRemoteServer,
    method: str,
    params: dict[str, object] | None,
    request_id: int,
    *,
    allow_retry: bool = True,
) -> dict[str, object]:
    try:
        return await call_mcp_jsonrpc_once(session, config, server, method, params, request_id)
    except Exception:
        if not allow_retry or method == "initialize":
            raise
        await refresh_mcp_server(session, config, server)
        return await call_mcp_jsonrpc_once(session, config, server, method, params, request_id)


def extract_mcp_tools_from_result(server: MCPRemoteServer, result: dict[str, object]) -> None:
    tools = result.get("tools")
    if not isinstance(tools, list):
        return
    for item in tools:
        if not isinstance(item, dict):
            continue
        name = item.get("name")
        if not isinstance(name, str) or name == "":
            continue
        description = item.get("description")
        input_schema = item.get("inputSchema")
        if not isinstance(description, str):
            description = ""
        if not isinstance(input_schema, dict):
            input_schema = {"type": "object", "properties": {}, "additionalProperties": True}
        server.tools[name] = MCPRemoteTool(
            server_name=server.name,
            tool_name=name,
            description=description,
            input_schema=input_schema,
        )


def extract_mcp_resources_from_result(server: MCPRemoteServer, result: dict[str, object]) -> None:
    resources = result.get("resources")
    if not isinstance(resources, list):
        return
    for item in resources:
        if not isinstance(item, dict):
            continue
        uri = item.get("uri")
        if not isinstance(uri, str) or uri == "":
            continue
        name = item.get("name")
        description = item.get("description")
        mime_type = item.get("mimeType")
        server.resources[uri] = MCPRemoteResource(
            server_name=server.name,
            uri=uri,
            name=name if isinstance(name, str) else uri,
            description=description if isinstance(description, str) else "",
            mime_type=mime_type if isinstance(mime_type, str) else "",
        )


async def initialize_mcp_server(session: ClientSession, config: ShimConfig, server: MCPRemoteServer) -> None:
    server.initialization_error = None
    initialize_response = await call_mcp_jsonrpc(
        session,
        config,
        server,
        "initialize",
        {
            "protocolVersion": server.protocol_version,
            "capabilities": {},
            "clientInfo": {"name": "warp-shim", "version": "0.1.0"},
        },
        request_id=1,
    )
    result = initialize_response.get("result")
    if isinstance(result, dict):
        protocol_version = result.get("protocolVersion")
        if isinstance(protocol_version, str) and protocol_version != "":
            server.protocol_version = protocol_version
        capabilities = result.get("capabilities")
        if isinstance(capabilities, dict):
            tools_capability = capabilities.get("tools")
            if isinstance(tools_capability, dict):
                extract_mcp_tools_from_result(server, {"tools": [{"name": name, **value} for name, value in tools_capability.items() if isinstance(value, dict)]})

    try:
        await call_mcp_jsonrpc(session, config, server, "notifications/initialized", None, request_id=2)
    except Exception:
        pass

    try:
        tools_response = await call_mcp_jsonrpc(session, config, server, "tools/list", None, request_id=3)
        if isinstance(tools_response.get("result"), dict):
            extract_mcp_tools_from_result(server, cast(dict[str, object], tools_response["result"]))
    except Exception:
        pass

    try:
        resources_response = await call_mcp_jsonrpc(session, config, server, "resources/list", None, request_id=4)
        if isinstance(resources_response.get("result"), dict):
            extract_mcp_resources_from_result(server, cast(dict[str, object], resources_response["result"]))
    except Exception:
        pass


async def build_mcp_registry(
    session: ClientSession,
    config: ShimConfig,
) -> dict[str, MCPRemoteServer]:
    registry: dict[str, MCPRemoteServer] = {}
    for server_name, raw_config in config.mcp_servers.items():
        if not isinstance(raw_config, dict):
            continue
        server_url = raw_config.get("serverUrl")
        headers = raw_config.get("headers")
        if not isinstance(server_url, str) or server_url == "":
            continue
        normalized_headers = {
            key: value
            for key, value in headers.items()
            if isinstance(key, str) and isinstance(value, str)
        } if isinstance(headers, dict) else {}
        server = MCPRemoteServer(
            name=server_name,
            server_url=server_url,
            headers=normalized_headers,
        )
        try:
            await initialize_mcp_server(session, config, server)
        except Exception as error:
            server.initialization_error = format_exception_message(error)
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "mcp_initialize_error",
                    "server_name": server_name,
                    "server_url": server_url,
                    "error": server.initialization_error,
                    "error_type": type(error).__name__,
                },
            )
        registry[server_name] = server
    return registry


def build_request_headers(headers: LooseHeaders) -> dict[str, str]:
    filtered: dict[str, str] = {}
    for key, value in headers.items():
        lowered_key = key.lower()
        if lowered_key in HOP_BY_HOP_HEADERS:
            continue
        if lowered_key == "host":
            continue
        filtered[key] = value
    return filtered


def build_websocket_upstream_headers(headers: LooseHeaders) -> dict[str, str]:
    filtered: dict[str, str] = {}
    for key, value in headers.items():
        lowered_key = key.lower()
        if lowered_key in HOP_BY_HOP_HEADERS:
            continue
        if lowered_key == "host":
            continue
        if lowered_key.startswith("sec-websocket-"):
            continue
        filtered[key] = value
    return filtered


def build_response_headers(headers: LooseHeaders) -> dict[str, str]:
    filtered: dict[str, str] = {}
    for key, value in headers.items():
        if key.lower() in HOP_BY_HOP_HEADERS:
            continue
        filtered[key] = value
    return filtered


def request_url(base_url: str, path_qs: str) -> str:
    return urljoin(f"{base_url}/", path_qs.lstrip("/"))


def is_ai_stream_path(path: str) -> bool:
    return path.startswith("/ai/")


def decode_utf8_bytes(value: bytes | None) -> str | None:
    if value is None:
        return None
    try:
        return value.decode("utf-8")
    except UnicodeDecodeError:
        return None


def infer_shell_command_flags(command: str) -> tuple[bool, bool, bool]:
    normalized = f" {command.strip().lower()} "
    is_read_only = any(normalized.strip().startswith(prefix) for prefix in READ_ONLY_COMMAND_PREFIXES)
    uses_pager = any(normalized.strip().startswith(prefix) for prefix in PAGER_COMMAND_PREFIXES)
    is_risky = any(token in normalized for token in RISKY_COMMAND_TOKENS)
    return is_read_only, uses_pager, is_risky


def parse_shell_tool_result(
    tool_call_result: request_pb2.Request.Input.ToolCallResult,
) -> ShellToolResult | None:
    if tool_call_result.HasField("run_shell_command"):
        shell_result = tool_call_result.run_shell_command
        result_kind = shell_result.WhichOneof("result")
        output = ""
        exit_code: int | None = None

        if result_kind == "command_finished":
            output = shell_result.command_finished.output
            exit_code = shell_result.command_finished.exit_code
        elif result_kind == "long_running_command_snapshot":
            output = shell_result.long_running_command_snapshot.output

        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=SHELL_TOOL_NAME,
            command=shell_result.command,
            output=output,
            exit_code=exit_code,
        )

    if tool_call_result.HasField("read_files"):
        read_files_result = tool_call_result.read_files
        if read_files_result.HasField("success"):
            output = json.dumps(
                [
                    {
                        "file_path": file_content.file_path,
                        "content": file_content.content,
                        "line_range": {
                            "start": file_content.line_range.start,
                            "end": file_content.line_range.end,
                        }
                        if file_content.HasField("line_range")
                        else None,
                    }
                    for file_content in read_files_result.success.files
                ],
                ensure_ascii=False,
            )
        else:
            output = read_files_result.error.message
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=READ_FILES_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    if tool_call_result.HasField("search_codebase"):
        search_result = tool_call_result.search_codebase
        if search_result.HasField("success"):
            output = json.dumps(
                [
                    {
                        "file_path": file_content.file_path,
                        "content": file_content.content,
                        "line_range": {
                            "start": file_content.line_range.start,
                            "end": file_content.line_range.end,
                        }
                        if file_content.HasField("line_range")
                        else None,
                    }
                    for file_content in search_result.success.files
                ],
                ensure_ascii=False,
            )
        else:
            output = search_result.error.message
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=SEARCH_CODEBASE_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    if tool_call_result.HasField("grep"):
        grep_result = tool_call_result.grep
        if grep_result.HasField("success"):
            output = json.dumps(
                [
                    {
                        "file_path": file_match.file_path,
                        "matched_lines": [line_match.line_number for line_match in file_match.matched_lines],
                    }
                    for file_match in grep_result.success.matched_files
                ],
                ensure_ascii=False,
            )
        else:
            output = grep_result.error.message
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=GREP_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    if tool_call_result.HasField("file_glob"):
        file_glob_result = tool_call_result.file_glob
        if file_glob_result.HasField("success"):
            output = file_glob_result.success.matched_files
        else:
            output = file_glob_result.error.message
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=FILE_GLOB_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    if tool_call_result.HasField("file_glob_v2"):
        glob_result = tool_call_result.file_glob_v2
        if glob_result.HasField("success"):
            output = json.dumps(
                [match.file_path for match in glob_result.success.matched_files],
                ensure_ascii=False,
            )
        else:
            output = glob_result.error.message
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=FILE_GLOB_V2_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    if tool_call_result.HasField("suggest_plan"):
        suggest_plan_result = tool_call_result.suggest_plan
        if suggest_plan_result.HasField("accepted"):
            output = json.dumps({"accepted": True}, ensure_ascii=False)
        else:
            output = json.dumps(
                {"user_edited_plan": suggest_plan_result.user_edited_plan.plan_text},
                ensure_ascii=False,
            )
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=SUGGEST_PLAN_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    if tool_call_result.HasField("suggest_create_plan"):
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=SUGGEST_CREATE_PLAN_TOOL_NAME,
            command=None,
            output=json.dumps({"accepted": tool_call_result.suggest_create_plan.accepted}, ensure_ascii=False),
            exit_code=None,
        )

    if tool_call_result.HasField("apply_file_diffs"):
        apply_result = tool_call_result.apply_file_diffs
        if apply_result.HasField("success"):
            output = json.dumps(
                [
                    {
                        "file_path": updated.file.file_path,
                        "content": updated.file.content,
                        "was_edited_by_user": updated.was_edited_by_user,
                    }
                    for updated in apply_result.success.updated_files_v2
                ],
                ensure_ascii=False,
            )
        else:
            output = apply_result.error.message
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=APPLY_FILE_DIFFS_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    if tool_call_result.HasField("read_mcp_resource"):
        read_result = tool_call_result.read_mcp_resource
        if read_result.HasField("success"):
            output = json.dumps(
                [
                    {
                        "uri": content.uri,
                        "text": {
                            "content": content.text.content,
                            "mime_type": content.text.mime_type,
                        }
                        if content.HasField("text")
                        else None,
                        "binary": {
                            "data": base64.b64encode(content.binary.data).decode("ascii"),
                            "mime_type": content.binary.mime_type,
                        }
                        if content.HasField("binary")
                        else None,
                    }
                    for content in read_result.success.contents
                ],
                ensure_ascii=False,
            )
        else:
            output = read_result.error.message
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=READ_MCP_RESOURCE_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    if tool_call_result.HasField("call_mcp_tool"):
        call_result = tool_call_result.call_mcp_tool
        if call_result.HasField("success"):
            output = json.dumps(
                [
                    {
                        "text": result.text.text if result.HasField("text") else None,
                        "image": {
                            "data": base64.b64encode(result.image.data).decode("ascii"),
                            "mime_type": result.image.mime_type,
                        }
                        if result.HasField("image")
                        else None,
                        "resource": {
                            "uri": result.resource.uri,
                            "text": {
                                "content": result.resource.text.content,
                                "mime_type": result.resource.text.mime_type,
                            }
                            if result.resource.HasField("text")
                            else None,
                            "binary": {
                                "data": base64.b64encode(result.resource.binary.data).decode("ascii"),
                                "mime_type": result.resource.binary.mime_type,
                            }
                            if result.resource.HasField("binary")
                            else None,
                        }
                        if result.HasField("resource")
                        else None,
                    }
                    for result in call_result.success.results
                ],
                ensure_ascii=False,
            )
        else:
            output = call_result.error.message
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=CALL_MCP_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    if tool_call_result.HasField("write_to_long_running_shell_command"):
        write_result = tool_call_result.write_to_long_running_shell_command
        result_kind = write_result.WhichOneof("result")
        output = ""
        exit_code: int | None = None
        if result_kind == "command_finished":
            output = write_result.command_finished.output
            exit_code = write_result.command_finished.exit_code
        elif result_kind == "long_running_command_snapshot":
            output = write_result.long_running_command_snapshot.output
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=WRITE_TO_LONG_RUNNING_SHELL_COMMAND_TOOL_NAME,
            command=None,
            output=output,
            exit_code=exit_code,
        )

    if tool_call_result.HasField("suggest_new_conversation"):
        suggest_result = tool_call_result.suggest_new_conversation
        if suggest_result.HasField("accepted"):
            output = json.dumps({"accepted": {"message_id": suggest_result.accepted.message_id}}, ensure_ascii=False)
        else:
            output = json.dumps({"rejected": True}, ensure_ascii=False)
        return ShellToolResult(
            tool_call_id=tool_call_result.tool_call_id,
            tool_name=SUGGEST_NEW_CONVERSATION_TOOL_NAME,
            command=None,
            output=output,
            exit_code=None,
        )

    return None


def parse_local_ai_request(body: bytes) -> LocalAIRequest:
    parsed_request = request_pb2.Request()
    parsed_request.ParseFromString(body)

    model_id = parsed_request.settings.model_config.base or "unknown-model"
    user_text = ""
    has_user_input = False
    pending_tool_results: list[ShellToolResult] = []

    if parsed_request.input.HasField("user_inputs"):
        has_user_input = len(parsed_request.input.user_inputs.inputs) > 0
        for user_input in parsed_request.input.user_inputs.inputs:
            if user_input.HasField("tool_call_result"):
                tool_result = parse_shell_tool_result(user_input.tool_call_result)
                if tool_result is not None:
                    pending_tool_results.append(tool_result)
            if user_text == "" and user_input.HasField("user_query") and user_input.user_query.query.strip() != "":
                user_text = user_input.user_query.query
    elif parsed_request.input.HasField("user_query"):
        has_user_input = True
        user_text = parsed_request.input.user_query.query
    elif parsed_request.input.HasField("query_with_canned_response"):
        has_user_input = True
        user_text = parsed_request.input.query_with_canned_response.query
    elif parsed_request.input.HasField("tool_call_result"):
        has_user_input = True
        tool_result = parse_shell_tool_result(parsed_request.input.tool_call_result)
        if tool_result is not None:
            pending_tool_results.append(tool_result)

    cwd = parsed_request.input.context.directory.pwd or None
    shell_name = parsed_request.input.context.shell.name or None
    os_platform = parsed_request.input.context.operating_system.platform or None
    username = None
    conversation_id = parsed_request.metadata.conversation_id or None
    task_id = parsed_request.task_context.active_task_id or None
    if task_id is None:
        for task in parsed_request.task_context.tasks:
            if task.id != "":
                task_id = task.id
                break
    try:
        for key, value in parsed_request.metadata.logging.items():
            if key == "user" and value.HasField("string_value"):
                username = value.string_value
                break
    except Exception:
        username = None

    return LocalAIRequest(
        model_id=model_id,
        user_text=user_text,
        cwd=cwd,
        shell_name=shell_name,
        os_platform=os_platform,
        username=username,
        conversation_id=conversation_id,
        task_id=task_id,
        has_user_input=has_user_input,
        is_resume_conversation=parsed_request.input.HasField("resume_conversation"),
        pending_tool_results=tuple(pending_tool_results),
        raw_request=parsed_request,
    )


def normalize_openai_base_url(base_url: str) -> str:
    normalized = base_url.rstrip("/")
    if normalized.endswith("/chat/completions"):
        return normalized
    if normalized.endswith("/v1"):
        return f"{normalized}/chat/completions"
    return f"{normalized}/v1/chat/completions"


def normalize_anthropic_base_url(base_url: str) -> str:
    normalized = base_url.rstrip("/")
    if normalized.endswith("/v1/messages"):
        return normalized
    return f"{normalized}/v1/messages"


def normalize_google_base_url(base_url: str, model: str, api_key: str) -> str:
    normalized = base_url.rstrip("/")
    if ":generateContent" in normalized:
        separator = "&" if "?" in normalized else "?"
        if "key=" in normalized:
            return normalized
        return f"{normalized}{separator}key={api_key}"
    if normalized.endswith("/v1beta") or normalized.endswith("/v1"):
        return f"{normalized}/models/{model}:generateContent?key={api_key}"
    return f"{normalized}/v1beta/models/{model}:generateContent?key={api_key}"


def build_provider_selection_metadata(
    config: ShimConfig,
    local_request: LocalAIRequest,
) -> dict[str, str]:
    provider_name = resolve_provider_name(local_request.model_id)
    target_model = resolve_provider_model(local_request.model_id, config)
    metadata = {
        "provider_name": provider_name,
        "target_model": target_model,
    }

    if provider_name == "anthropic" and config.anthropic is not None:
        metadata["endpoint"] = normalize_anthropic_base_url(config.anthropic.base_url)
    elif provider_name == "google" and config.google is not None:
        metadata["endpoint"] = normalize_google_base_url(
            config.google.base_url,
            target_model,
            config.google.api_key or "",
        )
    elif provider_name == "openai" and config.openai is not None:
        metadata["endpoint"] = normalize_openai_base_url(config.openai.base_url)
    else:
        metadata["endpoint"] = "local-echo"

    return metadata


def resolve_provider_name(model_id: str) -> str:
    normalized = model_id.lower()
    if normalized.startswith("claude"):
        return "anthropic"
    if normalized.startswith("gemini"):
        return "google"
    return "openai"


def resolve_provider_model(model_id: str, config: ShimConfig) -> str:
    override = config.model_overrides.get(model_id)
    if override is not None and override != "":
        return override

    normalized = model_id.lower()

    if normalized.startswith("gpt-5-4"):
        return "gpt-5.4"
    if normalized.startswith("gpt-5-3"):
        return "gpt-5.3"
    if normalized.startswith("gpt-5-2"):
        return "gpt-5.2"

    if normalized.startswith("claude-"):
        parts = normalized.split("-")
        if len(parts) >= 4 and parts[0] == "claude":
            family = parts[3]
            version = "-".join(parts[1:3])
            return f"claude-{family}-{version}"

    return model_id


def build_system_prompt(
    local_request: LocalAIRequest,
    mcp_registry: dict[str, MCPRemoteServer] | None = None,
) -> str:
    chunks: list[str] = [
        "Use the provided tools when you need command output or filesystem inspection.",
        "Do not fabricate tool calls or tool results in plain text.",
        "The shell tool runs on the user's machine and can access the network if shell commands support it.",
        "Prefer the minimum sufficient number of tool calls and model rounds.",
        "Batch independent tool calls in the same round when possible.",
        "If the user asks to test MCP functionality, do one small representative check per MCP and then answer without repetitive re-validation.",
    ]
    if local_request.cwd:
        chunks.append(f"cwd={local_request.cwd}")
    if local_request.shell_name:
        chunks.append(f"shell={local_request.shell_name}")
    if local_request.username:
        chunks.append(f"user={local_request.username}")
    if local_request.raw_request.mcp_context.resources:
        chunks.append(
            "mcp_resources="
            + json.dumps(
                [
                    {
                        "uri": resource.uri,
                        "name": resource.name,
                        "description": resource.description,
                        "mime_type": resource.mime_type,
                    }
                    for resource in local_request.raw_request.mcp_context.resources
                ],
                ensure_ascii=False,
            )
        )
    if local_request.raw_request.mcp_context.tools:
        chunks.append(
            "mcp_tools="
            + json.dumps(
                [
                    {
                        "name": tool.name,
                        "description": tool.description,
                        "input_schema": MessageToDict(tool.input_schema),
                    }
                    for tool in local_request.raw_request.mcp_context.tools
                ],
                ensure_ascii=False,
            )
        )
    if mcp_registry:
        chunks.append(
            "configured_mcp_servers="
            + json.dumps(
                {
                    server_name: {
                        "tools": sorted(server.tools.keys()),
                        "resources": sorted(server.resources.keys()),
                    }
                    for server_name, server in mcp_registry.items()
                },
                ensure_ascii=False,
            )
        )
    if local_request.raw_request.settings.web_context_retrieval_enabled:
        chunks.append(
            "web_context_retrieval_enabled=true; if provider-native web search is unavailable, use shell commands to test network access or fetch web content."
        )
    return "\n".join(chunks)


def build_supported_tool_schemas(
    local_request: LocalAIRequest,
    mcp_registry: dict[str, MCPRemoteServer] | None = None,
) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    openai_tools: list[dict[str, object]] = []
    anthropic_tools: list[dict[str, object]] = []

    requested_tool_ids = set(local_request.raw_request.settings.supported_tools)
    mcp_tool_aliases, mcp_resource_aliases = build_mcp_alias_maps(local_request, mcp_registry)

    def add_tool(name: str, description: str, input_schema: dict[str, object]) -> None:
        openai_tools.append(
            {
                "type": "function",
                "function": {
                    "name": name,
                    "description": description,
                    "parameters": input_schema,
                },
            }
        )
        anthropic_tools.append(
            {
                "name": name,
                "description": description,
                "input_schema": input_schema,
            }
        )

    # Fallback to all local tools when Warp did not specify a subset.
    if not requested_tool_ids or 0 in requested_tool_ids:
        add_tool(
            SHELL_TOOL_NAME,
            "Run a shell command in the user's terminal environment.",
            {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "The shell command to execute."}
                },
                "required": ["command"],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 2 in requested_tool_ids:
        add_tool(
            READ_FILES_TOOL_NAME,
            "Read one or more files, optionally restricted to line ranges.",
            {
                "type": "object",
                "properties": {
                    "files": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "line_ranges": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "start": {"type": "integer"},
                                            "end": {"type": "integer"},
                                        },
                                        "required": ["start", "end"],
                                        "additionalProperties": False,
                                    },
                                },
                            },
                            "required": ["name"],
                            "additionalProperties": False,
                        },
                    }
                },
                "required": ["files"],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 1 in requested_tool_ids:
        add_tool(
            SEARCH_CODEBASE_TOOL_NAME,
            "Search code or text across a codebase and return matching file snippets.",
            {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "path_filters": {"type": "array", "items": {"type": "string"}},
                    "codebase_path": {"type": "string"},
                },
                "required": ["query"],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 6 in requested_tool_ids:
        add_tool(
            GREP_TOOL_NAME,
            "Search for literal or regex patterns and return matching files and line numbers.",
            {
                "type": "object",
                "properties": {
                    "queries": {"type": "array", "items": {"type": "string"}},
                    "path": {"type": "string"},
                },
                "required": ["queries"],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 7 in requested_tool_ids:
        add_tool(
            FILE_GLOB_TOOL_NAME,
            "Find files by glob patterns inside a directory and return a compact list.",
            {
                "type": "object",
                "properties": {
                    "patterns": {"type": "array", "items": {"type": "string"}},
                    "path": {"type": "string"},
                },
                "required": ["patterns"],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 12 in requested_tool_ids:
        add_tool(
            FILE_GLOB_V2_TOOL_NAME,
            "Find files by glob patterns inside a directory.",
            {
                "type": "object",
                "properties": {
                    "patterns": {"type": "array", "items": {"type": "string"}},
                    "search_dir": {"type": "string"},
                    "max_matches": {"type": "integer"},
                    "max_depth": {"type": "integer"},
                    "min_depth": {"type": "integer"},
                },
                "required": ["patterns"],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 3 in requested_tool_ids:
        add_tool(
            APPLY_FILE_DIFFS_TOOL_NAME,
            "Apply search/replace edits to files and optionally create new files.",
            {
                "type": "object",
                "properties": {
                    "summary": {"type": "string"},
                    "diffs": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "file_path": {"type": "string"},
                                "search": {"type": "string"},
                                "replace": {"type": "string"},
                            },
                            "required": ["file_path", "search", "replace"],
                            "additionalProperties": False,
                        },
                    },
                    "new_files": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "file_path": {"type": "string"},
                                "content": {"type": "string"},
                            },
                            "required": ["file_path", "content"],
                            "additionalProperties": False,
                        },
                    },
                },
                "required": [],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 4 in requested_tool_ids:
        add_tool(
            SUGGEST_PLAN_TOOL_NAME,
            "Suggest a task plan for the current request.",
            {
                "type": "object",
                "properties": {"summary": {"type": "string"}},
                "required": ["summary"],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 5 in requested_tool_ids:
        add_tool(
            SUGGEST_CREATE_PLAN_TOOL_NAME,
            "Ask the client to create a task plan for the current request.",
            {
                "type": "object",
                "properties": {},
                "required": [],
                "additionalProperties": False,
            },
        )
    if (not requested_tool_ids or 8 in requested_tool_ids) and not mcp_resource_aliases:
        add_tool(
            READ_MCP_RESOURCE_TOOL_NAME,
            "Read an MCP resource by uri from the provided MCP context.",
            {
                "type": "object",
                "properties": {"uri": {"type": "string"}},
                "required": ["uri"],
                "additionalProperties": False,
            },
        )
    if (not requested_tool_ids or 9 in requested_tool_ids) and not mcp_tool_aliases:
        add_tool(
            CALL_MCP_TOOL_NAME,
            "Call a tool from the provided MCP context.",
            {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "args": {"type": "object", "additionalProperties": True},
                },
                "required": ["name", "args"],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 10 in requested_tool_ids:
        add_tool(
            WRITE_TO_LONG_RUNNING_SHELL_COMMAND_TOOL_NAME,
            "Write input text to an existing long-running shell command.",
            {
                "type": "object",
                "properties": {"input": {"type": "string"}},
                "required": ["input"],
                "additionalProperties": False,
            },
        )
    if not requested_tool_ids or 11 in requested_tool_ids:
        add_tool(
            SUGGEST_NEW_CONVERSATION_TOOL_NAME,
            "Suggest starting a new conversation from an existing message id.",
            {
                "type": "object",
                "properties": {"message_id": {"type": "string"}},
                "required": ["message_id"],
                "additionalProperties": False,
            },
        )

    if local_request.raw_request.settings.web_context_retrieval_enabled:
        anthropic_tools.append(ANTHROPIC_WEB_SEARCH_TOOL)

    if not requested_tool_ids or 8 in requested_tool_ids:
        for alias, server_and_uri in mcp_resource_aliases.items():
            server_name, uri = server_and_uri
            add_tool(
                alias,
                f"Read MCP resource {uri} from server {server_name}.",
                {
                    "type": "object",
                    "properties": {},
                    "required": [],
                    "additionalProperties": False,
                },
            )

    if not requested_tool_ids or 9 in requested_tool_ids:
        for alias, server_and_tool in mcp_tool_aliases.items():
            server_name, actual_name = server_and_tool
            matching_tool = None
            if mcp_registry is not None and server_name in mcp_registry:
                matching_tool = mcp_registry[server_name].tools.get(actual_name)
            if matching_tool is None:
                request_tool = next(
                    (tool for tool in local_request.raw_request.mcp_context.tools if tool.name == actual_name),
                    None,
                )
                if request_tool is not None:
                    input_schema = MessageToDict(request_tool.input_schema)
                    if not isinstance(input_schema, dict):
                        input_schema = {"type": "object", "properties": {}, "additionalProperties": True}
                    description = request_tool.description or f"Call MCP tool {actual_name}."
                else:
                    continue
            else:
                input_schema = matching_tool.input_schema
                description = matching_tool.description or f"Call MCP tool {actual_name}."
            add_tool(
                alias,
                description,
                input_schema,
            )

    return openai_tools, anthropic_tools


def sanitize_tool_alias(raw_name: str) -> str:
    sanitized = re.sub(r"[^a-zA-Z0-9_]", "_", raw_name)
    sanitized = re.sub(r"_+", "_", sanitized).strip("_")
    if sanitized == "":
        sanitized = "tool"
    return sanitized[:40]


def build_mcp_alias_maps(
    local_request: LocalAIRequest,
    mcp_registry: dict[str, MCPRemoteServer] | None = None,
) -> tuple[dict[str, tuple[str, str]], dict[str, tuple[str, str]]]:
    tool_aliases: dict[str, tuple[str, str]] = {}
    resource_aliases: dict[str, tuple[str, str]] = {}

    for index, tool in enumerate(local_request.raw_request.mcp_context.tools):
        alias = f"mcp_tool__{index}__{sanitize_tool_alias(tool.name)}"
        tool_aliases[alias] = ("request", tool.name)

    for index, resource in enumerate(local_request.raw_request.mcp_context.resources):
        alias = f"mcp_resource__{index}"
        resource_aliases[alias] = ("request", resource.uri)

    if mcp_registry is not None:
        for server_name, server in mcp_registry.items():
            for index, tool_name in enumerate(sorted(server.tools.keys())):
                alias = f"mcp_tool__cfg__{sanitize_tool_alias(server_name)}__{index}__{sanitize_tool_alias(tool_name)}"
                tool_aliases[alias] = (server_name, tool_name)
            for index, resource_uri in enumerate(sorted(server.resources.keys())):
                alias = f"mcp_resource__cfg__{sanitize_tool_alias(server_name)}__{index}"
                resource_aliases[alias] = (server_name, resource_uri)

    return tool_aliases, resource_aliases


def build_conversation_state_key(conversation_id: str, task_id: str) -> str:
    return f"{conversation_id}:{task_id}"


async def execute_mcp_tool_call(
    session: ClientSession,
    config: ShimConfig,
    mcp_registry: dict[str, MCPRemoteServer],
    tool_call: ShellToolCall,
) -> ShellToolResult | None:
    if tool_call.tool_name == CALL_MCP_TOOL_NAME:
        server_name_value = tool_call.arguments.get("server_name")
        requested_name = tool_call.arguments.get("name")
        server_name = server_name_value if isinstance(server_name_value, str) else None
        actual_tool_name = requested_name if isinstance(requested_name, str) else None

        if isinstance(requested_name, str) and requested_name in {"list_tools", "list_mcp_tools", "list_mcp_resources"}:
            return ShellToolResult(
                tool_call_id=tool_call.tool_call_id,
                tool_name=CALL_MCP_TOOL_NAME,
                command=None,
                output=render_mcp_registry_overview(mcp_registry),
                exit_code=None,
            )

        if server_name is not None and actual_tool_name is not None and server_name in mcp_registry:
            pass
        elif isinstance(requested_name, str):
            server_name = None
            actual_tool_name = None
            for configured_server_name, server in mcp_registry.items():
                if requested_name in server.tools:
                    server_name = configured_server_name
                    actual_tool_name = requested_name
                    break

        if server_name is None or actual_tool_name is None:
            return ShellToolResult(
                tool_call_id=tool_call.tool_call_id,
                tool_name=CALL_MCP_TOOL_NAME,
                command=None,
                output="MCP server for tool not found",
                exit_code=None,
            )

        response_payload = await call_mcp_jsonrpc(
            session,
            config,
            mcp_registry[server_name],
            "tools/call",
            {
                "name": actual_tool_name,
                "arguments": tool_call.arguments.get("args", {}),
            },
            request_id=100 + hash(tool_call.tool_call_id) % 100000,
        )
        result_payload = response_payload.get("result")
        if not isinstance(result_payload, dict):
            return ShellToolResult(
                tool_call_id=tool_call.tool_call_id,
                tool_name=CALL_MCP_TOOL_NAME,
                command=None,
                output="MCP tool call returned an invalid payload",
                exit_code=None,
            )

        return parse_shell_tool_result(
            build_tool_result_request_from_mcp_result(
                tool_call.tool_call_id,
                CALL_MCP_TOOL_NAME,
                result_payload,
            )
        )

    if tool_call.tool_name == READ_MCP_RESOURCE_TOOL_NAME:
        requested_uri = tool_call.arguments.get("uri")
        requested_server = tool_call.arguments.get("server_name")
        if isinstance(requested_uri, list) and len(requested_uri) == 2:
            if isinstance(requested_uri[0], str) and isinstance(requested_uri[1], str):
                requested_server = requested_uri[0]
                requested_uri = requested_uri[1]
        if isinstance(requested_uri, str) and requested_uri in {"mcp://list", "mcp:///", "mcp://"}:
            return ShellToolResult(
                tool_call_id=tool_call.tool_call_id,
                tool_name=READ_MCP_RESOURCE_TOOL_NAME,
                command=None,
                output=render_mcp_registry_overview(mcp_registry),
                exit_code=None,
            )
        if not isinstance(requested_uri, str):
            return None

        server_name_value = tool_call.arguments.get("server_name")
        server_name = requested_server if isinstance(requested_server, str) else (
            server_name_value if isinstance(server_name_value, str) else None
        )
        actual_uri = None
        if server_name is not None and server_name in mcp_registry and requested_uri in mcp_registry[server_name].resources:
            actual_uri = requested_uri
        else:
            server_name = None
            for configured_server_name, server in mcp_registry.items():
                if requested_uri in server.resources:
                    server_name = configured_server_name
                    actual_uri = requested_uri
                    break

        if server_name is None or actual_uri is None:
            return ShellToolResult(
                tool_call_id=tool_call.tool_call_id,
                tool_name=READ_MCP_RESOURCE_TOOL_NAME,
                command=None,
                output="MCP server resource not found",
                exit_code=None,
            )

        response_payload = await call_mcp_jsonrpc(
            session,
            config,
            mcp_registry[server_name],
            "resources/read",
            {"uri": actual_uri},
            request_id=100 + hash(tool_call.tool_call_id) % 100000,
        )
        result_payload = response_payload.get("result")
        if not isinstance(result_payload, dict):
            return ShellToolResult(
                tool_call_id=tool_call.tool_call_id,
                tool_name=READ_MCP_RESOURCE_TOOL_NAME,
                command=None,
                output="MCP resource read returned an invalid payload",
                exit_code=None,
            )

        return parse_shell_tool_result(
            build_tool_result_request_from_mcp_result(
                tool_call.tool_call_id,
                READ_MCP_RESOURCE_TOOL_NAME,
                result_payload,
            )
        )

    return None


def resolve_tool_path(path_value: str, cwd: str) -> Path:
    expanded_path = Path(path_value).expanduser()
    if expanded_path.is_absolute():
        return expanded_path
    return (Path(cwd) / expanded_path).resolve()


def should_skip_path(target_path: Path, root_path: Path) -> bool:
    try:
        relative_path = target_path.relative_to(root_path)
    except Exception:
        relative_path = target_path
    return "node_modules" in relative_path.parts


def resolve_effective_tool_cwd(local_request: LocalAIRequest) -> str:
    requested_cwd = local_request.cwd
    if requested_cwd:
        requested_path = Path(requested_cwd).expanduser()
        if requested_path.exists() and requested_path.is_dir():
            return str(requested_path.resolve())

    return str(Path.home())


async def run_shell_command_async(command: str, cwd: str) -> tuple[str, int]:
    def _run() -> tuple[str, int]:
        completed = subprocess.run(
            command,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
        )
        output = completed.stdout
        if completed.stderr != "":
            output = f"{output}{completed.stderr}"
        return output, completed.returncode

    return await asyncio.to_thread(_run)


async def execute_local_tool_call(
    session: ClientSession,
    config: ShimConfig,
    mcp_registry: dict[str, MCPRemoteServer],
    tool_call: ShellToolCall,
    cwd: str,
) -> ShellToolResult:
    if tool_call.tool_name in {CALL_MCP_TOOL_NAME, READ_MCP_RESOURCE_TOOL_NAME}:
        try:
            mcp_result = await execute_mcp_tool_call(session, config, mcp_registry, tool_call)
            if mcp_result is not None:
                return mcp_result
            return ShellToolResult(
                tool_call_id=tool_call.tool_call_id,
                tool_name=tool_call.tool_name,
                command=None,
                output="MCP execution failed",
                exit_code=None,
            )
        except Exception as error:
            return ShellToolResult(
                tool_call_id=tool_call.tool_call_id,
                tool_name=tool_call.tool_name,
                command=None,
                output=f"MCP execution failed: {format_exception_message(error)}",
                exit_code=None,
            )

    if tool_call.tool_name == SHELL_TOOL_NAME:
        command = tool_call.command or str(tool_call.arguments.get("command", ""))
        output, exit_code = await run_shell_command_async(command, cwd)
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=command,
            output=output,
            exit_code=exit_code,
        )

    if tool_call.tool_name == READ_FILES_TOOL_NAME:
        files_payload = tool_call.arguments.get("files")
        results: list[dict[str, object]] = []
        if isinstance(files_payload, list):
            for item in files_payload:
                if not isinstance(item, dict):
                    continue
                name = item.get("name")
                if not isinstance(name, str):
                    continue
                target_path = resolve_tool_path(name, cwd)
                if should_skip_path(target_path, Path(cwd)) and "node_modules" not in name:
                    continue
                content = target_path.read_text(encoding="utf-8", errors="replace")
                line_ranges = item.get("line_ranges")
                if isinstance(line_ranges, list) and line_ranges:
                    content_lines = content.splitlines()
                    for line_range in line_ranges:
                        if not isinstance(line_range, dict):
                            continue
                        start = int(line_range.get("start", 1))
                        end = int(line_range.get("end", start))
                        snippet = "\n".join(content_lines[max(0, start - 1) : end])
                        results.append(
                            {
                                "file_path": str(target_path),
                                "content": snippet,
                                "line_range": {"start": start, "end": end},
                            }
                        )
                else:
                    results.append({"file_path": str(target_path), "content": content})
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output=json.dumps(results, ensure_ascii=False),
            exit_code=None,
        )

    if tool_call.tool_name == FILE_GLOB_V2_TOOL_NAME:
        patterns = [value for value in tool_call.arguments.get("patterns", []) if isinstance(value, str)]
        search_dir_value = tool_call.arguments.get("search_dir", cwd)
        search_dir = resolve_tool_path(str(search_dir_value), cwd)
        max_matches = int(tool_call.arguments.get("max_matches", 200) or 200)
        max_depth = int(tool_call.arguments.get("max_depth", 32) or 32)
        min_depth = int(tool_call.arguments.get("min_depth", 0) or 0)
        matched_files: list[str] = []
        for candidate in search_dir.rglob("*"):
            if not candidate.is_file():
                continue
            if should_skip_path(candidate, search_dir):
                continue
            depth = len(candidate.relative_to(search_dir).parts)
            if depth < min_depth or depth > max_depth:
                continue
            relative_path = candidate.relative_to(search_dir).as_posix()
            if patterns and not any(fnmatch(relative_path, pattern) for pattern in patterns):
                continue
            matched_files.append(str(candidate))
            if len(matched_files) >= max_matches:
                break
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output=json.dumps(matched_files, ensure_ascii=False),
            exit_code=None,
        )

    if tool_call.tool_name == FILE_GLOB_TOOL_NAME:
        patterns = [value for value in tool_call.arguments.get("patterns", []) if isinstance(value, str)]
        path_value = str(tool_call.arguments.get("path", cwd))
        target_dir = resolve_tool_path(path_value, cwd)
        matched_files: list[str] = []
        for candidate in target_dir.rglob("*"):
            if not candidate.is_file():
                continue
            if should_skip_path(candidate, target_dir):
                continue
            relative_path = candidate.relative_to(target_dir).as_posix()
            if patterns and not any(fnmatch(relative_path, pattern) for pattern in patterns):
                continue
            matched_files.append(str(candidate))
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output="\n".join(matched_files),
            exit_code=None,
        )

    if tool_call.tool_name == GREP_TOOL_NAME:
        queries = [value for value in tool_call.arguments.get("queries", []) if isinstance(value, str)]
        path_value = str(tool_call.arguments.get("path", cwd))
        target_dir = resolve_tool_path(path_value, cwd)
        matches_by_file: dict[str, set[int]] = {}
        for query in queries:
            completed = await asyncio.to_thread(
                subprocess.run,
                ["rg", "-n", "--no-heading", "--glob", "!node_modules/**", query, str(target_dir)],
                capture_output=True,
                text=True,
                check=False,
            )
            if completed.returncode not in {0, 1}:
                continue
            for line in completed.stdout.splitlines():
                parts = line.split(":", 2)
                if len(parts) < 2:
                    continue
                file_path, line_number_text = parts[0], parts[1]
                if not line_number_text.isdigit():
                    continue
                matches_by_file.setdefault(file_path, set()).add(int(line_number_text))
        matches = [
            {"file_path": file_path, "matched_lines": sorted(line_numbers)}
            for file_path, line_numbers in sorted(matches_by_file.items())
        ]
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output=json.dumps(matches, ensure_ascii=False),
            exit_code=None,
        )

    if tool_call.tool_name == SEARCH_CODEBASE_TOOL_NAME:
        query = str(tool_call.arguments.get("query", ""))
        codebase_path_value = str(tool_call.arguments.get("codebase_path", cwd) or cwd)
        codebase_path = resolve_tool_path(codebase_path_value, cwd)
        path_filters = [value for value in tool_call.arguments.get("path_filters", []) if isinstance(value, str)]
        completed = await asyncio.to_thread(
            subprocess.run,
            ["rg", "-n", "--no-heading", "--glob", "!node_modules/**", query, str(codebase_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        files: list[dict[str, object]] = []
        if completed.returncode in {0, 1}:
            seen_paths: set[str] = set()
            for line in completed.stdout.splitlines():
                parts = line.split(":", 3)
                if len(parts) < 4:
                    continue
                file_path_text, line_number_text, _column_text, match_text = parts
                file_path = Path(file_path_text)
                if should_skip_path(file_path, codebase_path):
                    continue
                relative_path = (
                    file_path.relative_to(codebase_path).as_posix()
                    if file_path.is_absolute() and codebase_path in file_path.parents
                    else file_path.as_posix()
                )
                if path_filters and not any(fnmatch(relative_path, pattern) for pattern in path_filters):
                    continue
                if file_path_text in seen_paths:
                    continue
                seen_paths.add(file_path_text)
                line_number = int(line_number_text) if line_number_text.isdigit() else 1
                files.append(
                    {
                        "file_path": file_path_text,
                        "content": match_text,
                        "line_range": {"start": line_number, "end": line_number},
                    }
                )
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output=json.dumps(files, ensure_ascii=False),
            exit_code=None,
        )

    if tool_call.tool_name == APPLY_FILE_DIFFS_TOOL_NAME:
        updated_files: list[dict[str, object]] = []
        for diff_payload in tool_call.arguments.get("diffs", []):
            if not isinstance(diff_payload, dict):
                continue
            file_path = diff_payload.get("file_path")
            search = diff_payload.get("search")
            replace = diff_payload.get("replace")
            if not isinstance(file_path, str) or not isinstance(search, str) or not isinstance(replace, str):
                continue
            target_path = resolve_tool_path(file_path, cwd)
            if should_skip_path(target_path, Path(cwd)) and "node_modules" not in file_path:
                continue
            original_content = target_path.read_text(encoding="utf-8", errors="replace")
            updated_content = original_content.replace(search, replace)
            target_path.write_text(updated_content, encoding="utf-8")
            updated_files.append(
                {
                    "file_path": str(target_path),
                    "content": updated_content,
                    "was_edited_by_user": False,
                }
            )
        for new_file_payload in tool_call.arguments.get("new_files", []):
            if not isinstance(new_file_payload, dict):
                continue
            file_path = new_file_payload.get("file_path")
            content = new_file_payload.get("content")
            if not isinstance(file_path, str) or not isinstance(content, str):
                continue
            target_path = resolve_tool_path(file_path, cwd)
            target_path.parent.mkdir(parents=True, exist_ok=True)
            target_path.write_text(content, encoding="utf-8")
            updated_files.append(
                {
                    "file_path": str(target_path),
                    "content": content,
                    "was_edited_by_user": False,
                }
            )
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output=json.dumps(updated_files, ensure_ascii=False),
            exit_code=None,
        )

    if tool_call.tool_name == SUGGEST_PLAN_TOOL_NAME:
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output=json.dumps({"accepted": True}, ensure_ascii=False),
            exit_code=None,
        )

    if tool_call.tool_name == SUGGEST_CREATE_PLAN_TOOL_NAME:
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output=json.dumps({"accepted": True}, ensure_ascii=False),
            exit_code=None,
        )

    if tool_call.tool_name == WRITE_TO_LONG_RUNNING_SHELL_COMMAND_TOOL_NAME:
        input_value = str(tool_call.arguments.get("input", ""))
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output=input_value,
            exit_code=0,
        )

    if tool_call.tool_name == SUGGEST_NEW_CONVERSATION_TOOL_NAME:
        return ShellToolResult(
            tool_call_id=tool_call.tool_call_id,
            tool_name=tool_call.tool_name,
            command=None,
            output=json.dumps({"accepted": {"message_id": str(tool_call.arguments.get("message_id", ""))}}, ensure_ascii=False),
            exit_code=None,
        )

    return ShellToolResult(
        tool_call_id=tool_call.tool_call_id,
        tool_name=tool_call.tool_name,
        command=tool_call.command,
        output="Unsupported tool",
        exit_code=None,
    )


def build_tool_result_request_from_mcp_result(
    tool_call_id: str,
    tool_name: str,
    result_payload: dict[str, object],
) -> request_pb2.Request.Input.ToolCallResult:
    tool_result = request_pb2.Request.Input.ToolCallResult()
    tool_result.tool_call_id = tool_call_id

    if tool_name == CALL_MCP_TOOL_NAME:
        call_result = tool_result.call_mcp_tool.success
        results = result_payload.get("content")
        if isinstance(results, list):
            for item in results:
                if not isinstance(item, dict):
                    continue
                result_item = call_result.results.add()
                item_type = item.get("type")
                if item_type == "text":
                    text_value = item.get("text")
                    if isinstance(text_value, str):
                        result_item.text.text = text_value
                elif item_type == "image":
                    source = item.get("source")
                    if isinstance(source, dict):
                        data_value = source.get("data")
                        mime_type = source.get("mimeType") or source.get("media_type")
                        if isinstance(data_value, str):
                            result_item.image.data = base64.b64decode(data_value)
                        if isinstance(mime_type, str):
                            result_item.image.mime_type = mime_type
                elif item_type == "resource":
                    resource = item.get("resource")
                    if isinstance(resource, dict):
                        uri = resource.get("uri")
                        if isinstance(uri, str):
                            result_item.resource.uri = uri
                        text_value = resource.get("text")
                        if isinstance(text_value, str):
                            result_item.resource.text.content = text_value
                            result_item.resource.text.mime_type = str(resource.get("mimeType", "text/plain"))
        return tool_result

    if tool_name == READ_MCP_RESOURCE_TOOL_NAME:
        read_result = tool_result.read_mcp_resource.success
        contents = result_payload.get("contents")
        if isinstance(contents, list):
            for item in contents:
                if not isinstance(item, dict):
                    continue
                content_item = read_result.contents.add()
                uri = item.get("uri")
                if isinstance(uri, str):
                    content_item.uri = uri
                text_value = item.get("text")
                if isinstance(text_value, str):
                    content_item.text.content = text_value
                    content_item.text.mime_type = str(item.get("mimeType", "text/plain"))
                blob = item.get("blob")
                if isinstance(blob, str):
                    content_item.binary.data = base64.b64decode(blob)
                    content_item.binary.mime_type = str(item.get("mimeType", "application/octet-stream"))
        return tool_result

    return tool_result


def render_mcp_registry_overview(mcp_registry: dict[str, MCPRemoteServer]) -> str:
    payload = {
        server_name: {
            "tools": sorted(server.tools.keys()),
            "resources": sorted(server.resources.keys()),
        }
        for server_name, server in mcp_registry.items()
    }
    return json.dumps(payload, ensure_ascii=False)


def format_shell_tool_result(tool_result: ShellToolResult) -> str:
    if tool_result.tool_name != SHELL_TOOL_NAME:
        return tool_result.output

    lines = [f"command: {tool_result.command}"]
    if tool_result.exit_code is not None:
        lines.append(f"exit_code: {tool_result.exit_code}")
    lines.append("output:")
    lines.append(tool_result.output)
    return "\n".join(lines)


def build_openai_tool_call_payload(tool_call: ShellToolCall) -> dict[str, object]:
    return {
        "id": tool_call.tool_call_id,
        "type": "function",
        "function": {
            "name": tool_call.tool_name,
            "arguments": json.dumps(tool_call.arguments, ensure_ascii=False),
        },
    }


def build_tool_call_from_task_message(message: request_pb2.Message) -> ShellToolCall | None:
    tool_call_id = message.tool_call.tool_call_id
    if tool_call_id == "":
        return None

    if message.tool_call.HasField("run_shell_command"):
        shell_call = message.tool_call.run_shell_command
        if is_synthetic_mcp_display_command(shell_call.command):
            return None
        is_read_only, uses_pager, is_risky = infer_shell_command_flags(shell_call.command)
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=SHELL_TOOL_NAME,
            command=shell_call.command,
            arguments={"command": shell_call.command},
            is_read_only=is_read_only,
            uses_pager=uses_pager,
            is_risky=is_risky,
        )

    if message.tool_call.HasField("read_files"):
        files: list[dict[str, object]] = []
        for file_payload in message.tool_call.read_files.files:
            item: dict[str, object] = {"name": file_payload.name}
            if file_payload.line_ranges:
                item["line_ranges"] = [
                    {"start": line_range.start, "end": line_range.end}
                    for line_range in file_payload.line_ranges
                ]
            files.append(item)
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=READ_FILES_TOOL_NAME,
            arguments={"files": files},
            is_read_only=True,
            uses_pager=False,
            is_risky=False,
        )

    if message.tool_call.HasField("search_codebase"):
        search_payload = message.tool_call.search_codebase
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=SEARCH_CODEBASE_TOOL_NAME,
            arguments={
                "query": search_payload.query,
                "path_filters": list(search_payload.path_filters),
                "codebase_path": search_payload.codebase_path,
            },
            is_read_only=True,
            uses_pager=False,
            is_risky=False,
        )

    if message.tool_call.HasField("grep"):
        grep_payload = message.tool_call.grep
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=GREP_TOOL_NAME,
            arguments={"queries": list(grep_payload.queries), "path": grep_payload.path},
            is_read_only=True,
            uses_pager=False,
            is_risky=False,
        )

    if message.tool_call.HasField("file_glob"):
        glob_payload = message.tool_call.file_glob
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=FILE_GLOB_TOOL_NAME,
            is_read_only=True,
            uses_pager=False,
            is_risky=False,
            arguments={"patterns": list(glob_payload.patterns), "path": glob_payload.path},
        )

    if message.tool_call.HasField("file_glob_v2"):
        glob_payload = message.tool_call.file_glob_v2
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=FILE_GLOB_V2_TOOL_NAME,
            arguments={
                "patterns": list(glob_payload.patterns),
                "search_dir": glob_payload.search_dir,
                "max_matches": glob_payload.max_matches,
                "max_depth": glob_payload.max_depth,
                "min_depth": glob_payload.min_depth,
            },
            is_read_only=True,
            uses_pager=False,
            is_risky=False,
        )

    if message.tool_call.HasField("apply_file_diffs"):
        apply_payload = message.tool_call.apply_file_diffs
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=APPLY_FILE_DIFFS_TOOL_NAME,
            is_read_only=False,
            uses_pager=False,
            is_risky=True,
            arguments={
                "summary": apply_payload.summary,
                "diffs": [
                    {
                        "file_path": diff.file_path,
                        "search": diff.search,
                        "replace": diff.replace,
                    }
                    for diff in apply_payload.diffs
                ],
                "new_files": [
                    {
                        "file_path": new_file.file_path,
                        "content": new_file.content,
                    }
                    for new_file in apply_payload.new_files
                ],
            },
        )

    if message.tool_call.HasField("suggest_plan"):
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=SUGGEST_PLAN_TOOL_NAME,
            is_read_only=True,
            uses_pager=False,
            is_risky=False,
            arguments={"summary": message.tool_call.suggest_plan.summary},
        )

    if message.tool_call.HasField("suggest_create_plan"):
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=SUGGEST_CREATE_PLAN_TOOL_NAME,
            is_read_only=True,
            uses_pager=False,
            is_risky=False,
            arguments={},
        )

    if message.tool_call.HasField("read_mcp_resource"):
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=READ_MCP_RESOURCE_TOOL_NAME,
            is_read_only=True,
            uses_pager=False,
            is_risky=False,
            arguments={"uri": message.tool_call.read_mcp_resource.uri},
        )

    if message.tool_call.HasField("call_mcp_tool"):
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=CALL_MCP_TOOL_NAME,
            is_read_only=False,
            uses_pager=False,
            is_risky=False,
            arguments={
                "name": message.tool_call.call_mcp_tool.name,
                "args": MessageToDict(message.tool_call.call_mcp_tool.args),
            },
        )

    if message.tool_call.HasField("write_to_long_running_shell_command"):
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=WRITE_TO_LONG_RUNNING_SHELL_COMMAND_TOOL_NAME,
            is_read_only=False,
            uses_pager=False,
            is_risky=False,
            arguments={
                "input": base64.b64encode(message.tool_call.write_to_long_running_shell_command.input).decode("ascii")
            },
        )

    if message.tool_call.HasField("suggest_new_conversation"):
        return ShellToolCall(
            tool_call_id=tool_call_id,
            tool_name=SUGGEST_NEW_CONVERSATION_TOOL_NAME,
            is_read_only=True,
            uses_pager=False,
            is_risky=False,
            arguments={"message_id": message.tool_call.suggest_new_conversation.message_id},
        )

    return None


def build_conversation_state(
    local_request: LocalAIRequest,
    config: ShimConfig,
    mcp_registry: dict[str, MCPRemoteServer] | None = None,
) -> ConversationState:
    provider_name = resolve_provider_name(local_request.model_id)
    target_model = resolve_provider_model(local_request.model_id, config)
    system_prompt = build_system_prompt(local_request, mcp_registry)
    mcp_tool_aliases, mcp_resource_aliases = build_mcp_alias_maps(local_request, mcp_registry)
    messages: list[dict[str, object]] = []

    for task in local_request.raw_request.task_context.tasks:
        has_seen_user_query = False
        for message in task.messages:
            message_kind = message.WhichOneof("message")

            if provider_name == "openai":
                if message_kind == "user_query" and message.user_query.query != "":
                    has_seen_user_query = True
                    messages.append({"role": "user", "content": message.user_query.query})
                elif has_seen_user_query and message_kind == "agent_output" and message.agent_output.text != "":
                    messages.append({"role": "assistant", "content": message.agent_output.text})
                elif has_seen_user_query and message_kind == "tool_call":
                    tool_call = build_tool_call_from_task_message(message)
                    if tool_call is not None:
                        messages.append(
                            {
                                "role": "assistant",
                                "content": None,
                                "tool_calls": [build_openai_tool_call_payload(tool_call)],
                            }
                        )
                elif has_seen_user_query and message_kind == "tool_call_result":
                    tool_result = parse_shell_tool_result(message.tool_call_result)
                    if tool_result is not None and not is_synthetic_mcp_display_command(tool_result.command):
                        messages.append(
                            {
                                "role": "tool",
                                "tool_call_id": tool_result.tool_call_id,
                                "content": format_shell_tool_result(tool_result),
                            }
                        )
                continue

            if provider_name == "anthropic":
                if message_kind == "user_query" and message.user_query.query != "":
                    has_seen_user_query = True
                    messages.append({"role": "user", "content": message.user_query.query})
                elif has_seen_user_query and message_kind == "agent_output" and message.agent_output.text != "":
                    messages.append(
                        {
                            "role": "assistant",
                            "content": [{"type": "text", "text": message.agent_output.text}],
                        }
                    )
                elif has_seen_user_query and message_kind == "tool_call":
                    tool_call = build_tool_call_from_task_message(message)
                    if tool_call is not None:
                        messages.append(
                            {
                                "role": "assistant",
                                "content": [
                                    {
                                        "type": "tool_use",
                                        "id": tool_call.tool_call_id,
                                        "name": tool_call.tool_name,
                                        "input": tool_call.arguments,
                                    }
                                ],
                            }
                        )
                elif has_seen_user_query and message_kind == "tool_call_result":
                    tool_result = parse_shell_tool_result(message.tool_call_result)
                    if tool_result is not None and not is_synthetic_mcp_display_command(tool_result.command):
                        messages.append(
                            {
                                "role": "user",
                                "content": [
                                    {
                                        "type": "tool_result",
                                        "tool_use_id": tool_result.tool_call_id,
                                        "content": format_shell_tool_result(tool_result),
                                    }
                                ],
                            }
                        )
                continue

    return ConversationState(
        provider_name=provider_name,
        target_model=target_model,
        system_prompt=system_prompt,
        messages=messages,
        mcp_tool_aliases=mcp_tool_aliases,
        mcp_resource_aliases=mcp_resource_aliases,
    )


def get_or_create_conversation_state(
    state_map: dict[str, ConversationState],
    state_key: str,
    local_request: LocalAIRequest,
    config: ShimConfig,
    mcp_registry: dict[str, MCPRemoteServer] | None = None,
) -> ConversationState:
    provider_name = resolve_provider_name(local_request.model_id)
    target_model = resolve_provider_model(local_request.model_id, config)
    system_prompt = build_system_prompt(local_request, mcp_registry)
    mcp_tool_aliases, mcp_resource_aliases = build_mcp_alias_maps(local_request, mcp_registry)
    existing_state = state_map.get(state_key)

    if existing_state is None or existing_state.provider_name != provider_name:
        next_state = build_conversation_state(local_request, config, mcp_registry)
        state_map[state_key] = next_state
        return next_state

    existing_state.target_model = target_model
    existing_state.system_prompt = system_prompt
    existing_state.mcp_tool_aliases = mcp_tool_aliases
    existing_state.mcp_resource_aliases = mcp_resource_aliases
    return existing_state


def append_user_text_to_state(conversation_state: ConversationState, user_text: str) -> None:
    if user_text == "":
        return

    last_message = conversation_state.messages[-1] if conversation_state.messages else None
    if isinstance(last_message, dict) and last_message.get("role") == "user" and last_message.get("content") == user_text:
        return

    conversation_state.messages.append({"role": "user", "content": user_text})


def find_pending_tool_call_ids(conversation_state: ConversationState) -> list[str]:
    pending_ids: list[str] = []

    for message in conversation_state.messages:
        role = message.get("role")
        if role == "assistant":
            tool_calls = message.get("tool_calls")
            if isinstance(tool_calls, list):
                for tool_call in tool_calls:
                    if isinstance(tool_call, dict):
                        tool_call_id = tool_call.get("id")
                        if isinstance(tool_call_id, str) and tool_call_id not in pending_ids:
                            pending_ids.append(tool_call_id)

            content = message.get("content")
            if isinstance(content, list):
                for item in content:
                    if not isinstance(item, dict):
                        continue
                    if item.get("type") != "tool_use":
                        continue
                    tool_call_id = item.get("id")
                    if isinstance(tool_call_id, str) and tool_call_id not in pending_ids:
                        pending_ids.append(tool_call_id)

        if role == "tool":
            tool_call_id = message.get("tool_call_id")
            if isinstance(tool_call_id, str) and tool_call_id in pending_ids:
                pending_ids.remove(tool_call_id)

        if role == "user":
            content = message.get("content")
            if not isinstance(content, list):
                continue
            for item in content:
                if not isinstance(item, dict):
                    continue
                if item.get("type") != "tool_result":
                    continue
                tool_call_id = item.get("tool_use_id")
                if isinstance(tool_call_id, str) and tool_call_id in pending_ids:
                    pending_ids.remove(tool_call_id)

    return pending_ids


def append_interrupted_tool_results_to_state(
    conversation_state: ConversationState,
    pending_tool_call_ids: list[str],
) -> None:
    if not pending_tool_call_ids:
        return

    interruption_text = "Tool execution was interrupted before completion because the user sent a new request."

    if conversation_state.provider_name == "anthropic":
        conversation_state.messages.append(
            {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": tool_call_id,
                        "content": interruption_text,
                    }
                    for tool_call_id in pending_tool_call_ids
                ],
            }
        )
        return

    for tool_call_id in pending_tool_call_ids:
        conversation_state.messages.append(
            {
                "role": "tool",
                "tool_call_id": tool_call_id,
                "content": interruption_text,
            }
        )


def append_tool_results_to_state(
    conversation_state: ConversationState,
    tool_results: tuple[ShellToolResult, ...],
) -> None:
    if not tool_results:
        return

    if conversation_state.provider_name == "anthropic":
        conversation_state.messages.append(
            {
                "role": "user",
                "content": [
                    {
                        "type": "tool_result",
                        "tool_use_id": tool_result.tool_call_id,
                        "content": format_shell_tool_result(tool_result),
                    }
                    for tool_result in tool_results
                ],
            }
        )
        return

    for tool_result in tool_results:
        conversation_state.messages.append(
            {
                "role": "tool",
                "tool_call_id": tool_result.tool_call_id,
                "content": format_shell_tool_result(tool_result),
            }
        )


def extract_openai_text(payload: dict[str, object]) -> str:
    choices = payload.get("choices")
    if isinstance(choices, list) and choices:
        first_choice = choices[0]
        if isinstance(first_choice, dict):
            message = first_choice.get("message")
            if isinstance(message, dict):
                content = message.get("content")
                if isinstance(content, str):
                    return content
    return json.dumps(payload, ensure_ascii=False)


def extract_anthropic_text(payload: dict[str, object]) -> str:
    content = payload.get("content")
    if isinstance(content, list):
        text_chunks: list[str] = []
        has_tool_use = False
        for item in content:
            if isinstance(item, dict):
                if item.get("type") == "tool_use":
                    has_tool_use = True
                text_value = item.get("text")
                if isinstance(text_value, str):
                    text_chunks.append(text_value)
        if text_chunks:
            return "".join(text_chunks)
        if has_tool_use:
            return ""
    return json.dumps(payload, ensure_ascii=False)


def extract_google_text(payload: dict[str, object]) -> str:
    candidates = payload.get("candidates")
    if isinstance(candidates, list) and candidates:
        first_candidate = candidates[0]
        if isinstance(first_candidate, dict):
            content = first_candidate.get("content")
            if isinstance(content, dict):
                parts = content.get("parts")
                if isinstance(parts, list):
                    text_chunks: list[str] = []
                    for item in parts:
                        if isinstance(item, dict):
                            text_value = item.get("text")
                            if isinstance(text_value, str):
                                text_chunks.append(text_value)
                    if text_chunks:
                        return "".join(text_chunks)
    text_value = payload.get("text")
    if isinstance(text_value, str):
        return text_value
    return json.dumps(payload, ensure_ascii=False)


async def fetch_web_search_context(
    session: ClientSession,
    query: str,
) -> str | None:
    if query.strip() == "":
        return None

    search_url = "https://html.duckduckgo.com/html/"
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0 Safari/537.36",
    }

    try:
        async with session.post(
            search_url,
            data={"q": query},
            headers=headers,
            timeout=ClientTimeout(total=WEB_SEARCH_TIMEOUT_SECONDS),
        ) as response:
            html_text = await response.text()
    except Exception:
        return None

    results: list[str] = []
    seen_urls: set[str] = set()

    for href, title in re.findall(r'<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>(.*?)</a>', html_text, flags=re.S):
        decoded_href = html.unescape(href)
        parsed_href = urlparse(decoded_href)
        if parsed_href.netloc.endswith("duckduckgo.com"):
            query_map = parse_qs(parsed_href.query)
            redirect_target = query_map.get("uddg")
            if redirect_target:
                decoded_href = unquote(redirect_target[0])
        if decoded_href in seen_urls:
            continue
        seen_urls.add(decoded_href)
        clean_title = re.sub(r"<.*?>", "", title)
        clean_title = html.unescape(clean_title).strip()
        if clean_title == "":
            continue
        results.append(f"- {clean_title} — {decoded_href}")
        if len(results) >= WEB_SEARCH_RESULT_LIMIT:
            break

    if not results:
        return None

    return "web_search_results:\n" + "\n".join(results)


def extract_openai_tool_calls(
    message: dict[str, object],
    conversation_state: ConversationState,
) -> tuple[ShellToolCall, ...]:
    tool_calls = message.get("tool_calls")
    if not isinstance(tool_calls, list):
        return ()

    parsed_tool_calls: list[ShellToolCall] = []
    for raw_tool_call in tool_calls:
        if not isinstance(raw_tool_call, dict):
            continue
        if raw_tool_call.get("type") != "function":
            continue
        function_payload = raw_tool_call.get("function")
        if not isinstance(function_payload, dict):
            continue
        tool_name = function_payload.get("name")
        if not isinstance(tool_name, str):
            continue
        arguments_payload = function_payload.get("arguments")
        if not isinstance(arguments_payload, str):
            continue
        try:
            arguments = json.loads(arguments_payload)
        except json.JSONDecodeError:
            continue
        if not isinstance(arguments, dict):
            continue
        tool_call_id = raw_tool_call.get("id")
        if not isinstance(tool_call_id, str):
            continue
        command = arguments.get("command")
        normalized_command = command if isinstance(command, str) else None
        mapped_tool_name = tool_name
        mapped_arguments = arguments
        if tool_name in conversation_state.mcp_tool_aliases:
            server_name, actual_tool_name = conversation_state.mcp_tool_aliases[tool_name]
            mapped_tool_name = CALL_MCP_TOOL_NAME
            mapped_arguments = {"server_name": server_name, "name": actual_tool_name, "args": arguments}
        elif tool_name in conversation_state.mcp_resource_aliases:
            server_name, actual_uri = conversation_state.mcp_resource_aliases[tool_name]
            mapped_tool_name = READ_MCP_RESOURCE_TOOL_NAME
            mapped_arguments = {"server_name": server_name, "uri": actual_uri}

        if mapped_tool_name not in SUPPORTED_TOOL_NAMES:
            continue

        normalized_command = mapped_arguments.get("command") if isinstance(mapped_arguments.get("command"), str) else None
        if mapped_tool_name == SHELL_TOOL_NAME and normalized_command is None:
            continue
        if normalized_command is None:
            is_read_only = True
            uses_pager = False
            is_risky = False
        else:
            is_read_only, uses_pager, is_risky = infer_shell_command_flags(normalized_command)
        parsed_tool_calls.append(
            ShellToolCall(
                tool_call_id=tool_call_id,
                tool_name=mapped_tool_name,
                command=normalized_command,
                arguments=mapped_arguments,
                is_read_only=is_read_only,
                uses_pager=uses_pager,
                is_risky=is_risky,
            )
        )

    return tuple(parsed_tool_calls)


def extract_anthropic_tool_calls(
    payload: dict[str, object],
    conversation_state: ConversationState,
) -> tuple[ShellToolCall, ...]:
    content = payload.get("content")
    if not isinstance(content, list):
        return ()

    parsed_tool_calls: list[ShellToolCall] = []
    for item in content:
        if not isinstance(item, dict):
            continue
        if item.get("type") != "tool_use":
            continue
        tool_name = item.get("name")
        if not isinstance(tool_name, str):
            continue
        tool_call_id = item.get("id")
        input_payload = item.get("input")
        if not isinstance(tool_call_id, str) or not isinstance(input_payload, dict):
            continue
        command = input_payload.get("command")
        normalized_command = command if isinstance(command, str) else None
        mapped_tool_name = tool_name
        mapped_arguments = input_payload
        if tool_name in conversation_state.mcp_tool_aliases:
            server_name, actual_tool_name = conversation_state.mcp_tool_aliases[tool_name]
            mapped_tool_name = CALL_MCP_TOOL_NAME
            mapped_arguments = {"server_name": server_name, "name": actual_tool_name, "args": input_payload}
        elif tool_name in conversation_state.mcp_resource_aliases:
            server_name, actual_uri = conversation_state.mcp_resource_aliases[tool_name]
            mapped_tool_name = READ_MCP_RESOURCE_TOOL_NAME
            mapped_arguments = {"server_name": server_name, "uri": actual_uri}

        if mapped_tool_name not in SUPPORTED_TOOL_NAMES:
            continue

        normalized_command = mapped_arguments.get("command") if isinstance(mapped_arguments.get("command"), str) else None
        if mapped_tool_name == SHELL_TOOL_NAME and normalized_command is None:
            continue
        if normalized_command is None:
            is_read_only = True
            uses_pager = False
            is_risky = False
        else:
            is_read_only, uses_pager, is_risky = infer_shell_command_flags(normalized_command)
        parsed_tool_calls.append(
            ShellToolCall(
                tool_call_id=tool_call_id,
                tool_name=mapped_tool_name,
                command=normalized_command,
                arguments=mapped_arguments,
                is_read_only=is_read_only,
                uses_pager=uses_pager,
                is_risky=is_risky,
            )
        )

    return tuple(parsed_tool_calls)


async def run_openai_request(
    session: ClientSession,
    provider: ProviderConfig,
    local_request: LocalAIRequest,
    conversation_state: ConversationState,
    config: ShimConfig,
    mcp_registry: dict[str, MCPRemoteServer] | None = None,
) -> LocalAIResult:
    if provider.api_key is None:
        raise RuntimeError("OpenAI-compatible API key is not configured.")

    endpoint = normalize_openai_base_url(provider.base_url)
    messages: list[dict[str, object]] = []
    if conversation_state.system_prompt != "":
        messages.append({"role": "system", "content": conversation_state.system_prompt})
    if local_request.raw_request.settings.web_context_retrieval_enabled:
        web_search_context = await fetch_web_search_context(session, local_request.user_text)
        if web_search_context is not None:
            messages.append({"role": "system", "content": web_search_context})
    messages.extend(conversation_state.messages)
    openai_tools, _anthropic_tools = build_supported_tool_schemas(local_request, mcp_registry)

    payload = {
        "model": conversation_state.target_model,
        "messages": messages,
        "stream": False,
        "tools": openai_tools,
        "tool_choice": "auto",
    }
    if conversation_state.target_model.startswith("gpt-5"):
        payload["max_completion_tokens"] = 2048
    else:
        payload["max_tokens"] = 2048
    headers = {
        "Authorization": f"Bearer {provider.api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "provider_request",
            "provider": "openai",
            "endpoint": endpoint,
            "payload": payload,
        },
    )

    async with session.post(
        endpoint,
        json=payload,
        headers=headers,
        timeout=ClientTimeout(total=PROVIDER_REQUEST_TIMEOUT_SECONDS),
    ) as response:
        response_text = await response.text()
        if response.status >= 400:
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "provider_error",
                    "provider": "openai",
                    "endpoint": endpoint,
                    "status": response.status,
                    "body": truncate_text(response_text, limit=8000),
                },
            )
            raise RuntimeError(
                f"OpenAI-compatible endpoint failed: status={response.status}, body={truncate_text(response_text, limit=1000)}"
            )
        data = json.loads(response_text)

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "provider_response",
            "provider": "openai",
            "endpoint": endpoint,
            "status": 200,
            "body": truncate_text(response_text, limit=4000),
        },
    )

    choices = data.get("choices")
    if not isinstance(choices, list) or not choices:
        return LocalAIResult(text=extract_openai_text(data))

    first_choice = choices[0]
    if not isinstance(first_choice, dict):
        return LocalAIResult(text=extract_openai_text(data))

    message = first_choice.get("message")
    if not isinstance(message, dict):
        return LocalAIResult(text=extract_openai_text(data))

    text_value = message.get("content")
    text = text_value if isinstance(text_value, str) else ""
    tool_calls = extract_openai_tool_calls(message, conversation_state)
    assistant_state_message: dict[str, object] = {
        "role": "assistant",
        "content": text if text != "" else None,
    }
    if tool_calls:
        assistant_state_message["tool_calls"] = [build_openai_tool_call_payload(tool_call) for tool_call in tool_calls]
    conversation_state.messages.append(assistant_state_message)

    return LocalAIResult(text=text, tool_calls=tool_calls)


async def run_anthropic_request(
    session: ClientSession,
    provider: ProviderConfig,
    local_request: LocalAIRequest,
    conversation_state: ConversationState,
    config: ShimConfig,
    mcp_registry: dict[str, MCPRemoteServer] | None = None,
) -> LocalAIResult:
    if provider.api_key is None:
        raise RuntimeError("Anthropic API key is not configured.")

    endpoint = normalize_anthropic_base_url(provider.base_url)
    _openai_tools, anthropic_tools = build_supported_tool_schemas(local_request, mcp_registry)
    payload: dict[str, object] = {
        "model": conversation_state.target_model,
        "max_tokens": 2048,
        "messages": conversation_state.messages,
        "tools": anthropic_tools,
    }
    if conversation_state.system_prompt != "":
        payload["system"] = conversation_state.system_prompt

    headers = {
        "x-api-key": provider.api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
        "accept": "application/json",
    }

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "provider_request",
            "provider": "anthropic",
            "endpoint": endpoint,
            "payload": payload,
        },
    )

    async with session.post(
        endpoint,
        json=payload,
        headers=headers,
        timeout=ClientTimeout(total=PROVIDER_REQUEST_TIMEOUT_SECONDS),
    ) as response:
        response_text = await response.text()
        if response.status >= 400:
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "provider_error",
                    "provider": "anthropic",
                    "endpoint": endpoint,
                    "status": response.status,
                    "body": truncate_text(response_text, limit=8000),
                },
            )
            raise RuntimeError(
                f"Anthropic endpoint failed: status={response.status}, body={truncate_text(response_text, limit=1000)}"
            )
        data = json.loads(response_text)

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "provider_response",
            "provider": "anthropic",
            "endpoint": endpoint,
            "status": 200,
            "body": truncate_text(response_text, limit=4000),
        },
    )

    content = data.get("content")
    if isinstance(content, list):
        conversation_state.messages.append({"role": "assistant", "content": content})
    return LocalAIResult(
        text=extract_anthropic_text(data),
        tool_calls=extract_anthropic_tool_calls(data, conversation_state),
    )


async def run_google_request(
    session: ClientSession,
    provider: ProviderConfig,
    local_request: LocalAIRequest,
    config: ShimConfig,
) -> LocalAIResult:
    if provider.api_key is None:
        raise RuntimeError("Google API key is not configured.")

    target_model = resolve_provider_model(local_request.model_id, config)
    endpoint = normalize_google_base_url(provider.base_url, target_model, provider.api_key)
    payload = {
        "contents": [
            {
                "parts": [{"text": local_request.user_text}],
            }
        ]
    }

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "provider_request",
            "provider": "google",
            "endpoint": endpoint,
            "payload": payload,
        },
    )

    async with session.post(
        endpoint,
        json=payload,
        timeout=ClientTimeout(total=PROVIDER_REQUEST_TIMEOUT_SECONDS),
    ) as response:
        response_text = await response.text()
        if response.status >= 400:
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "provider_error",
                    "provider": "google",
                    "endpoint": endpoint,
                    "status": response.status,
                    "body": truncate_text(response_text, limit=8000),
                },
            )
            raise RuntimeError(
                f"Google endpoint failed: status={response.status}, body={truncate_text(response_text, limit=1000)}"
            )
        data = json.loads(response_text)

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "provider_response",
            "provider": "google",
            "endpoint": endpoint,
            "status": 200,
            "body": truncate_text(response_text, limit=4000),
        },
    )

    return LocalAIResult(text=extract_google_text(data))


async def run_local_ai_request(
    session: ClientSession,
    config: ShimConfig,
    local_request: LocalAIRequest,
    conversation_state: ConversationState,
    mcp_registry: dict[str, MCPRemoteServer] | None = None,
    on_model_result: Callable[[LocalAIResult], Awaitable[None]] | None = None,
    on_tool_results: Callable[[tuple[ShellToolCall, ...], tuple[ShellToolResult, ...]], Awaitable[None]] | None = None,
) -> tuple[LocalAIResult, dict[str, str]]:
    metadata = build_provider_selection_metadata(config, local_request)
    provider_name = conversation_state.provider_name

    if not local_request.pending_tool_results and local_request.user_text.strip() == "":
        return LocalAIResult(text=""), metadata

    if local_request.pending_tool_results:
        append_tool_results_to_state(conversation_state, local_request.pending_tool_results)
    else:
        pending_tool_call_ids = find_pending_tool_call_ids(conversation_state)
        if pending_tool_call_ids:
            append_interrupted_tool_results_to_state(conversation_state, pending_tool_call_ids)
        append_user_text_to_state(conversation_state, local_request.user_text)

    for _loop_index in range(8):
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "local_ai_loop_iteration",
                "provider_name": provider_name,
                "model_id": local_request.model_id,
                "iteration": _loop_index + 1,
                "pending_message_count": len(conversation_state.messages),
            },
        )
        if provider_name == "anthropic" and config.anthropic is not None:
            local_result = await run_anthropic_request(
                session,
                config.anthropic,
                local_request,
                conversation_state,
                config,
                mcp_registry,
            )
        elif provider_name == "google" and config.google is not None:
            local_result = await run_google_request(session, config.google, local_request, config)
        elif provider_name == "openai" and config.openai is not None:
            local_result = await run_openai_request(
                session,
                config.openai,
                local_request,
                conversation_state,
                config,
                mcp_registry,
            )
        else:
            fallback_text = (
                "[local-shim echo]\n"
                f"model={local_request.model_id}\n"
                f"query={local_request.user_text}"
            )
            return LocalAIResult(text=fallback_text), metadata

        if on_model_result is not None:
            await on_model_result(local_result)

        if not local_result.tool_calls:
            conversation_state.awaiting_client_tool_results = False
            return local_result, metadata

        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "local_ai_loop_tool_calls",
                "provider_name": provider_name,
                "iteration": _loop_index + 1,
                "tool_calls": [
                    {
                        "tool_call_id": tool_call.tool_call_id,
                        "tool_name": tool_call.tool_name,
                        "arguments": truncate_text(json.dumps(tool_call.arguments, ensure_ascii=False), limit=1000),
                    }
                    for tool_call in local_result.tool_calls
                ],
            },
        )

        delegated_tool_calls = tuple(
            tool_call
            for tool_call in local_result.tool_calls
            if should_delegate_tool_call_to_client(local_request, tool_call)
        )
        if delegated_tool_calls:
            conversation_state.awaiting_client_tool_results = True
            return LocalAIResult(text="", reasoning=None, tool_calls=delegated_tool_calls), metadata

        cwd_for_tools = resolve_effective_tool_cwd(local_request)
        if local_request.cwd != cwd_for_tools:
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "tool_cwd_fallback",
                    "requested_cwd": local_request.cwd,
                    "effective_cwd": cwd_for_tools,
                    "shell_name": local_request.shell_name,
                },
            )
        executed_tool_results: list[ShellToolResult]
        for tool_call in local_result.tool_calls:
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "local_tool_execution_start",
                    "tool_call_id": tool_call.tool_call_id,
                    "tool_name": tool_call.tool_name,
                    "arguments": truncate_text(json.dumps(tool_call.arguments, ensure_ascii=False), limit=1000),
                },
            )
        if should_execute_tool_calls_in_parallel(local_result.tool_calls):
            executed_tool_results = list(
                await asyncio.gather(
                    *[
                        execute_local_tool_call(
                            session=session,
                            config=config,
                            mcp_registry=mcp_registry or {},
                            tool_call=tool_call,
                            cwd=cwd_for_tools,
                        )
                        for tool_call in local_result.tool_calls
                    ]
                )
            )
        else:
            executed_tool_results = []
            for tool_call in local_result.tool_calls:
                executed_tool_results.append(
                    await execute_local_tool_call(
                        session=session,
                        config=config,
                        mcp_registry=mcp_registry or {},
                        tool_call=tool_call,
                        cwd=cwd_for_tools,
                    )
                )

        for tool_result in executed_tool_results:
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "local_tool_execution_result",
                    "tool_call_id": tool_result.tool_call_id,
                    "tool_name": tool_result.tool_name,
                    "output": truncate_text(tool_result.output, limit=3000),
                    "exit_code": tool_result.exit_code,
                },
            )

        append_tool_results_to_state(conversation_state, tuple(executed_tool_results))
        conversation_state.awaiting_client_tool_results = False
        if on_tool_results is not None:
            await on_tool_results(local_result.tool_calls, tuple(executed_tool_results))

    raise RuntimeError("Tool execution loop exceeded safety limit.")


def encode_response_event(event: response_pb2.ResponseEvent) -> bytes:
    return event.SerializeToString()


def sse_chunk_from_event(event: response_pb2.ResponseEvent) -> bytes:
    encoded = encode_response_event(event)
    payload = base64.urlsafe_b64encode(encoded).decode("ascii")
    return f"data: {payload}\n\n".encode("utf-8")


def build_stream_init_event(conversation_id: str, request_id: str) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    event.init.conversation_id = conversation_id
    event.init.request_id = request_id
    return event


def build_create_task_event(task_id: str) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    action = event.client_actions.actions.add()
    action.create_task.task.id = task_id
    action.create_task.task.description = ""
    action.create_task.task.summary = ""
    action.create_task.task.status.in_progress.SetInParent()
    return event


def set_message_metadata(
    message: object,
    request_id: str,
    created_at: datetime,
) -> None:
    message.request_id = request_id
    timestamp = timestamp_pb2.Timestamp()
    timestamp.FromDatetime(created_at.astimezone(UTC))
    message.timestamp.CopyFrom(timestamp)


def build_add_message_event(
    task_id: str,
    message_id: str,
    text: str,
    reasoning: str | None,
    request_id: str,
    created_at: datetime,
) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    action = event.client_actions.actions.add()
    action.add_messages_to_task.task_id = task_id
    message = action.add_messages_to_task.messages.add()
    message.id = message_id
    message.task_id = task_id
    set_message_metadata(message, request_id, created_at)
    message.agent_output.text = text
    if reasoning:
        message.agent_output.reasoning = reasoning
    return event


def build_add_user_message_event(
    task_id: str,
    message_id: str,
    text: str,
    request_id: str,
    created_at: datetime,
) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    action = event.client_actions.actions.add()
    action.add_messages_to_task.task_id = task_id
    message = action.add_messages_to_task.messages.add()
    message.id = message_id
    message.task_id = task_id
    set_message_metadata(message, request_id, created_at)
    message.user_query.query = text
    return event


def build_add_tool_calls_event(
    task_id: str,
    tool_calls: tuple[ShellToolCall, ...],
    request_id: str,
    created_at: datetime,
) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    action = event.client_actions.actions.add()
    action.add_messages_to_task.task_id = task_id

    for tool_call in tool_calls:
        message = action.add_messages_to_task.messages.add()
        message.id = str(uuid.uuid4())
        message.task_id = task_id
        set_message_metadata(message, request_id, created_at)
        message.tool_call.tool_call_id = tool_call.tool_call_id
        if tool_call.tool_name == SHELL_TOOL_NAME and tool_call.command is not None:
            message.tool_call.run_shell_command.command = tool_call.command
            message.tool_call.run_shell_command.is_read_only = tool_call.is_read_only
            message.tool_call.run_shell_command.uses_pager = tool_call.uses_pager
            message.tool_call.run_shell_command.is_risky = tool_call.is_risky
            continue
        if tool_call.tool_name == READ_FILES_TOOL_NAME:
            files = tool_call.arguments.get("files")
            if isinstance(files, list):
                for file_payload in files:
                    if not isinstance(file_payload, dict):
                        continue
                    file_message = message.tool_call.read_files.files.add()
                    file_name = file_payload.get("name")
                    if isinstance(file_name, str):
                        file_message.name = file_name
                    line_ranges = file_payload.get("line_ranges")
                    if isinstance(line_ranges, list):
                        for line_range_payload in line_ranges:
                            if not isinstance(line_range_payload, dict):
                                continue
                            start = line_range_payload.get("start")
                            end = line_range_payload.get("end")
                            if isinstance(start, int) and isinstance(end, int):
                                line_range = file_message.line_ranges.add()
                                line_range.start = start
                                line_range.end = end
            continue
        if tool_call.tool_name == SEARCH_CODEBASE_TOOL_NAME:
            query = tool_call.arguments.get("query")
            codebase_path = tool_call.arguments.get("codebase_path")
            path_filters = tool_call.arguments.get("path_filters")
            if isinstance(query, str):
                message.tool_call.search_codebase.query = query
            if isinstance(codebase_path, str):
                message.tool_call.search_codebase.codebase_path = codebase_path
            if isinstance(path_filters, list):
                message.tool_call.search_codebase.path_filters.extend(
                    [value for value in path_filters if isinstance(value, str)]
                )
            continue
        if tool_call.tool_name == GREP_TOOL_NAME:
            queries = tool_call.arguments.get("queries")
            path_value = tool_call.arguments.get("path")
            if isinstance(queries, list):
                message.tool_call.grep.queries.extend([value for value in queries if isinstance(value, str)])
            if isinstance(path_value, str):
                message.tool_call.grep.path = path_value
            continue
        if tool_call.tool_name == FILE_GLOB_TOOL_NAME:
            patterns = tool_call.arguments.get("patterns")
            path_value = tool_call.arguments.get("path")
            if isinstance(patterns, list):
                message.tool_call.file_glob.patterns.extend([value for value in patterns if isinstance(value, str)])
            if isinstance(path_value, str):
                message.tool_call.file_glob.path = path_value
            continue
        if tool_call.tool_name == FILE_GLOB_V2_TOOL_NAME:
            patterns = tool_call.arguments.get("patterns")
            search_dir = tool_call.arguments.get("search_dir")
            max_matches = tool_call.arguments.get("max_matches")
            max_depth = tool_call.arguments.get("max_depth")
            min_depth = tool_call.arguments.get("min_depth")
            if isinstance(patterns, list):
                message.tool_call.file_glob_v2.patterns.extend([value for value in patterns if isinstance(value, str)])
            if isinstance(search_dir, str):
                message.tool_call.file_glob_v2.search_dir = search_dir
            if isinstance(max_matches, int):
                message.tool_call.file_glob_v2.max_matches = max_matches
            if isinstance(max_depth, int):
                message.tool_call.file_glob_v2.max_depth = max_depth
            if isinstance(min_depth, int):
                message.tool_call.file_glob_v2.min_depth = min_depth
            continue
        if tool_call.tool_name == APPLY_FILE_DIFFS_TOOL_NAME:
            summary = tool_call.arguments.get("summary")
            diffs = tool_call.arguments.get("diffs")
            new_files = tool_call.arguments.get("new_files")
            if isinstance(summary, str):
                message.tool_call.apply_file_diffs.summary = summary
            if isinstance(diffs, list):
                for diff_payload in diffs:
                    if not isinstance(diff_payload, dict):
                        continue
                    diff = message.tool_call.apply_file_diffs.diffs.add()
                    file_path = diff_payload.get("file_path")
                    search = diff_payload.get("search")
                    replace = diff_payload.get("replace")
                    if isinstance(file_path, str):
                        diff.file_path = file_path
                    if isinstance(search, str):
                        diff.search = search
                    if isinstance(replace, str):
                        diff.replace = replace
            if isinstance(new_files, list):
                for new_file_payload in new_files:
                    if not isinstance(new_file_payload, dict):
                        continue
                    new_file = message.tool_call.apply_file_diffs.new_files.add()
                    file_path = new_file_payload.get("file_path")
                    content = new_file_payload.get("content")
                    if isinstance(file_path, str):
                        new_file.file_path = file_path
                    if isinstance(content, str):
                        new_file.content = content
            continue
        if tool_call.tool_name == SUGGEST_PLAN_TOOL_NAME:
            summary = tool_call.arguments.get("summary")
            if isinstance(summary, str):
                message.tool_call.suggest_plan.summary = summary
            continue
        if tool_call.tool_name == SUGGEST_CREATE_PLAN_TOOL_NAME:
            message.tool_call.suggest_create_plan.SetInParent()
            continue
        if tool_call.tool_name == READ_MCP_RESOURCE_TOOL_NAME:
            uri = tool_call.arguments.get("uri")
            if isinstance(uri, str):
                message.tool_call.read_mcp_resource.uri = uri
            continue
        if tool_call.tool_name == CALL_MCP_TOOL_NAME:
            name = tool_call.arguments.get("name")
            args = tool_call.arguments.get("args")
            if isinstance(name, str):
                message.tool_call.call_mcp_tool.name = name
            if isinstance(args, dict):
                ParseDict(args, message.tool_call.call_mcp_tool.args)
            continue
        if tool_call.tool_name == WRITE_TO_LONG_RUNNING_SHELL_COMMAND_TOOL_NAME:
            input_value = tool_call.arguments.get("input")
            if isinstance(input_value, str):
                message.tool_call.write_to_long_running_shell_command.input = base64.b64decode(input_value)
            continue
        if tool_call.tool_name == SUGGEST_NEW_CONVERSATION_TOOL_NAME:
            message_id_value = tool_call.arguments.get("message_id")
            if isinstance(message_id_value, str):
                message.tool_call.suggest_new_conversation.message_id = message_id_value

    return event


def parse_json_list_output(raw_output: str) -> list[object] | None:
    try:
        payload = json.loads(raw_output)
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, list) else None


def is_mcp_tool_name(tool_name: str) -> bool:
    return tool_name in {READ_MCP_RESOURCE_TOOL_NAME, CALL_MCP_TOOL_NAME}


def is_remote_execution_context(local_request: LocalAIRequest) -> bool:
    platform_name = (local_request.os_platform or "").strip().lower()
    if platform_name not in {"", os.name.lower(), sys.platform.lower(), "windows"}:
        return True
    cwd_value = local_request.cwd or ""
    if cwd_value.startswith("/"):
        return True
    return False


def should_delegate_tool_call_to_client(local_request: LocalAIRequest, tool_call: ShellToolCall) -> bool:
    if tool_call.tool_name not in CLIENT_EXECUTED_TOOL_NAMES:
        return False
    return is_remote_execution_context(local_request)


def build_mcp_display_shell_command(tool_call: ShellToolCall) -> str:
    server_name_value = tool_call.arguments.get("server_name")
    server_name = server_name_value if isinstance(server_name_value, str) and server_name_value != "" else "mcp"

    if tool_call.tool_name == READ_MCP_RESOURCE_TOOL_NAME:
        uri = tool_call.arguments.get("uri")
        uri_text = uri if isinstance(uri, str) and uri != "" else "<unknown-resource>"
        return f"mcp read {server_name} {uri_text}"

    tool_name_value = tool_call.arguments.get("name")
    tool_name_text = tool_name_value if isinstance(tool_name_value, str) and tool_name_value != "" else "<unknown-tool>"
    args_value = tool_call.arguments.get("args")
    if isinstance(args_value, dict) and args_value:
        return f"mcp call {server_name} {tool_name_text} {json.dumps(args_value, ensure_ascii=False)}"
    return f"mcp call {server_name} {tool_name_text}"


def is_synthetic_mcp_display_command(command: str | None) -> bool:
    return isinstance(command, str) and command.startswith("mcp ")


def render_mcp_resource_output_for_display(raw_output: str) -> str:
    parsed_results = parse_json_list_output(raw_output)
    if parsed_results is None:
        return raw_output

    rendered_chunks: list[str] = []
    for item in parsed_results:
        if not isinstance(item, dict):
            continue
        uri = item.get("uri")
        text_payload = item.get("text")
        binary_payload = item.get("binary")
        if isinstance(uri, str) and uri != "":
            rendered_chunks.append(f"uri: {uri}")
        if isinstance(text_payload, dict):
            text_content = text_payload.get("content")
            if isinstance(text_content, str) and text_content != "":
                rendered_chunks.append(text_content)
        elif isinstance(binary_payload, dict):
            mime_type = binary_payload.get("mime_type")
            encoded_data = binary_payload.get("data")
            byte_count = 0
            if isinstance(encoded_data, str):
                try:
                    byte_count = len(base64.b64decode(encoded_data))
                except Exception:
                    byte_count = 0
            if isinstance(mime_type, str) and mime_type != "":
                rendered_chunks.append(f"[binary resource: {mime_type}, {byte_count} bytes]")
            else:
                rendered_chunks.append(f"[binary resource: {byte_count} bytes]")

    return "\n\n".join(chunk for chunk in rendered_chunks if chunk != "") or raw_output


def render_mcp_tool_output_for_display(raw_output: str) -> str:
    parsed_results = parse_json_list_output(raw_output)
    if parsed_results is None:
        return raw_output

    rendered_chunks: list[str] = []
    for item in parsed_results:
        if not isinstance(item, dict):
            continue
        text_value = item.get("text")
        resource_value = item.get("resource")
        image_value = item.get("image")
        if isinstance(text_value, str) and text_value != "":
            rendered_chunks.append(text_value)
            continue
        if isinstance(resource_value, dict):
            rendered_chunks.append(render_mcp_resource_output_for_display(json.dumps([resource_value], ensure_ascii=False)))
            continue
        if isinstance(image_value, dict):
            mime_type = image_value.get("mime_type")
            encoded_data = image_value.get("data")
            byte_count = 0
            if isinstance(encoded_data, str):
                try:
                    byte_count = len(base64.b64decode(encoded_data))
                except Exception:
                    byte_count = 0
            if isinstance(mime_type, str) and mime_type != "":
                rendered_chunks.append(f"[image output: {mime_type}, {byte_count} bytes]")
            else:
                rendered_chunks.append(f"[image output: {byte_count} bytes]")

    return "\n\n".join(chunk for chunk in rendered_chunks if chunk != "") or raw_output


def build_display_shell_result_for_mcp(tool_call: ShellToolCall, tool_result: ShellToolResult) -> ShellToolResult:
    output = (
        render_mcp_resource_output_for_display(tool_result.output)
        if tool_result.tool_name == READ_MCP_RESOURCE_TOOL_NAME
        else render_mcp_tool_output_for_display(tool_result.output)
    )
    exit_code = 1 if tool_result.output.startswith("MCP execution failed") else 0
    return ShellToolResult(
        tool_call_id=tool_call.tool_call_id,
        tool_name=SHELL_TOOL_NAME,
        command=build_mcp_display_shell_command(tool_call),
        output=output,
        exit_code=exit_code,
    )


def describe_mcp_tool_call(tool_call: ShellToolCall) -> str:
    server_name_value = tool_call.arguments.get("server_name")
    server_name = server_name_value if isinstance(server_name_value, str) and server_name_value != "" else "mcp"
    if tool_call.tool_name == READ_MCP_RESOURCE_TOOL_NAME:
        uri = tool_call.arguments.get("uri")
        uri_text = uri if isinstance(uri, str) and uri != "" else "<unknown-resource>"
        return f"{server_name} {uri_text}"
    tool_name_value = tool_call.arguments.get("name")
    tool_name_text = tool_name_value if isinstance(tool_name_value, str) and tool_name_value != "" else "<unknown-tool>"
    return f"{server_name} {tool_name_text}"


def build_mcp_progress_text(tool_call: ShellToolCall) -> str:
    return f"[MCP] Running {describe_mcp_tool_call(tool_call)}"


def wrap_text_in_code_block(text: str) -> str:
    fence = "```"
    if "```" in text:
        fence = "````"
    return f"{fence}text\n{text}\n{fence}"


def build_mcp_result_text(tool_call: ShellToolCall, tool_result: ShellToolResult) -> str:
    rendered_output = (
        render_mcp_resource_output_for_display(tool_result.output)
        if tool_result.tool_name == READ_MCP_RESOURCE_TOOL_NAME
        else render_mcp_tool_output_for_display(tool_result.output)
    ).strip()
    if rendered_output == "":
        return f"[MCP] Completed {describe_mcp_tool_call(tool_call)}"
    compact_output = truncate_text(rendered_output, limit=1600)
    return (
        f"[MCP] Completed {describe_mcp_tool_call(tool_call)}\n"
        f"{wrap_text_in_code_block(compact_output)}"
    )


def build_add_mcp_display_interactions_event(
    task_id: str,
    interactions: tuple[tuple[ShellToolCall, ShellToolResult], ...],
) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    action = event.client_actions.actions.add()
    action.add_messages_to_task.task_id = task_id

    for tool_call, tool_result in interactions:
        display_result = build_display_shell_result_for_mcp(tool_call, tool_result)

        call_message = action.add_messages_to_task.messages.add()
        call_message.id = str(uuid.uuid4())
        call_message.task_id = task_id
        call_message.tool_call.tool_call_id = tool_call.tool_call_id
        call_message.tool_call.run_shell_command.command = display_result.command or ""
        call_message.tool_call.run_shell_command.is_read_only = True
        call_message.tool_call.run_shell_command.uses_pager = False
        call_message.tool_call.run_shell_command.is_risky = False

        result_message = action.add_messages_to_task.messages.add()
        result_message.id = str(uuid.uuid4())
        result_message.task_id = task_id
        result_message.tool_call_result.tool_call_id = tool_call.tool_call_id
        result_message.tool_call_result.run_shell_command.command = display_result.command or ""
        result_message.tool_call_result.run_shell_command.command_finished.output = display_result.output
        result_message.tool_call_result.run_shell_command.command_finished.exit_code = display_result.exit_code or 0

    return event


def build_add_tool_results_event(
    task_id: str,
    tool_results: tuple[ShellToolResult, ...],
    request_id: str,
    created_at: datetime,
) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    action = event.client_actions.actions.add()
    action.add_messages_to_task.task_id = task_id

    for tool_result in tool_results:
        message = action.add_messages_to_task.messages.add()
        message.id = str(uuid.uuid4())
        message.task_id = task_id
        set_message_metadata(message, request_id, created_at)
        result_message = message.tool_call_result
        result_message.tool_call_id = tool_result.tool_call_id

        if tool_result.tool_name == SHELL_TOOL_NAME:
            if tool_result.command is not None:
                result_message.run_shell_command.command = tool_result.command
            result_message.run_shell_command.command_finished.output = tool_result.output
            if tool_result.exit_code is not None:
                result_message.run_shell_command.command_finished.exit_code = tool_result.exit_code
            continue

        if tool_result.tool_name == READ_MCP_RESOURCE_TOOL_NAME:
            parsed_results = parse_json_list_output(tool_result.output)
            if parsed_results is None:
                result_message.read_mcp_resource.error.message = tool_result.output
                continue
            for item in parsed_results:
                if not isinstance(item, dict):
                    continue
                content = result_message.read_mcp_resource.success.contents.add()
                uri = item.get("uri")
                if isinstance(uri, str):
                    content.uri = uri
                text_payload = item.get("text")
                if isinstance(text_payload, dict):
                    text_content = text_payload.get("content")
                    mime_type = text_payload.get("mime_type")
                    if isinstance(text_content, str):
                        content.text.content = text_content
                    if isinstance(mime_type, str):
                        content.text.mime_type = mime_type
                binary_payload = item.get("binary")
                if isinstance(binary_payload, dict):
                    encoded_data = binary_payload.get("data")
                    mime_type = binary_payload.get("mime_type")
                    if isinstance(encoded_data, str):
                        content.binary.data = base64.b64decode(encoded_data)
                    if isinstance(mime_type, str):
                        content.binary.mime_type = mime_type
            continue

        if tool_result.tool_name == CALL_MCP_TOOL_NAME:
            parsed_results = parse_json_list_output(tool_result.output)
            if parsed_results is None:
                result_message.call_mcp_tool.error.message = tool_result.output
                continue
            for item in parsed_results:
                if not isinstance(item, dict):
                    continue
                result_item = result_message.call_mcp_tool.success.results.add()
                text_value = item.get("text")
                if isinstance(text_value, str):
                    result_item.text.text = text_value
                    continue
                image_payload = item.get("image")
                if isinstance(image_payload, dict):
                    encoded_data = image_payload.get("data")
                    mime_type = image_payload.get("mime_type")
                    if isinstance(encoded_data, str):
                        result_item.image.data = base64.b64decode(encoded_data)
                    if isinstance(mime_type, str):
                        result_item.image.mime_type = mime_type
                    continue
                resource_payload = item.get("resource")
                if isinstance(resource_payload, dict):
                    uri = resource_payload.get("uri")
                    if isinstance(uri, str):
                        result_item.resource.uri = uri
                    text_payload = resource_payload.get("text")
                    if isinstance(text_payload, dict):
                        text_content = text_payload.get("content")
                        mime_type = text_payload.get("mime_type")
                        if isinstance(text_content, str):
                            result_item.resource.text.content = text_content
                        if isinstance(mime_type, str):
                            result_item.resource.text.mime_type = mime_type
                    binary_payload = resource_payload.get("binary")
                    if isinstance(binary_payload, dict):
                        encoded_data = binary_payload.get("data")
                        mime_type = binary_payload.get("mime_type")
                        if isinstance(encoded_data, str):
                            result_item.resource.binary.data = base64.b64decode(encoded_data)
                        if isinstance(mime_type, str):
                            result_item.resource.binary.mime_type = mime_type
            continue

        result_message.server.serialized_result = tool_result.output

    return event


def build_in_progress_event(task_id: str) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    action = event.client_actions.actions.add()
    action.update_task_status.task_id = task_id
    action.update_task_status.task_status.in_progress.SetInParent()
    return event


def should_execute_tool_calls_in_parallel(tool_calls: tuple[ShellToolCall, ...]) -> bool:
    if len(tool_calls) < 2:
        return False
    for tool_call in tool_calls:
        if tool_call.tool_name == SHELL_TOOL_NAME:
            if (not tool_call.is_read_only) or tool_call.uses_pager or tool_call.is_risky:
                return False
            continue
        if tool_call.tool_name in {
            READ_FILES_TOOL_NAME,
            SEARCH_CODEBASE_TOOL_NAME,
            GREP_TOOL_NAME,
            FILE_GLOB_TOOL_NAME,
            FILE_GLOB_V2_TOOL_NAME,
            READ_MCP_RESOURCE_TOOL_NAME,
            CALL_MCP_TOOL_NAME,
        }:
            continue
        return False
    return True


def build_succeeded_event(task_id: str) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    action = event.client_actions.actions.add()
    action.update_task_status.task_id = task_id
    action.update_task_status.task_status.succeeded.SetInParent()
    return event


def build_failed_event(task_id: str) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    action = event.client_actions.actions.add()
    action.update_task_status.task_id = task_id
    action.update_task_status.task_status.failed.SetInParent()
    return event


def build_finished_done_event() -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    event.finished.done.SetInParent()
    return event


def build_finished_error_event(message: str) -> response_pb2.ResponseEvent:
    event = response_pb2.ResponseEvent()
    event.finished.internal_error.message = message
    return event


def is_user_config_service_error(message: str) -> bool:
    return any(
        pattern in message
        for pattern in (
            "OpenAI-compatible endpoint failed",
            "Anthropic endpoint failed",
            "Google endpoint failed",
            "API key is not configured",
        )
    )


def build_user_visible_error_text(message: str) -> str:
    concise_message = truncate_text(message, limit=1600)
    return f"Custom provider error:\n```text\n{concise_message}\n```"


async def handle_local_multi_agent(request: web.Request, body: bytes) -> web.StreamResponse:
    config = await refresh_runtime_provider_settings(request.app)
    session = cast(ClientSession, request.app["client_session"])
    conversation_states = cast(dict[str, ConversationState], request.app["conversation_states"])
    mcp_registry = cast(dict[str, MCPRemoteServer], request.app["mcp_registry"])
    request_id = str(uuid.uuid4())
    stream_initialized = False
    task_state_pushed = False
    user_message_pushed = False

    response = web.StreamResponse(
        status=200,
        headers={"Content-Type": "text/event-stream; charset=utf-8"},
    )
    await response.prepare(request)

    try:
        local_request = parse_local_ai_request(body)
        conversation_id = local_request.conversation_id or str(uuid.uuid4())
        task_id = local_request.task_id or str(uuid.uuid4())
        state_key = build_conversation_state_key(conversation_id, task_id)
        conversation_state = get_or_create_conversation_state(
            conversation_states,
            state_key,
            local_request,
            config,
            mcp_registry,
        )
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "local_multi_agent_request",
                "request_id": request_id,
                "model_id": local_request.model_id,
                "user_text": local_request.user_text,
                "cwd": local_request.cwd,
                "shell_name": local_request.shell_name,
                "os_platform": local_request.os_platform,
                "is_remote_context": is_remote_execution_context(local_request),
                "username": local_request.username,
                "conversation_id": local_request.conversation_id,
                "task_id": local_request.task_id,
                "has_user_input": local_request.has_user_input,
                "is_resume_conversation": local_request.is_resume_conversation,
                "tool_result_count": len(local_request.pending_tool_results),
                "web_context_retrieval_enabled": local_request.raw_request.settings.web_context_retrieval_enabled,
            },
        )

        if local_request.user_text.strip() == "" and not local_request.has_user_input:
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "local_multi_agent_result",
                    "request_id": request_id,
                    "text": "",
                    "reasoning": None,
                    "noop": True,
                },
            )
            await response.write(sse_chunk_from_event(build_stream_init_event(conversation_id, request_id)))
            stream_initialized = True
            await response.write(sse_chunk_from_event(build_finished_done_event()))
            await response.write_eof()
            return response

        await response.write(sse_chunk_from_event(build_stream_init_event(conversation_id, request_id)))
        stream_initialized = True
        if local_request.task_id is None:
            await response.write(sse_chunk_from_event(build_create_task_event(task_id)))
        else:
            await response.write(sse_chunk_from_event(build_in_progress_event(task_id)))
        task_state_pushed = True
        if local_request.user_text.strip() != "":
            await response.write(
                sse_chunk_from_event(
                    build_add_user_message_event(
                        task_id,
                        str(uuid.uuid4()),
                        local_request.user_text,
                        request_id,
                        datetime.now(UTC),
                    )
                )
            )
            user_message_pushed = True

        request_metadata = build_provider_selection_metadata(config, local_request)
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "local_multi_agent_provider_selection",
                "request_id": request_id,
                **request_metadata,
            },
        )

        async def stream_model_result(local_result: LocalAIResult) -> None:
            if local_result.text != "" or local_result.reasoning:
                await response.write(
                    sse_chunk_from_event(
                        build_add_message_event(
                            task_id,
                            str(uuid.uuid4()),
                            local_result.text,
                            local_result.reasoning,
                            request_id,
                            datetime.now(UTC),
                        )
                    )
                )
            displayable_tool_calls = tuple(
                tool_call for tool_call in local_result.tool_calls if not is_mcp_tool_name(tool_call.tool_name)
            )
            if displayable_tool_calls:
                await response.write(
                    sse_chunk_from_event(
                        build_add_tool_calls_event(
                            task_id,
                            displayable_tool_calls,
                            request_id,
                            datetime.now(UTC),
                        )
                    )
                )
            for tool_call in local_result.tool_calls:
                if is_mcp_tool_name(tool_call.tool_name):
                    await response.write(
                        sse_chunk_from_event(
                            build_add_message_event(
                                task_id,
                                str(uuid.uuid4()),
                                build_mcp_progress_text(tool_call),
                                None,
                                request_id,
                                datetime.now(UTC),
                            )
                        )
                    )

        async def stream_tool_results(
            tool_calls: tuple[ShellToolCall, ...],
            tool_results: tuple[ShellToolResult, ...],
        ) -> None:
            non_mcp_results: list[ShellToolResult] = []
            mcp_interactions: list[tuple[ShellToolCall, ShellToolResult]] = []
            for tool_call, tool_result in zip(tool_calls, tool_results, strict=True):
                if is_mcp_tool_name(tool_call.tool_name):
                    mcp_interactions.append((tool_call, tool_result))
                else:
                    non_mcp_results.append(tool_result)

            if mcp_interactions:
                for tool_call, tool_result in mcp_interactions:
                    await response.write(
                        sse_chunk_from_event(
                            build_add_message_event(
                                task_id,
                                str(uuid.uuid4()),
                                build_mcp_result_text(tool_call, tool_result),
                                None,
                                request_id,
                                datetime.now(UTC),
                            )
                        )
                    )
            if non_mcp_results:
                await response.write(
                    sse_chunk_from_event(
                        build_add_tool_results_event(
                            task_id,
                            tuple(non_mcp_results),
                            request_id,
                            datetime.now(UTC),
                        )
                    )
                )

        local_result, _request_metadata = await run_local_ai_request(
            session,
            config,
            local_request,
            conversation_state,
            mcp_registry,
            on_model_result=stream_model_result,
            on_tool_results=stream_tool_results,
        )
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "local_multi_agent_result",
                "request_id": request_id,
                "text": truncate_text(local_result.text, limit=4000),
                "reasoning": truncate_text(local_result.reasoning, limit=2000) if local_result.reasoning else None,
                "tool_calls": [
                    {
                        "tool_call_id": tool_call.tool_call_id,
                        "tool_name": tool_call.tool_name,
                        "command": truncate_text(tool_call.command, limit=500) if tool_call.command else None,
                        "arguments": truncate_text(json.dumps(tool_call.arguments, ensure_ascii=False), limit=1000),
                    }
                    for tool_call in local_result.tool_calls
                ],
            },
        )
        if not local_result.tool_calls:
            await response.write(sse_chunk_from_event(build_succeeded_event(task_id)))
        await response.write(sse_chunk_from_event(build_finished_done_event()))
    except Exception as error:  # noqa: BLE001
        conversation_id = locals().get("conversation_id", str(uuid.uuid4()))
        task_id = locals().get("task_id", str(uuid.uuid4()))
        local_request = locals().get("local_request")
        error_message = str(error)
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "local_multi_agent_error",
                "request_id": request_id,
                "error": error_message,
                "error_type": type(error).__name__,
                "traceback": traceback.format_exc(limit=20),
            },
        )
        if not stream_initialized:
            await response.write(sse_chunk_from_event(build_stream_init_event(conversation_id, request_id)))
            stream_initialized = True
        if not task_state_pushed:
            await response.write(sse_chunk_from_event(build_create_task_event(task_id)))
            task_state_pushed = True
        if (
            not user_message_pushed
            and isinstance(local_request, LocalAIRequest)
            and local_request.user_text.strip() != ""
        ):
            await response.write(
                sse_chunk_from_event(
                    build_add_user_message_event(
                        task_id,
                        str(uuid.uuid4()),
                        local_request.user_text,
                        request_id,
                        datetime.now(UTC),
                    )
                )
            )
            user_message_pushed = True
        if is_user_config_service_error(error_message):
            await response.write(
                sse_chunk_from_event(
                    build_add_message_event(
                        task_id,
                        str(uuid.uuid4()),
                        build_user_visible_error_text(error_message),
                        None,
                        request_id,
                        datetime.now(UTC),
                    )
                )
            )
            await response.write(sse_chunk_from_event(build_failed_event(task_id)))
            await response.write(sse_chunk_from_event(build_finished_done_event()))
        else:
            await response.write(sse_chunk_from_event(build_finished_error_event(error_message)))

    await response.write_eof()
    return response


async def handle_local_passive_suggestions(request: web.Request, body: bytes) -> web.StreamResponse:
    config = cast(ShimConfig, request.app["config"])
    request_id = str(uuid.uuid4())
    conversation_id = str(uuid.uuid4())

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "local_passive_suggestions_request",
            "request_id": request_id,
            "byte_count": len(body),
        },
    )

    response = web.StreamResponse(
        status=200,
        headers={"Content-Type": "text/event-stream; charset=utf-8"},
    )
    await response.prepare(request)
    await response.write(sse_chunk_from_event(build_stream_init_event(conversation_id, request_id)))
    await response.write(sse_chunk_from_event(build_finished_done_event()))
    await response.write_eof()
    return response


def is_websocket_request(request: web.Request) -> bool:
    upgrade_value = request.headers.get("Upgrade", "")
    connection_value = request.headers.get("Connection", "")
    return upgrade_value.lower() == "websocket" or "upgrade" in connection_value.lower()


def truncate_text(value: str, *, limit: int = 2000) -> str:
    if len(value) <= limit:
        return value
    return f"{value[:limit]}...<truncated>"


def safe_decode(body: bytes) -> str | None:
    if body == b"":
        return None
    try:
        return body.decode("utf-8")
    except UnicodeDecodeError:
        return None


def normalize_graphql_key(key: str) -> str:
    return re.sub(r"[^a-z0-9]", "", key.lower())


def rewrite_graphql_response_payload(payload: object) -> int:
    if isinstance(payload, list):
        return sum(rewrite_graphql_response_payload(item) for item in payload)

    if not isinstance(payload, dict):
        return 0

    changed_count = 0

    for key, value in list(payload.items()):
        normalized_key = normalize_graphql_key(key)
        should_force_true = normalized_key in GRAPHQL_TRUE_OVERRIDE_KEYS or any(
            partial in normalized_key for partial in GRAPHQL_TRUE_OVERRIDE_KEY_PARTIALS
        )
        should_force_false = normalized_key in GRAPHQL_FALSE_OVERRIDE_KEYS or any(
            partial in normalized_key for partial in GRAPHQL_FALSE_OVERRIDE_KEY_PARTIALS
        )

        if should_force_true and isinstance(value, bool) and value is not True:
            payload[key] = True
            value = True
            changed_count += 1
        elif should_force_false and isinstance(value, bool) and value is not False:
            payload[key] = False
            value = False
            changed_count += 1
        elif normalized_key in GRAPHQL_FORCE_TRUE_SCALAR_KEYS and isinstance(value, bool) and value is not True:
            payload[key] = True
            value = True
            changed_count += 1
        elif normalized_key == "isunlimited" and isinstance(value, bool) and value is not True:
            payload[key] = True
            value = True
            changed_count += 1
        elif normalized_key in GRAPHQL_FORCE_STRING_VALUES and (
            value is None or (isinstance(value, str) and value != GRAPHQL_FORCE_STRING_VALUES[normalized_key])
        ):
            payload[key] = GRAPHQL_FORCE_STRING_VALUES[normalized_key]
            value = payload[key]
            changed_count += 1
        elif normalized_key == "disablereason" and value is not None:
            payload[key] = None
            value = None
            changed_count += 1
        elif normalized_key in GRAPHQL_FORCE_TRUE_NUMERIC_KEYS and isinstance(value, int) and value < 1_000_000:
            payload[key] = 1_000_000
            value = payload[key]
            changed_count += 1
        elif normalized_key in GRAPHQL_FORCE_ZERO_NUMERIC_KEYS and isinstance(value, int) and value != 0:
            payload[key] = 0
            value = 0
            changed_count += 1
        elif normalized_key == "hostconfigs":
            if isinstance(value, dict):
                model_routing_host = value.get("modelRoutingHost")
                if model_routing_host == "AWS_BEDROCK":
                    value["modelRoutingHost"] = "DIRECT_API"
                    changed_count += 1
                if value.get("enabled") is not True:
                    value["enabled"] = True
                    changed_count += 1
            elif isinstance(value, list):
                direct_api_items = [
                    item
                    for item in value
                    if isinstance(item, dict) and item.get("modelRoutingHost") == "DIRECT_API"
                ]
                if direct_api_items:
                    filtered_items = [
                        item
                        for item in value
                        if not (
                            isinstance(item, dict)
                            and item.get("modelRoutingHost") == "AWS_BEDROCK"
                        )
                    ]
                    if len(filtered_items) != len(value):
                        payload[key] = filtered_items
                        value = filtered_items
                        changed_count += 1
                for item in value:
                    if not isinstance(item, dict):
                        continue
                    if item.get("modelRoutingHost") == "AWS_BEDROCK":
                        item["modelRoutingHost"] = "DIRECT_API"
                        changed_count += 1
                    if item.get("enabled") is not True:
                        item["enabled"] = True
                        changed_count += 1
        elif normalized_key == "modelroutinghost" and value == "AWS_BEDROCK":
            payload[key] = "DIRECT_API"
            value = "DIRECT_API"
            changed_count += 1

        changed_count += rewrite_graphql_response_payload(value)

    return changed_count


def maybe_rewrite_graphql_response_body(
    graphql_op: str | None,
    body: bytes,
) -> tuple[bytes, int]:
    if graphql_op not in GRAPHQL_RESPONSE_REWRITE_OPS or body == b"":
        return body, 0

    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return body, 0

    changed_count = rewrite_graphql_response_payload(payload)
    if changed_count == 0:
        return body, 0

    return json.dumps(payload, ensure_ascii=False).encode("utf-8"), changed_count


async def refresh_runtime_provider_settings(app: web.Application) -> ShimConfig:
    current_config = cast(ShimConfig, app["config"])
    launch_arguments = cast(argparse.Namespace | None, app.get("launch_arguments"))
    if launch_arguments is None:
        return current_config

    refreshed_config = await asyncio.to_thread(load_config, launch_arguments)
    merged_config = merge_runtime_provider_config(current_config, refreshed_config)
    app["config"] = merged_config
    return merged_config


def build_token_proxy_cache_key(request: web.Request, body: bytes) -> str:
    hasher = hashlib.sha256()
    hasher.update(request.path_qs.encode("utf-8"))
    hasher.update(b"\0")
    hasher.update(body)
    return hasher.hexdigest()


def build_buffered_response_headers(headers: LooseHeaders) -> dict[str, str]:
    response_headers = build_response_headers(headers)
    response_headers.pop("Content-Length", None)
    response_headers.pop("Content-Encoding", None)
    response_headers.pop("Transfer-Encoding", None)
    return response_headers


def prune_token_proxy_cache(cache: dict[str, TokenProxyCacheEntry]) -> None:
    current_monotonic = asyncio.get_running_loop().time()
    expired_keys = [
        cache_key
        for cache_key, cache_entry in cache.items()
        if cache_entry.expires_at_monotonic <= current_monotonic
    ]
    for cache_key in expired_keys:
        cache.pop(cache_key, None)


def compute_token_proxy_cache_expiry(body: bytes) -> float:
    ttl_seconds = TOKEN_PROXY_FALLBACK_TTL_SECONDS
    try:
        payload = json.loads(body)
    except Exception:
        payload = None

    if isinstance(payload, dict):
        expires_in_value = payload.get("expires_in")
        if isinstance(expires_in_value, str) and expires_in_value.isdigit():
            ttl_seconds = max(60.0, float(int(expires_in_value) - 60))
        elif isinstance(expires_in_value, int):
            ttl_seconds = max(60.0, float(expires_in_value - 60))

    return asyncio.get_running_loop().time() + ttl_seconds


def build_cached_token_proxy_response(cache_entry: TokenProxyCacheEntry) -> web.Response:
    return web.Response(
        status=cache_entry.status,
        headers=dict(cache_entry.headers),
        body=cache_entry.body,
    )


def decode_jwt_payload_without_verification(token: str) -> dict[str, object]:
    parts = token.split(".")
    if len(parts) < 2:
        return {}
    payload_part = parts[1]
    padding = "=" * (-len(payload_part) % 4)
    try:
        decoded = base64.urlsafe_b64decode(payload_part + padding)
        parsed = json.loads(decoded)
    except Exception:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def build_securetoken_fallback_entry() -> TokenProxyCacheEntry | None:
    user_settings = load_warp_user_settings()
    nested_token = user_settings.get("id_token")
    if not isinstance(nested_token, dict):
        return None

    id_token = nested_token.get("id_token")
    refresh_token = nested_token.get("refresh_token")
    if not isinstance(id_token, str) or not isinstance(refresh_token, str):
        return None

    jwt_payload = decode_jwt_payload_without_verification(id_token)
    project_id = None
    if isinstance(jwt_payload.get("aud"), str):
        project_id = jwt_payload.get("aud")
    elif isinstance(jwt_payload.get("iss"), str):
        issuer = str(jwt_payload.get("iss"))
        project_id = issuer.rsplit("/", 1)[-1]

    user_id = user_settings.get("local_id")
    response_payload: dict[str, object] = {
        "id_token": id_token,
        "access_token": id_token,
        "refresh_token": refresh_token,
        "token_type": "Bearer",
        "expires_in": "3600",
    }
    if isinstance(user_id, str) and user_id != "":
        response_payload["user_id"] = user_id
    if isinstance(project_id, str) and project_id != "":
        response_payload["project_id"] = project_id

    response_body = json.dumps(response_payload, ensure_ascii=False).encode("utf-8")
    response_headers = {"Content-Type": "application/json; charset=UTF-8"}
    expires_at_monotonic = asyncio.get_running_loop().time() + TOKEN_PROXY_FALLBACK_TTL_SECONDS

    return TokenProxyCacheEntry(
        status=200,
        headers=response_headers,
        body=response_body,
        expires_at_monotonic=expires_at_monotonic,
    )


def parse_websocket_protocols(header_value: str | None) -> list[str]:
    if header_value is None:
        return []
    protocols: list[str] = []
    for item in header_value.split(","):
        protocol = item.strip()
        if protocol != "":
            protocols.append(protocol)
    return protocols


async def handle_token_proxy_request(
    request: web.Request,
    config: ShimConfig,
    session: ClientSession,
    request_id: str,
    body: bytes,
) -> web.Response:
    token_proxy_cache = cast(dict[str, TokenProxyCacheEntry], request.app["token_proxy_cache"])
    token_proxy_lock = cast(asyncio.Lock, request.app["token_proxy_lock"])
    cache_key = build_token_proxy_cache_key(request, body)

    async with token_proxy_lock:
        prune_token_proxy_cache(token_proxy_cache)
        cached_entry = token_proxy_cache.get(cache_key)
        if cached_entry is not None:
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "token_proxy_cache_hit",
                    "request_id": request_id,
                },
            )
            return build_cached_token_proxy_response(cached_entry)

        upstream_url = request_url(config.upstream_http_base, request.path_qs)
        headers = build_request_headers(request.headers)

        async with session.request(
            method=request.method,
            url=upstream_url,
            headers=headers,
            data=body if body != b"" else None,
            allow_redirects=False,
        ) as upstream_response:
            await log_http_response(config, request_id, upstream_response.status, upstream_response.headers)
            response_body = await upstream_response.read()
            response_headers = build_buffered_response_headers(upstream_response.headers)
            content_type = str(upstream_response.headers.get("Content-Type", "")).lower()

            if upstream_response.status == 200 and "application/json" in content_type and response_body != b"":
                cache_entry = TokenProxyCacheEntry(
                    status=upstream_response.status,
                    headers=response_headers,
                    body=response_body,
                    expires_at_monotonic=compute_token_proxy_cache_expiry(response_body),
                )
                token_proxy_cache[cache_key] = cache_entry
                await append_log(
                    config,
                    {
                        "timestamp": datetime.now(UTC).isoformat(),
                        "kind": "token_proxy_cache_store",
                        "request_id": request_id,
                    },
                )
                return build_cached_token_proxy_response(cache_entry)

            fallback_entry = token_proxy_cache.get(cache_key)
            fallback_source = "memory_cache"
            if fallback_entry is None and upstream_response.status in {400, 401, 403, 429, 500, 502, 503}:
                fallback_entry = build_securetoken_fallback_entry()
                if fallback_entry is not None:
                    token_proxy_cache[cache_key] = fallback_entry
                    fallback_source = "keychain_user"
            if fallback_entry is not None and upstream_response.status in {400, 401, 403, 429, 500, 502, 503}:
                await append_log(
                    config,
                    {
                        "timestamp": datetime.now(UTC).isoformat(),
                        "kind": "token_proxy_cache_fallback",
                        "request_id": request_id,
                        "upstream_status": upstream_response.status,
                        "fallback_source": fallback_source,
                    },
                )
                return build_cached_token_proxy_response(fallback_entry)

            return web.Response(
                status=upstream_response.status,
                headers=response_headers,
                body=response_body,
            )


async def append_log(config: ShimConfig, payload: dict[str, object]) -> None:
    config.log_path.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(payload, ensure_ascii=False)

    def write_line() -> None:
        with config.log_path.open("a", encoding="utf-8") as file_handle:
            file_handle.write(f"{line}\n")

    await asyncio.to_thread(write_line)


async def write_capture_bytes(path: Path, data: bytes) -> None:
    def write_bytes() -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("wb") as file_handle:
            file_handle.write(data)

    await asyncio.to_thread(write_bytes)


async def log_http_request(
    config: ShimConfig,
    request_id: str,
    request: web.Request,
    body: bytes,
) -> None:
    query_map = {key: values for key, values in parse_qs(request.query_string, keep_blank_values=True).items()}
    body_text = safe_decode(body)
    graphql_op = request.query.get("op")

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "http_request",
            "request_id": request_id,
            "method": request.method,
            "path_qs": request.path_qs,
            "graphql_op": graphql_op,
            "query": query_map,
            "headers": {
                key: ("<redacted>" if key.lower() == "authorization" else value)
                for key, value in request.headers.items()
            },
            "body_text": truncate_text(body_text) if body_text is not None else None,
            "interesting_graphql_op": graphql_op in INTERESTING_GRAPHQL_OPS if graphql_op is not None else False,
        },
    )


async def log_http_response(
    config: ShimConfig,
    request_id: str,
    status: int,
    headers: LooseHeaders,
) -> None:
    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "http_response",
            "request_id": request_id,
            "status": status,
            "headers": dict(headers),
        },
    )


async def maybe_capture_ai_request_body(
    config: ShimConfig,
    request_id: str,
    path_qs: str,
    body: bytes,
) -> None:
    if not is_ai_stream_path(path_qs):
        return

    if body == b"":
        return

    capture_path = config.capture_dir / f"{request_id}.request.bin"
    meta_path = config.capture_dir / f"{request_id}.request.json"

    await write_capture_bytes(capture_path, body)
    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "capture_request_body",
            "request_id": request_id,
            "path_qs": path_qs,
            "byte_count": len(body),
            "capture_path": str(capture_path),
            "meta_path": str(meta_path),
        },
    )

    await asyncio.to_thread(
        meta_path.write_text,
        json.dumps(
            {
                "request_id": request_id,
                "path_qs": path_qs,
                "byte_count": len(body),
                "timestamp": datetime.now(UTC).isoformat(),
            },
            ensure_ascii=False,
            indent=2,
        ),
        "utf-8",
    )


async def maybe_capture_graphql_debug_payload(
    config: ShimConfig,
    request_id: str,
    graphql_op: str | None,
    *,
    suffix: str,
    body: bytes,
) -> None:
    if graphql_op not in GRAPHQL_DEBUG_CAPTURE_OPS or body == b"":
        return

    capture_path = config.capture_dir / f"{request_id}.{graphql_op}.{suffix}.json"
    await write_capture_bytes(capture_path, body)


async def health_handler(request: web.Request) -> web.Response:
    config = await refresh_runtime_provider_settings(request.app)
    mcp_registry = cast(dict[str, MCPRemoteServer], request.app["mcp_registry"])
    response_payload = {
        "ok": True,
        "listen_host": config.listen_host,
        "listen_port": config.listen_port,
        "upstream_http_base": config.upstream_http_base,
        "upstream_ws_base": config.upstream_ws_base,
        "log_path": str(config.log_path),
        "capture_dir": str(config.capture_dir),
        "providers": {
            "openai": config.openai.base_url if config.openai is not None else None,
            "anthropic": config.anthropic.base_url if config.anthropic is not None else None,
            "google": config.google.base_url if config.google is not None else None,
        },
        "mcp_servers": {
            name: {
                "url": server.server_url,
                "session_id_present": server.session_id is not None,
                "tool_count": len(server.tools),
                "resource_count": len(server.resources),
                "initialization_error": server.initialization_error,
            }
            for name, server in mcp_registry.items()
        },
    }
    return web.json_response(response_payload)


async def proxy_http(request: web.Request) -> web.StreamResponse:
    config = cast(ShimConfig, request.app["config"])
    session = cast(ClientSession, request.app["client_session"])
    request_id = str(uuid.uuid4())
    body = await request.read()
    graphql_op = request.query.get("op")

    await log_http_request(config, request_id, request, body)
    await maybe_capture_ai_request_body(config, request_id, request.path_qs, body)
    await maybe_capture_graphql_debug_payload(
        config,
        request_id,
        graphql_op,
        suffix="request",
        body=body,
    )

    if request.path == "/ai/multi-agent":
        return await handle_local_multi_agent(request, body)

    if request.path == "/ai/passive-suggestions":
        return await handle_local_passive_suggestions(request, body)

    if is_ai_stream_path(request.path):
        return await proxy_http_with_curl(
            request=request,
            config=config,
            request_id=request_id,
            body=body,
        )

    if request.path == "/proxy/token":
        return await handle_token_proxy_request(
            request=request,
            config=config,
            session=session,
            request_id=request_id,
            body=body,
        )

    upstream_url = request_url(config.upstream_http_base, request.path_qs)
    headers = build_request_headers(request.headers)

    async with session.request(
        method=request.method,
        url=upstream_url,
        headers=headers,
        data=body if body != b"" else None,
        allow_redirects=False,
    ) as upstream_response:
        await log_http_response(config, request_id, upstream_response.status, upstream_response.headers)

        upstream_content_type = str(upstream_response.headers.get("Content-Type", "")).lower()
        if graphql_op in GRAPHQL_RESPONSE_REWRITE_OPS and "application/json" in upstream_content_type:
            upstream_body = await upstream_response.read()
            response_body, rewritten_field_count = maybe_rewrite_graphql_response_body(graphql_op, upstream_body)
            await maybe_capture_graphql_debug_payload(
                config,
                request_id,
                graphql_op,
                suffix="response",
                body=response_body,
            )
            response_headers = build_response_headers(upstream_response.headers)
            response_headers.pop("Content-Length", None)
            response_headers.pop("Content-Encoding", None)
            response_headers.pop("Transfer-Encoding", None)

            if rewritten_field_count > 0:
                await append_log(
                    config,
                    {
                        "timestamp": datetime.now(UTC).isoformat(),
                        "kind": "graphql_response_rewrite",
                        "request_id": request_id,
                        "graphql_op": graphql_op,
                        "rewritten_field_count": rewritten_field_count,
                    },
                )

            return web.Response(
                status=upstream_response.status,
                headers=response_headers,
                body=response_body,
            )

        response = web.StreamResponse(
            status=upstream_response.status,
            headers=build_response_headers(upstream_response.headers),
        )
        await response.prepare(request)

        async for chunk in upstream_response.content.iter_chunked(64 * 1024):
            await response.write(chunk)

        await response.write_eof()
        return response


async def read_curl_headers(
    stdout_reader: asyncio.StreamReader,
) -> tuple[int, dict[str, str], bytes]:
    status_code = 502
    headers: dict[str, str] = {}

    while True:
        line = await stdout_reader.readline()
        if line == b"":
            return status_code, headers, b""

        if line in {b"\r\n", b"\n"}:
            break

        stripped_line = line.decode("utf-8", errors="replace").strip()
        if stripped_line.startswith("HTTP/"):
            parts = stripped_line.split()
            if len(parts) >= 2 and parts[1].isdigit():
                status_code = int(parts[1])
                headers = {}
            continue

        if ":" not in stripped_line:
            continue

        key, value = stripped_line.split(":", 1)
        if key.lower() in HOP_BY_HOP_HEADERS:
            continue
        headers[key.strip()] = value.strip()

    first_body_chunk = await stdout_reader.read(64 * 1024)
    return status_code, headers, first_body_chunk


async def proxy_http_with_curl(
    request: web.Request,
    config: ShimConfig,
    request_id: str,
    body: bytes,
) -> web.StreamResponse:
    if shutil.which("curl") is None:
        raise RuntimeError("curl is required for AI stream proxying.")

    upstream_url = request_url(config.upstream_ai_base, request.path_qs)
    forwarded_headers = build_request_headers(request.headers)
    session = cast(ClientSession, request.app["client_session"])
    cookies = session.cookie_jar.filter_cookies(URL(upstream_url))
    cookie_header = cookies.output(header="", sep=";").strip()
    if cookie_header != "":
        forwarded_headers["Cookie"] = cookie_header

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "ai_forward_headers",
            "request_id": request_id,
            "path_qs": request.path_qs,
            "upstream_url": upstream_url,
            "headers": {
                key: ("<redacted>" if key.lower() in {"authorization", "cookie"} else value)
                for key, value in forwarded_headers.items()
            },
            "has_cookie_header": "Cookie" in forwarded_headers,
        },
    )

    command = [
        "curl",
        "--silent",
        "--show-error",
        "--no-buffer",
        "--dump-header",
        "-",
        "--output",
        "-",
        "--request",
        request.method,
        "--url",
        upstream_url,
        "--noproxy",
        "*",
    ]

    for key, value in forwarded_headers.items():
        command.extend(["--header", f"{key}: {value}"])

    if body != b"":
        command.extend(["--data-binary", "@-"])

    env = {
        key: value
        for key, value in os.environ.items()
        if key.upper() not in {"HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY"}
    }

    process = await asyncio.create_subprocess_exec(
        *command,
        stdin=asyncio.subprocess.PIPE if body != b"" else None,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=env,
    )

    if body != b"" and process.stdin is not None:
        process.stdin.write(body)
        await process.stdin.drain()
        process.stdin.close()

    if process.stdout is None or process.stderr is None:
        raise RuntimeError("curl subprocess pipes were not created.")

    status, response_headers, first_body_chunk = await read_curl_headers(process.stdout)
    await log_http_response(config, request_id, status, response_headers)

    response = web.StreamResponse(
        status=status,
        headers=response_headers,
    )
    await response.prepare(request)

    if first_body_chunk != b"":
        await response.write(first_body_chunk)

    while True:
        chunk = await process.stdout.read(64 * 1024)
        if chunk == b"":
            break
        await response.write(chunk)

    stderr_output = (await process.stderr.read()).decode("utf-8", errors="replace").strip()
    return_code = await process.wait()

    if stderr_output != "":
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "curl_stderr",
                "request_id": request_id,
                "return_code": return_code,
                "stderr": truncate_text(stderr_output),
                "path_qs": request.path_qs,
            },
        )

    await response.write_eof()
    return response


async def pump_client_to_upstream(
    client_ws: web.WebSocketResponse,
    upstream_ws: object,
) -> None:
    async for message in client_ws:
        if message.type == WSMsgType.TEXT:
            await cast(object, upstream_ws).send_str(message.data)
        elif message.type == WSMsgType.BINARY:
            await cast(object, upstream_ws).send_bytes(message.data)
        elif message.type == WSMsgType.PING:
            await cast(object, upstream_ws).ping()
        elif message.type == WSMsgType.PONG:
            await cast(object, upstream_ws).pong()
        elif message.type in {WSMsgType.CLOSE, WSMsgType.CLOSED, WSMsgType.CLOSING}:
            await cast(object, upstream_ws).close()
            break
        elif message.type == WSMsgType.ERROR:
            break


async def pump_upstream_to_client(
    client_ws: web.WebSocketResponse,
    upstream_ws: object,
) -> None:
    async for message in cast(object, upstream_ws):
        if message.type == WSMsgType.TEXT:
            await client_ws.send_str(message.data)
        elif message.type == WSMsgType.BINARY:
            await client_ws.send_bytes(message.data)
        elif message.type == WSMsgType.PING:
            await client_ws.ping()
        elif message.type == WSMsgType.PONG:
            await client_ws.pong()
        elif message.type in {WSMsgType.CLOSE, WSMsgType.CLOSED, WSMsgType.CLOSING}:
            await client_ws.close()
            break
        elif message.type == WSMsgType.ERROR:
            break


async def proxy_websocket(request: web.Request) -> web.StreamResponse:
    config = cast(ShimConfig, request.app["config"])
    session = cast(ClientSession, request.app["client_session"])
    request_id = str(uuid.uuid4())
    requested_protocols = parse_websocket_protocols(request.headers.get("Sec-WebSocket-Protocol"))

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "websocket_request",
            "request_id": request_id,
            "path_qs": request.path_qs,
            "headers": dict(request.headers),
        },
    )

    client_ws = web.WebSocketResponse(protocols=tuple(requested_protocols))
    await client_ws.prepare(request)

    upstream_url = request_url(config.upstream_ws_base, request.path_qs)
    headers = build_websocket_upstream_headers(request.headers)
    cookies = session.cookie_jar.filter_cookies(URL(upstream_url))
    cookie_header = cookies.output(header="", sep=";").strip()
    if cookie_header != "":
        headers["Cookie"] = cookie_header

    await append_log(
        config,
        {
            "timestamp": datetime.now(UTC).isoformat(),
            "kind": "websocket_connecting",
            "request_id": request_id,
            "upstream_url": upstream_url,
            "requested_protocols": requested_protocols,
            "has_cookie_header": "Cookie" in headers,
        },
    )

    try:
        async with session.ws_connect(
            upstream_url,
            headers=headers,
            protocols=tuple(requested_protocols),
        ) as upstream_ws:
            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "websocket_connected",
                    "request_id": request_id,
                    "requested_protocols": requested_protocols,
                    "negotiated_client_protocol": client_ws.ws_protocol,
                    "negotiated_upstream_protocol": upstream_ws.protocol,
                },
            )

            forward_tasks = {
                asyncio.create_task(pump_client_to_upstream(client_ws, upstream_ws)),
                asyncio.create_task(pump_upstream_to_client(client_ws, upstream_ws)),
            }
            done, pending = await asyncio.wait(forward_tasks, return_when=asyncio.FIRST_COMPLETED)

            for task in pending:
                task.cancel()
            await asyncio.gather(*pending, return_exceptions=True)

            task_errors: list[str] = []
            for task in done:
                exception = task.exception()
                if exception is None:
                    continue
                if isinstance(exception, (ConnectionError, asyncio.CancelledError, RuntimeError)):
                    task_errors.append(str(exception))
                    continue
                raise exception

            await append_log(
                config,
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "kind": "websocket_closed",
                    "request_id": request_id,
                    "task_errors": task_errors,
                },
            )
    except Exception as error:
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "websocket_error",
                "request_id": request_id,
                "error": format_exception_message(error),
                "error_type": type(error).__name__,
            },
        )
        await client_ws.close()
        return client_ws

    await client_ws.close()
    return client_ws


async def proxy_handler(request: web.Request) -> web.StreamResponse:
    if request.path == "/__warp_shim/health":
        return await health_handler(request)

    try:
        if is_websocket_request(request):
            return await proxy_websocket(request)

        return await proxy_http(request)
    except Exception as error:  # noqa: BLE001
        config = cast(ShimConfig, request.app["config"])
        await append_log(
            config,
            {
                "timestamp": datetime.now(UTC).isoformat(),
                "kind": "unhandled_exception",
                "path_qs": request.path_qs,
                "error": str(error),
                "traceback": traceback.format_exc(limit=20),
            },
        )
        return web.Response(status=500, text="Internal Server Error")


async def on_startup(app: web.Application) -> None:
    timeout = ClientTimeout(total=None, connect=30)
    session = ClientSession(timeout=timeout)
    app["client_session"] = session
    config = cast(ShimConfig, app["config"])
    app["mcp_registry"] = await build_mcp_registry(session, config)


async def on_cleanup(app: web.Application) -> None:
    session = cast(ClientSession | None, app.get("client_session"))
    if session is not None:
        await session.close()


def create_app(config: ShimConfig, launch_arguments: argparse.Namespace) -> web.Application:
    app = web.Application(client_max_size=50 * 1024 * 1024)
    app["config"] = config
    app["launch_arguments"] = launch_arguments
    app["conversation_states"] = {}
    app["mcp_registry"] = {}
    app["token_proxy_cache"] = {}
    app["token_proxy_lock"] = asyncio.Lock()
    app.router.add_route("*", "/__warp_shim/health", health_handler)
    app.router.add_route("*", "/{tail:.*}", proxy_handler)
    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)
    return app


def install_signal_handlers() -> None:
    def handle_signal(signum: int, _frame: object) -> None:
        raise KeyboardInterrupt(f"Received signal {signum}")

    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, handle_signal)


def main() -> int:
    parser = build_parser()
    arguments = parser.parse_args()
    config = load_config(arguments)

    install_signal_handlers()
    app = create_app(config, arguments)

    print(
        f"Warp shim listening on http://{config.listen_host}:{config.listen_port} "
        f"-> {config.upstream_http_base}"
    )
    print(f"Traffic log: {config.log_path}")

    web.run_app(
        app,
        host=config.listen_host,
        port=config.listen_port,
        handle_signals=False,
        access_log=None,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
