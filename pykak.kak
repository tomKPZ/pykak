decl str pk_interpreter python3

decl -hidden str pk_source %val{source}
decl -hidden bool pk_running false

def pk_start -docstring "start pykak server" %{
    try %{
        alias global pk_init_false nop
        "pk_init_%opt{pk_running}"
        eval %sh{
            # variable export: kak_session
            set -e
            trap 'rm -rf "$pk_dir"' EXIT
            pk_dir="$(mktemp -d -t pykak_XXXXXX)"
            mkfifo "$pk_dir/kak2py_a.fifo"
            mkfifo "$pk_dir/kak2py_b.fifo"
            mkfifo "$pk_dir/py2kak.fifo"
            pykak_py="$(dirname $kak_opt_pk_source)/pykak.py"
            export PYKAK_DIR="$pk_dir"
            export KAK_PID="$PPID"
            "$kak_opt_pk_interpreter" "$pykak_py"
            trap - EXIT
        }
    }
    unalias global pk_init_false
}

def pk_stop -docstring "stop pykak server" %{
    try %{
        alias global pk_init_true nop
        "pk_init_%opt{pk_running}"
        pk_write f
        rmhooks global pykak
        set global pk_running false
    }
    unalias global pk_init_true
}

def pk_restart -docstring "restart pykak server" %{
    pk_stop
    pk_start
}

def -hidden -override pk_read_1 %{
    try %{
        pk_read_impl
        try pk_done catch %{
            pk_write a
        }
    } catch %{
        pk_write "e%val{error}"
    }
}

def pk_write -hidden -params 1 %{
    alias global "pk_%opt{kak2py_state}" nop
    try %{
        pk_true
        unalias global pk_true
        set global kak2py_state false
        echo -to-file "%opt{pk_dir}/kak2py_a.fifo" %arg{1}
    } catch %{
        unalias global pk_false
        set global kak2py_state true
        echo -to-file "%opt{pk_dir}/kak2py_b.fifo" %arg{1}
    }
}
def pk_write_quoted -hidden -params 1.. %{
    alias global "pk_%opt{kak2py_state}" nop
    try %{
        pk_true
        unalias global pk_true
        set global kak2py_state false
        echo -to-file "%opt{pk_dir}/kak2py_a.fifo" \
            -quoting kakoune %arg{@}
    } catch %{
        unalias global pk_false
        set global kak2py_state true
        echo -to-file "%opt{pk_dir}/kak2py_b.fifo" \
            -quoting kakoune %arg{@}
    }
}

def pk_send -params 1 -docstring "send data to python" %{
    echo -debug 'the arg is ' %arg{1}
    pk_write "d%arg{1}"
}

def pk_sendq -params 1.. -docstring "send quoted data to python" %{
    pk_write_quoted d %arg{@}
}

def python -docstring "run python code" -params 1.. %{
    pk_start

    pk_write_quoted r %arg{@}

    pk_read_inf
    unalias global pk_done
}
alias global py python
