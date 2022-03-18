decl str pk_interpreter python3

decl -hidden str pk_source %val{source}

def pk_init %{
    eval %sh{
        pk_dir="$(mktemp -d -t pykak_XXXXXX)"
        mkfifo "$pk_dir/kak2py_a.fifo"
        mkfifo "$pk_dir/kak2py_b.fifo"
        mkfifo "$pk_dir/py2kak.fifo"
        file="$(dirname $kak_opt_pk_source)/pykak.py"
        "$kak_opt_pk_interpreter" "$file" "$pk_dir" \
            > /dev/null 2>&1 </dev/null &
        pk_pid=$!
        echo "
            decl -hidden str pk_dir \"$pk_dir\"
            decl -hidden str pk_pid \"$pk_pid\"
            def -hidden pk_read %{
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
    decl -hidden str write_cmd
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

def -hidden pk_read_1 %{
    try %{ pk_done } catch %{ pk_read }
}
def -hidden pk_read_4 %{
    try %{ pk_done } catch %{
        pk_read_1; pk_read_1; pk_read_1; pk_read_1;
    }
}
def -hidden pk_read_16 %{
    try %{ pk_done } catch %{
        pk_read_4; pk_read_4; pk_read_4; pk_read_4;
    }
}
def -hidden pk_read_64 %{
    try %{ pk_done } catch %{
        pk_read_16; pk_read_16; pk_read_16; pk_read_16;
    }
}
def -hidden pk_read_256 %{
    try %{ pk_done } catch %{
        pk_read_64; pk_read_64; pk_read_64; pk_read_64;
    }
}
def -hidden pk_read_1024 %{
    try %{ pk_done } catch %{
        pk_read_256; pk_read_256; pk_read_256; pk_read_256;
    }
}
def -hidden pk_read_4096 %{
    try %{ pk_done } catch %{
        pk_read_1024; pk_read_1024; pk_read_1024; pk_read_1024;
    }
}
def -hidden pk_read_16384 %{
    try %{ pk_done } catch %{
        pk_read_4096; pk_read_4096; pk_read_4096; pk_read_4096;
    }
}
def -hidden pk_read_65536 %{
    try %{ pk_done } catch %{
        pk_read_16384; pk_read_16384; pk_read_16384; pk_read_16384;
    }
}
def -hidden pk_read_inf %{
    try %{
        pk_read_1
        pk_done
    } catch %{
        pk_read_4
        pk_done
    } catch %{
        pk_read_16
        pk_done
    } catch %{
        pk_read_64
        pk_done
    } catch %{
        pk_read_256
        pk_done
    } catch %{
        pk_read_1024
        pk_done
    } catch %{
        pk_read_4096
        pk_done
    } catch %{
        pk_read_16384
        pk_done
    } catch %{
        pk_read_65536
        pk_done
    } catch %{
        pk_read_inf
        pk_done
    }
}

def python -params 1 %{
    pk_autoinit

    pk_write "r%arg{1}"

    pk_read_inf
    unalias global pk_done
}
alias global py python
