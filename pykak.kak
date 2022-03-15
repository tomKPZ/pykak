decl str pk_interpreter python3

decl -hidden str pk_source %val{source}
decl -hidden str error_uuid f74c66de-3e90-4ee5-ae33-bf7e8e358cb0

def pk_init %{
    eval %sh{
        pk_dir=$(mktemp -d -t pykak_XXXXXX)
        kak2pya="$pk_dir/kak2pya.fifo"
        kak2pyb="$pk_dir/kak2pyb.fifo"
        py2kaka="$pk_dir/py2kaka.fifo"
        py2kakb="$pk_dir/py2kakb.fifo"
        mkfifo "$kak2pya"
        mkfifo "$kak2pyb"
        mkfifo "$py2kaka"
        mkfifo "$py2kakb"
        file="$(dirname $kak_opt_pk_source)/pykak.py"
        "$kak_opt_pk_interpreter" "$file" \
            "$kak2pya" "$kak2pyb" "$py2kaka" "$py2kakb" \
            > /dev/null 2>&1 </dev/null &
        pk_pid=$!
        echo "
            decl -hidden str pk_dir \"$pk_dir\"
            decl -hidden str kak2pya \"$kak2pya\"
            decl -hidden str kak2pyb \"$kak2pyb\"
            decl -hidden str py2kaka \"$py2kaka\"
            decl -hidden str py2kakb \"$py2kakb\"
            decl -hidden str pk_pid \"$pk_pid\"
            def -hidden pk_read_a %{ eval %file{$py2kaka} }
            def -hidden pk_read_b %{ eval %file{$py2kakb} }
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

decl -hidden bool py2kak_state true
def -hidden pk_read %{
    decl -hidden str pk_read_cmd
    alias global "pk_%opt{py2kak_state}" nop
    try %{
        pk_true
        unalias global pk_true
        set global py2kak_state false
        set global pk_read_cmd pk_read_a
    } catch %{
        unalias global pk_false
        set global py2kak_state true
        set global pk_read_cmd pk_read_b
    }
    try %{
        eval %opt{pk_read_cmd}
    } catch %{
        pk_write "%opt{error_uuid}%val{error}"
    }
}

def pk_write_a -hidden -params 1 %{
    echo -to-file %opt{kak2pya} %arg{1}
}
def pk_write_b -hidden -params 1 %{
    echo -to-file %opt{kak2pyb} %arg{1}
}
decl -hidden bool kak2py_state true
def pk_write -hidden -params 1 %{
    alias global "pk_%opt{kak2py_state}" nop
    decl -hidden str write_cmd
    try %{
        pk_true
        unalias global pk_true
        set global kak2py_state false
        set global write_cmd pk_write_a
    } catch %{
        unalias global pk_false
        set global kak2py_state true
        set global write_cmd pk_write_b
    }
    eval %{
        %opt{write_cmd} %arg{1}
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

    pk_write %arg{1}

    pk_read_inf
    unalias global pk_done
}
alias global py python
