#! /usr/bin/env python3

import argparse
import itertools
import os
import re
import sys
import textwrap
import traceback

# TODO:
# * tests
# * cleanup temp dir
# * more robust process starting
# * make a kak->py raw write available?
# * put args before code?
# * async work on socket


class KakException(Exception):
    pass


def _gen_read_cmd(cmd, cmds):
    print('def -hidden pk_read_%s %%{' % cmd)
    for i, cmd in enumerate(cmds):
        print('try %{' if i == 0 else '} catch %{')
        print('pk_read_' + cmd)
        if i != len(cmds) - 1:
            print('pk_done')
    print('} }')


def _gen_read_cmds():
    N = 9
    B = 4
    for i in range(1, N):
        _gen_read_cmd(str(B**i), [str(B**(i - 1)) for _ in range(B)])
    _gen_read_cmd('inf', [str(B**i) for i in range(N)] + ['inf'])


def _write(response):
    with open(_py2kak, 'w') as f:
        f.write(response)


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


def _process_request(request):
    global args
    old_args = args
    try:
        cmd = textwrap.dedent(next(request))
        args = list(request)
        exec(cmd)
    except Exception:
        exc = traceback.format_exc()
        # TODO: coalesce commands.
        keval('echo -markup "{Error}{\\}pykak error: '
              'see *debug* buffer"')
        keval("echo -debug 'pykak error:' %s" % quote(exc))
    finally:
        args = old_args
        _write('alias global pk_done nop')


def _getter(prefix, quoted):
    def getter_impl(name):
        return keval(('pk_write_quoted d %%%s{%s}' if quoted else
                      'pk_write "d%%%s{%s}"') % (prefix, name))[0]
    return getter_impl


def keval(response):
    _write(response)
    replies = []
    while True:
        dtype, data = _read()
        if dtype == 'a':
            return replies
        elif dtype == 'd':
            replies.append(data)
        elif dtype == 'r':
            _process_request(data)
        elif dtype == 'e':
            # TODO: put replies into exception
            raise KakException(data)
        else:
            # TODO: add reply info in exception
            raise Exception('invalid reply type')


def unquote(s):
    return (quoted[-1].replace("''", "'")
            for quoted in _quoted_pattern.findall(s))


def quote(v):
    def quote_impl(s):
        return "'%s'" % s.replace("'", "''")
    if type(v) == str:
        return quote_impl(v)
    return ' '.join(quote_impl(s) for s in iter)


def main():
    pid = os.fork()
    if pid:
        print('decl -hidden str pk_pid %d' % pid)
        _gen_read_cmds()
        return 0
    with open('/dev/null', 'w+') as f:
        for fd in range(3):
            os.dup2(f.fileno(), fd)

    while True:
        dtype, data = _read()
        assert dtype == 'r'
        _process_request(data)


_parser = argparse.ArgumentParser('pykak server')
_parser.add_argument('pk_dir', type=str)
_cmd_args = _parser.parse_args()

_kak2py_a = os.path.join(_cmd_args.pk_dir, 'kak2py_a.fifo')
_kak2py_b = os.path.join(_cmd_args.pk_dir, 'kak2py_b.fifo')
_kak2py = itertools.cycle((_kak2py_a, _kak2py_b))
_py2kak = os.path.join(_cmd_args.pk_dir, 'py2kak.fifo')

_quoted_pattern = re.compile(r"(?s)('')|('(.+?)(?<!')'(?!'))")

args = None
opt = _getter('opt', False)
reg = _getter('reg', False)
val = _getter('val', False)
optq = _getter('opt', True)
regq = _getter('reg', True)
valq = _getter('val', True)

if __name__ == '__main__':
    sys.exit(main())
