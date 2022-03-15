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
            def -hidden pk_response_a %{
                eval %file{$py2kaka}
            }
            def -hidden pk_response_b %{
                eval %file{$py2kakb}
            }
        "
    }
    decl -hidden bool py2kak_state true
    def pk_response -hidden %{
        decl -hidden str pk_response_cmd
        alias window "pk_%opt{py2kak_state}" nop
        try %{
            pk_true
            unalias window pk_true
            set global py2kak_state false
            set global pk_response_cmd pk_response_a
        } catch %{
            unalias window pk_false
            set global py2kak_state true
            set global pk_response_cmd pk_response_b
        }
        eval %opt{pk_response_cmd}
    }
    hook -group pykak global KakEnd .* %{ nop %sh{
        kill $kak_opt_pk_pid
        rm -rf "$kak_opt_pk_dir"
    }}
}

def pk_autoinit %{
    try %{
        nop %opt{pk_pid}
    } catch %{
        pk_init
    }
}

def pk_request_a -hidden -params 1 %{
    echo -to-file %opt{kak2pya} %arg{1}
}
def pk_request_b -hidden -params 1 %{
    echo -to-file %opt{kak2pyb} %arg{1}
}
decl -hidden bool kak2py_state true
def pk_request -hidden -params 1 %{
    alias window "pk_%opt{kak2py_state}" nop
    decl -hidden str request_cmd
    try %{
        pk_true
        unalias window pk_true
        set global kak2py_state false
        set global request_cmd pk_request_a
    } catch %{
        unalias window pk_false
        set global kak2py_state true
        set global request_cmd pk_request_b
    }
    eval %{
        %opt{request_cmd} %arg{1}
    }
}

def pk_response8 %{
    pk_response; pk_response;
    pk_response; pk_response;
    pk_response; pk_response;
    pk_response; pk_response;
}
def pk_response64 %{
    pk_response8; pk_response8;
    pk_response8; pk_response8;
    pk_response8; pk_response8;
    pk_response8; pk_response8;
}
def pk_response512 %{
    pk_response64; pk_response64;
    pk_response64; pk_response64;
    pk_response64; pk_response64;
    pk_response64; pk_response64;
}
def pk_response4096 %{
    pk_response512; pk_response512;
    pk_response512; pk_response512;
    pk_response512; pk_response512;
    pk_response512; pk_response512;
}
def pk_response32768 %{
    pk_response4096; pk_response4096;
    pk_response4096; pk_response4096;
    pk_response4096; pk_response4096;
    pk_response4096; pk_response4096;
}
def pk_response262114 %{
    pk_response32768; pk_response32768;
    pk_response32768; pk_response32768;
    pk_response32768; pk_response32768;
    pk_response32768; pk_response32768;
}
def pk_response_inf %{
    pk_response
    pk_response8
    pk_response64
    pk_response512
    pk_response4096
    pk_response32768
    pk_response262114
    pk_response_inf
}

def python -params 1 %{
    pk_autoinit
    pk_request %arg{1}
    try %{
        pk_response_inf
    }
}
alias global py python
