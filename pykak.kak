decl str pk_interpreter python3

decl -hidden str pk_source %val{source}

def pk_init %{
    eval %sh{
        # variable export: kak_session
        set -e
        trap 'rm -rf "$pk_dir"' EXIT
        pk_dir="$(mktemp -d -t pykak_XXXXXX)"
        mkfifo "$pk_dir/kak2py_a.fifo"
        mkfifo "$pk_dir/kak2py_b.fifo"
        mkfifo "$pk_dir/py2kak.fifo"
        pykak_py="$(dirname $kak_opt_pk_source)/pykak.py"
        PYKAK_DIR="$pk_dir" "$kak_opt_pk_interpreter" "$pykak_py"
        trap - EXIT
    }
    hook -group pykak global KakEnd .* %{ python %{
        global _running
        _running = False
    }}
}

def -hidden pk_autoinit %{
    try %{
        nop %opt{pk_dir}
    } catch %{
        pk_init
    }
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

decl -hidden bool kak2py_state true
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
        echo -to-file "%opt{pk_dir}/kak2py_a.fifo" -quoting kakoune %arg{@}
    } catch %{
        unalias global pk_false
        set global kak2py_state true
        echo -to-file "%opt{pk_dir}/kak2py_b.fifo" -quoting kakoune %arg{@}
    }
}

def python -params 1.. %{
    pk_autoinit

    pk_write_quoted r %arg{@}

    pk_read_inf
    unalias global pk_done
}
alias global py python
