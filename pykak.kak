define-command pykak-init %{
    evaluate-commands %sh{
        tmp_dir=$(mktemp -d -t pykak-XXXXXX)
        kak2py="$tmp_dir/kak2py.fifo"
        mkfifo "$kak2py"
        py2kak="$tmp_dir/py2kak.fifo"
        mkfifo "$py2kak"
        file=/home/tom/dev/local/pykak/pykak.py
        python3 "$file" "$kak2py" "$py2kak" > /dev/null 2>&1 </dev/null &
        pykak_pid=$!
        echo "declare-option -hidden str kak2py "$kak2py""
        echo "declare-option -hidden str py2kak "$py2kak""
        echo "declare-option -hidden str pykak_pid "$pykak_pid""
        echo "define-command -hidden pykak-response %{"
        echo "    evaluate-commands %file{$py2kak}"
        echo "}"
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

define-command pykak-request -params 1 %{
    pykak-autoinit
    echo -to-file %opt{kak2py} %arg{1}
    pykak-response
}

define-command python -params 1 %{
    pykak-request %arg{1}
}
alias global py python
