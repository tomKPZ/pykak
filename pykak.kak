declare-option -hidden str pykak_source %val{source}

define-command pykak-init %{
    evaluate-commands %sh{
        tmp_dir=$(mktemp -d -t pykak-XXXXXX)
        kak2pya="$tmp_dir/kak2pya.fifo"
        kak2pyb="$tmp_dir/kak2pyb.fifo"
        py2kaka="$tmp_dir/py2kaka.fifo"
        py2kakb="$tmp_dir/py2kakb.fifo"
        mkfifo "$kak2pya"
        mkfifo "$kak2pyb"
        mkfifo "$py2kaka"
        mkfifo "$py2kakb"
        file="$(dirname $kak_opt_pykak_source)/pykak.py"
        python3 "$file" "$kak2pya" "$kak2pyb" "$py2kaka" "$py2kakb" \
            > /dev/null 2>&1 </dev/null &
        pykak_pid=$!
        echo declare-option -hidden str kak2pya "$kak2pya"
        echo declare-option -hidden str kak2pyb "$kak2pyb"
        echo declare-option -hidden str py2kaka "$py2kaka"
        echo declare-option -hidden str py2kakb "$py2kakb"
        echo declare-option -hidden str pykak_pid "$pykak_pid"
        echo "define-command -hidden pykak-response-a %{"
        echo "    evaluate-commands %file{$py2kaka}"
        echo "}"
        echo "define-command -hidden pykak-response-b %{"
        echo "    evaluate-commands %file{$py2kakb}"
        echo "}"
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
    hook -group pykak global KakEnd .* %{
        kill $kak_pykak_pid
        nop %sh{rm -rf "$kak_tmp_dir"}
    }
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
