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
