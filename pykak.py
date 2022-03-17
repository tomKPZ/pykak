#! /usr/bin/env python3

import argparse
import itertools
import queue
import textwrap
import threading
import traceback


class KakException(Exception):
    pass


def _write_inf():
    for fname in itertools.cycle([_args.py2kaka, _args.py2kakb]):
        with open(fname, 'w') as f:
            f.write(_write_queue.get())


def _read_inf():
    for fname in itertools.cycle([_args.kak2pya, _args.kak2pyb]):
        with open(fname, 'r') as f:
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
        exec(textwrap.dedent(_read()))
    except:
        exc = traceback.format_exc().replace('"', '""')
        _write('echo -markup "{Error}{\\}pykak error: '
               'see *debug* buffer"')
        _write('echo -debug "pykak error: %s"' % exc)
    _write('alias global pk_done nop')
