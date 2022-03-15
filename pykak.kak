decl str pk_interpreter python3

decl -hidden str pk_source %val{source}

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
            def -hidden pk_read_a %{
                eval %file{$py2kaka}
            }
            def -hidden pk_read_b %{
                eval %file{$py2kakb}
            }
        "
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
        eval %opt{pk_read_cmd}
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

def -hidden pk_read_8 %{
    pk_read; pk_read; pk_read; pk_read;
    pk_read; pk_read; pk_read; pk_read;
}
def -hidden pk_read_64 %{
    pk_read_8; pk_read_8; pk_read_8; pk_read_8;
    pk_read_8; pk_read_8; pk_read_8; pk_read_8;
}
def -hidden pk_read_512 %{
    pk_read_64; pk_read_64; pk_read_64; pk_read_64;
    pk_read_64; pk_read_64; pk_read_64; pk_read_64;
}
def -hidden pk_read_4096 %{
    pk_read_512; pk_read_512; pk_read_512; pk_read_512;
    pk_read_512; pk_read_512; pk_read_512; pk_read_512;
}
def -hidden pk_read_32768 %{
    pk_read_4096; pk_read_4096; pk_read_4096; pk_read_4096;
    pk_read_4096; pk_read_4096; pk_read_4096; pk_read_4096;
}
def -hidden pk_read_inf %{
    pk_read
    pk_read_8
    pk_read_64
    pk_read_512
    pk_read_4096
    pk_read_32768
    pk_read_inf
}

def python -params 1 %{
    pk_autoinit
    pk_write %arg{1}
    try %{
        pk_read_inf
    }
}
alias global py python
