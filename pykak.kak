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
        file=/home/tom/dev/local/pykak/pykak.py
        python3 "$file" "$kak2pya" "$kak2pyb" "$py2kaka" "$py2kakb" \
            > /dev/null 2>&1 </dev/null &
        pykak_pid=$!
        echo declare-option -hidden str kak2pya "$kak2pya"
        echo declare-option -hidden str kak2pyb "$kak2pyb"
        echo declare-option -hidden str py2kaka "$py2kaka"
        echo declare-option -hidden str py2kakb "$py2kakb"
        echo declare-option -hidden str pykak_pid "$pykak_pid"
        echo "define-command -hidden pykak-response-a-impl %{"
        echo "    evaluate-commands %file{$py2kaka}"
        echo "}"
        echo "define-command -hidden pykak-response-b-impl %{"
        echo "    evaluate-commands %file{$py2kakb}"
        echo "}"
    }
    define-command -hidden pykak-response-a %{
        define-command -hidden -override pykak-response %{
            pykak-response-b
        }
        pykak-response-a-impl
    }
    define-command -hidden pykak-response-b %{
        define-command -hidden -override pykak-response %{
            pykak-response-a
        }
        pykak-response-b-impl
    }
    define-command -hidden pykak-response %{
        pykak-response-a
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

define-command -hidden pykak-request-a -params 1 %{
    define-command -hidden -override -params 1 pykak-request-impl %{
        pykak-request-b %arg{1}
    }
    echo -to-file %opt{kak2pya} %arg{1}
}
define-command -hidden pykak-request-b -params 1 %{
    define-command -hidden -override -params 1 pykak-request-impl %{
        pykak-request-a %arg{1}
    }
    echo -to-file %opt{kak2pyb} %arg{1}
}
define-command -hidden pykak-request-impl -params 1 %{
    pykak-request-a %arg{1}
}

define-command pykak-request -params 1 %{
    pykak-autoinit
    pykak-request-impl %arg{1}
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
    pykak-request %arg{1}
    try %{
        pykak-response-inf
    }
}
alias global py python
