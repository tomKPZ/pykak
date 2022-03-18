#! /usr/bin/env python3

import argparse
import itertools
import queue
import textwrap
import threading
import traceback


class KakException(Exception):
    pass


class DoneToken:
    pass


def _drain_read_queue():
    assert _io_lock.locked()
    data = []
    try:
        while True:
            data.append(_read_queue.get_nowait())
    except queue.Empty:
        pass
    return data


def _echo_error(message):
    message = message.replace('"', '""')
    return ('echo -markup "{Error}{\\}pykak error: '
            'see *debug* buffer"; ' +
            ('echo -debug "pykak error: %s"' % message))


def _format_write_data(data):
    if type(data) == DoneToken:
        data = ''
        unhandled = _drain_read_queue()
        if unhandled:
            message = 'unhandled messages: '
            message += '\n'.join(unhandled)
            data = _echo_error(message)
            data += '; '
        data += 'alias global pk_done nop'
    return data


def _write_inf():
    for fname in itertools.cycle([_args.py2kaka, _args.py2kakb]):
        data = _write_queue.get()
        with open(fname, 'w') as f:
            with _io_lock:
                f.write(_format_write_data(data))
                _write_queue.task_done()


def _read_inf():
    for fname in itertools.cycle([_args.kak2pya, _args.kak2pyb]):
        with open(fname, 'r') as f:
            # TODO: There's a race condition between the open above and
            # obtaining the lock below.
            with _io_lock:
                _read_queue.put(f.read())


def _read():
    data = _read_queue.get()
    if data.startswith(_ERROR_UUID):
        raise KakException(data.removeprefix(_ERROR_UUID))
    return data


def _write(response):
    _write_queue.put(response)


def _getter(prefix):
    def getter_impl(name):
        _write('pk_write "%%%s{%s}"' % (prefix, name))
        return _read()
    return getter_impl


_ERROR_UUID = 'f74c66de-3e90-4ee5-ae33-bf7e8e358cb0'

_parser = argparse.ArgumentParser('pykak server')
_parser.add_argument('kak2pya', type=str)
_parser.add_argument('kak2pyb', type=str)
_parser.add_argument('py2kaka', type=str)
_parser.add_argument('py2kakb', type=str)
_args = _parser.parse_args()

_write_queue = queue.Queue()
_read_queue = queue.Queue()

_io_lock = threading.Lock()

_write_thread = threading.Thread(target=_write_inf)
_write_thread.start()
_read_thread = threading.Thread(target=_read_inf)
_read_thread.start()

arg = _getter('arg')
opt = _getter('opt')
reg = _getter('reg')
val = _getter('val')

while True:
    try:
        try:
            data = _read()
        except:
            assert False
        exec(textwrap.dedent(data))
    except:
        exc = traceback.format_exc().replace('"', '""')
        _write(_echo_error(exc))
    _write(DoneToken())
    _write_queue.join()
