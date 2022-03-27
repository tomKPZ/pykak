# The code for `send_cmd`, `_encode_length`, and `get_socket_path` is obtained
# from kakoune-smooth-scroll.
# https://github.com/caksoylar/kakoune-smooth-scroll
#
# The LICENSE file for kakoune-smooth-scroll is inlined below.

# MIT License
#
# Copyright (c) 2021 Cem Aksoylar
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
#     The above copyright notice and this permission notice shall be included
#     in all copies or substantial portions of the Software.
#
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
#     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
#     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import sys
import os
import socket


def init(session):
    global socket_path
    socket_path = _get_socket_path(session)


def send_cmd(cmd: str) -> bool:
    """
    Send a command string to the Kakoune session. Sent data is a
    concatenation of:
       - Header
         - Magic byte indicating type is "command" (\x02)
         - Length of whole message in uint32
       - Content
         - Length of command string in uint32
         - Command string
    Return whether the communication was successful.
    """
    b_cmd = cmd.encode('utf-8')
    sock = socket.socket(socket.AF_UNIX)
    sock.connect(socket_path)
    b_content = _encode_length(len(b_cmd)) + b_cmd
    b_header = b'\x02' + _encode_length(len(b_content) + 5)
    b_message = b_header + b_content
    return sock.send(b_message) == len(b_message)


def _encode_length(str_length: int) -> bytes:
    return str_length.to_bytes(4, byteorder=sys.byteorder)


def _get_socket_path(session: str) -> str:
    xdg_runtime_dir = os.environ.get('XDG_RUNTIME_DIR')
    if xdg_runtime_dir is None:
        tmpdir = os.environ.get('TMPDIR', '/tmp')
        session_path = os.path.join(
            tmpdir, 'kakoune-' + os.environ['USER'], session
        )
        if not os.path.exists(session_path):  # pre-Kakoune db9ef82
            session_path = os.path.join(
                tmpdir, 'kakoune', os.environ['USER'], session
            )
    else:
        session_path = os.path.join(xdg_runtime_dir, 'kakoune', session)
    return session_path
