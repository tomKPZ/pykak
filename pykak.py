#! /usr/bin/env python3

import argparse
import itertools
import os
import re
import textwrap
import traceback

# TODO:
# * reentrancy
# * tests
# * cleanup temp dir
# * add main()
# * rename evalc?


class KakException(Exception):
    pass


def _raw_write(response):
    with open(_py2kak, 'w') as f:
        f.write(response)


def _write(response):
    _raw_write(response)
    replies = []
    while True:
        dtype, data = _read()
        if dtype == 'a':
            return replies
        elif dtype == 'd':
            replies.append(data)
        elif dtype == 'r':
            raise Exception('reentrancy not supported yet')
        elif dtype == 'e':
            # TODO: put replies into exception
            raise KakException(data)
        else:
            # Todo: add reply info in exception
            raise Exception('invalid reply type')


def _read():
    with open(next(_kak2py), 'r') as f:
        dtype = f.read(1)
        if dtype == "'":
            dtype = f.read(1)
            f.read(2)
            data = unquote(f.read())
        else:
            data = f.read()
    return (dtype, data)


def _getter(prefix, quoted):
    def getter_impl(name):
        return _write(('pk_write_quoted d %%%s{%s}' if quoted else
                       'pk_write "d%%%s{%s}"') % (prefix, name))[0]
    return getter_impl


def unquote(s):
    return (quoted[-1].replace("''", "'")
            for quoted in _quoted_pattern.findall(s))


def quote(iter):
    return ' '.join("'%s'" % x.replace("'", "''") for x in iter)


_parser = argparse.ArgumentParser('pykak server')
_parser.add_argument('pk_dir', type=str)
_cmd_args = _parser.parse_args()

_kak2py_a = os.path.join(_cmd_args.pk_dir, 'kak2py_a.fifo')
_kak2py_b = os.path.join(_cmd_args.pk_dir, 'kak2py_b.fifo')
_kak2py = itertools.cycle((_kak2py_a, _kak2py_b))
_py2kak = os.path.join(_cmd_args.pk_dir, 'py2kak.fifo')

_quoted_pattern = re.compile(r"(?s)('')|('(.+?)(?<!')'(?!'))")

opt = _getter('opt', False)
reg = _getter('reg', False)
val = _getter('val', False)
optq = _getter('opt', True)
regq = _getter('reg', True)
valq = _getter('val', True)
evalc = _write

while True:
    try:
        dtype, data = _read()
        if dtype == 'r':
            cmd = textwrap.dedent(next(data))
            args = list(data)
            exec(cmd)
        else:
            raise Exception('not a request')
    except Exception:
        exc = traceback.format_exc()
        # TODO: is this quoting sufficient?
        # TODO: coalesce commands.
        exc = exc.replace("'", "''")
        _write('echo -markup "{Error}{\\}pykak error: '
               'see *debug* buffer"')
        _write("echo -debug 'pykak error: %s'" % exc)
    _raw_write('alias global pk_done nop')
