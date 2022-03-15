declare-option str pykak_interpreter python3

declare-option -hidden str pykak_source %val{source}

define-command pykak-init %{
    evaluate-commands %sh{
        pykak_dir=$(mktemp -d -t pykak-XXXXXX)
        kak2pya="$pykak_dir/kak2pya.fifo"
        kak2pyb="$pykak_dir/kak2pyb.fifo"
        py2kaka="$pykak_dir/py2kaka.fifo"
        py2kakb="$pykak_dir/py2kakb.fifo"
        mkfifo "$kak2pya"
        mkfifo "$kak2pyb"
        mkfifo "$py2kaka"
        mkfifo "$py2kakb"
        file="$(dirname $kak_opt_pykak_source)/pykak.py"
        "$kak_opt_pykak_interpreter" "$file" \
            "$kak2pya" "$kak2pyb" "$py2kaka" "$py2kakb" \
            > /dev/null 2>&1 </dev/null &
        pykak_pid=$!
        echo "
            declare-option -hidden str pykak_dir \"$pykak_dir\"
            declare-option -hidden str kak2pya \"$kak2pya\"
            declare-option -hidden str kak2pyb \"$kak2pyb\"
            declare-option -hidden str py2kaka \"$py2kaka\"
            declare-option -hidden str py2kakb \"$py2kakb\"
            declare-option -hidden str pykak_pid \"$pykak_pid\"
            define-command -hidden pykak-response-a %{
                evaluate-commands %file{$py2kaka}
            }
            define-command -hidden pykak-response-b %{
                evaluate-commands %file{$py2kakb}
            }
        "
    }
    declare-option -hidden bool py2kak_state true
    define-command pykak-response -hidden %{
        declare-option -hidden str response_cmd
        alias window "pykak_%opt{py2kak_state}" nop
        try %{
            pykak_true
            unalias window pykak_true
            set-option global py2kak_state false
            set-option global response_cmd pykak-response-a
        } catch %{
            unalias window pykak_false
            set-option global py2kak_state true
            set-option global response_cmd pykak-response-b
        }
        evaluate-commands %opt{response_cmd}
    }
    hook -group pykak global KakEnd .* %{ nop %sh{
        kill $kak_opt_pykak_pid
        rm -rf "$kak_opt_pykak_dir"
    }}
}

define-command pykak-autoinit %{
    try %{
        nop %opt{pykak_pid}
    } catch %{
        pykak-init
    }
}

define-command pykak-request-a -hidden -params 1 %{
    echo -to-file %opt{kak2pya} %arg{1}
}
define-command pykak-request-b -hidden -params 1 %{
    echo -to-file %opt{kak2pyb} %arg{1}
}
declare-option -hidden bool kak2py_state true
define-command pykak-request -hidden -params 1 %{
    alias window "pykak_%opt{kak2py_state}" nop
    declare-option -hidden str request_cmd
    try %{
        pykak_true
        unalias window pykak_true
        set-option global kak2py_state false
        set-option global request_cmd pykak-request-a
    } catch %{
        unalias window pykak_false
        set-option global kak2py_state true
        set-option global request_cmd pykak-request-b
    }
    evaluate-commands %{
        %opt{request_cmd} %arg{1}
    }
}

define-command pykak-response8 %{
    pykak-response; pykak-response;
    pykak-response; pykak-response;
    pykak-response; pykak-response;
    pykak-response; pykak-response;
}
define-command pykak-response64 %{
    pykak-response8; pykak-response8;
    pykak-response8; pykak-response8;
    pykak-response8; pykak-response8;
    pykak-response8; pykak-response8;
}
define-command pykak-response512 %{
    pykak-response64; pykak-response64;
    pykak-response64; pykak-response64;
    pykak-response64; pykak-response64;
    pykak-response64; pykak-response64;
}
define-command pykak-response4096 %{
    pykak-response512; pykak-response512;
    pykak-response512; pykak-response512;
    pykak-response512; pykak-response512;
    pykak-response512; pykak-response512;
}
define-command pykak-response32768 %{
    pykak-response4096; pykak-response4096;
    pykak-response4096; pykak-response4096;
    pykak-response4096; pykak-response4096;
    pykak-response4096; pykak-response4096;
}
define-command pykak-response262114 %{
    pykak-response32768; pykak-response32768;
    pykak-response32768; pykak-response32768;
    pykak-response32768; pykak-response32768;
    pykak-response32768; pykak-response32768;
}
define-command pykak-response-inf %{
    pykak-response
    pykak-response8
    pykak-response64
    pykak-response512
    pykak-response4096
    pykak-response32768
    pykak-response262114
    pykak-response-inf
}

define-command python -params 1 %{
    pykak-autoinit
    pykak-request %arg{1}
    try %{
        pykak-response-inf
    }
}
alias global py python
