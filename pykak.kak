decl str pk_interpreter python3

decl -hidden str pk_source %val{source}

def pk_init %{
    eval %sh{
        set -e
        trap 'rm -rf "$pk_dir"' EXIT
        pk_dir="$(mktemp -d -t pykak_XXXXXX)"
        mkfifo "$pk_dir/kak2py_a.fifo"
        mkfifo "$pk_dir/kak2py_b.fifo"
        mkfifo "$pk_dir/py2kak.fifo"
        pykak_py="$(dirname $kak_opt_pk_source)/pykak.py"
        "$kak_opt_pk_interpreter" "$pykak_py" "$pk_dir"
        echo "
            decl -hidden str pk_dir \"$pk_dir\"
            def -hidden -override pk_read_1 %{
                try %{
                    eval %file{$pk_dir/py2kak.fifo}
                    try pk_done catch %{
                        pk_write a
                    }
                } catch %{
                    pk_write \"e%val{error}\"
                }
            }
        "
        trap - EXIT
    }
    hook -group pykak global KakEnd .* %{ nop %sh{
        kill $kak_opt_pk_pid
        rm -rf "$kak_opt_pk_dir"
    }}
}

def -hidden pk_autoinit %{
    try %{
        nop %opt{pk_pid}
    } catch %{
        pk_init
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
