"""Process-only Qwen configuration for explicit local validation commands."""

from getpass import getpass
import os
import sys

from django.conf import settings
from django.core.management.base import CommandError

from workbench.ai import configured


def prompt_secret(prompt):
    if os.name != "nt":
        return getpass(prompt)

    # Windows getpass reads individual key events; Ctrl+V can arrive as a
    # control character instead of the pasted text. Console line input with
    # echo disabled keeps ordinary paste support without displaying the key.
    import ctypes
    import msvcrt
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GetConsoleMode.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    kernel32.GetConsoleMode.restype = wintypes.BOOL
    kernel32.SetConsoleMode.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel32.SetConsoleMode.restype = wintypes.BOOL
    handle = msvcrt.get_osfhandle(sys.stdin.fileno())
    previous = wintypes.DWORD()
    if not kernel32.GetConsoleMode(handle, ctypes.byref(previous)):
        raise CommandError("需要在交互式 Windows PowerShell 中输入 Key；没有发送请求。")
    line_input, echo_input = 0x0002, 0x0004
    if not kernel32.SetConsoleMode(handle, (previous.value | line_input) & ~echo_input):
        raise CommandError("无法关闭 Key 输入回显；没有发送请求。")
    try:
        return input(prompt)
    finally:
        kernel32.SetConsoleMode(handle, previous.value)
        # Enter is not echoed while echo mode is disabled.
        print()


def prompt_qwen_provider():
    base_url = input(
        "粘贴百炼页面左侧 OpenAI 图标下的‘按量付费 Base URL’（地址会显示；直接回车使用北京通用地址）："
    ).strip() or "https://dashscope.aliyuncs.com/compatible-mode/v1"
    settings.AI_ENABLED = True
    settings.AI_PROVIDER = "qwen"
    settings.AI_BASE_URL = base_url
    settings.AI_MODEL = "qwen-flash"
    settings.AI_API_KEY = "validation-placeholder"
    if not configured():
        raise CommandError("Base URL 不符合北京地域 OpenAI 兼容地址；请检查粘贴内容是否为左侧完整 URL。没有读取 Key 或发送请求。")
    key = prompt_secret("请输入百炼 API Key（输入不显示）：").strip()
    if not key or any(char.isspace() or ord(char) < 32 or ord(char) == 127 for char in key):
        raise CommandError("Key 为空或包含空白／控制字符；隐藏输入可能未正确接收粘贴。没有发送请求。")
    settings.AI_API_KEY = key
