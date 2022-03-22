# user-facing options
declare-option -docstring %{
    space-separated list of <key>=<value> pairs that specify the behavior of
    smooth scroll.

    Following keys are accepted:
        speed:        number of lines to scroll per tick, 0 for inertial
                      scrolling (default: 0)
        interval:     average milliseconds between each scroll (default: 10)
        max_duration: maximum duration of a scroll in milliseconds (default: 500)
} str-to-str-map scroll_options speed=0 interval=10 max_duration=500

declare-option -docstring %{
    list of keys to apply smooth scrolling in normal mode. Specify only keys
    that do not modify the buffer. If source and destination mappings are different,
    specify them in the format <src>=<dst>. Existing mappings for source keys will
    be overridden.

    Default:
        <c-f> <c-b> <c-d> <c-u> <pageup> <pagedown> ( ) m M <a-semicolon>
        <percent> n <a-n> N <a-N> u U <a-u> <a-U>
} str-list scroll_keys_normal <c-f> <c-b> <c-d> <c-u> <pageup> <pagedown> ( ) m M <a-semicolon> \% n <a-n> N <a-N> u U <a-u> <a-U>

declare-option -docstring %{
    list of keys to apply smooth scrolling in goto mode. If source and
    destination mappings are different, specify them in the format <src>=<dst>.
    Existing mappings for source keys will be overridden.

    Default:
        g k j e .
} str-list scroll_keys_goto g k j e .

declare-option -docstring %{
    list of keys to apply smooth scrolling in object mode. If source and
    destination mappings are different, specify them in the format <src>=<dst>.
    Existing mappings for source keys will be overridden.

    Default:
        B { } p i
} str-list scroll_keys_object B { } p i

# internal
declare-option -hidden str scroll_py %sh{printf "%s" "${kak_source%.kak}.py"}  # python script path
declare-option -hidden bool scroll_fallback false  # remember if we fell back to sh impl
declare-option -hidden str scroll_running ""       # pid of scroll process if it running
declare-option -hidden str scroll_window           # new location after a key press
declare-option -hidden str-list scroll_selections  # new selections after a key press
declare-option -hidden str scroll_client           # store for WinSetOption hook which runs in draft context
declare-option -hidden str scroll_mode             # key we used to enter a mode so we can replicate it

define-command smooth-scroll-enable -docstring "enable smooth scrolling for window" %{
    smooth-scroll-disable

    # map the list of keys to smoothly scroll for given by the scroll_keys_* options
    evaluate-commands %sh{
        # $kak_quoted_opt_scroll_keys_normal, $kak_quoted_opt_scroll_keys_goto, $kak_quoted_opt_scroll_keys_object
        for mode in normal goto object; do
            eval option="\$kak_quoted_opt_scroll_keys_$mode"
            eval "set -- $option"
            for key; do
                # in case both sides of the mapping were given with lhs=rhs, split
                lhs=${key%%=*}
                rhs=${key#*=}
                printf "smooth-scroll-map-key %s '%s' '%s'\\n" "$mode" "$lhs" "$rhs"
            done
        done
    }

    set-option window scroll_running ""
    set-option window scroll_client %val{client}

    # remember what key we used to enter a mode so we can replicate it
    hook -group scroll window NormalKey [gG[\]{}]|<a-[ai]> %{
        set-option window scroll_mode %val{hook_param}
    }

    # when we exit normal mode, kill the scrolling process if it is currently running
    hook -group scroll window ModeChange push:normal:.* %{
        evaluate-commands %sh{
            if [ -n "$kak_opt_scroll_running" ]; then
                kill "$kak_opt_scroll_running"
                printf 'set-option window scroll_running ""\n'
            fi
        }
    }

    # started scrolling, make cursor invisible to make it less jarring
    hook -group scroll window WinSetOption scroll_running=\d+ %{
        set-face window PrimaryCursor @default
        set-face window PrimaryCursorEol @default
        set-face window LineNumberCursor @LineNumbers
        evaluate-commands -client %opt{scroll_client} %{ trigger-user-hook ScrollBegin }
    }

    # done scrolling, so restore cursor highlighting and original selection
    hook -group scroll window WinSetOption scroll_running= %{
        evaluate-commands -client %opt{scroll_client} %{
            try %{ select %opt{scroll_selections} }
        }
        unset-face window PrimaryCursor
        unset-face window PrimaryCursorEol
        unset-face window LineNumberCursor
        evaluate-commands -client %opt{scroll_client} %{ trigger-user-hook ScrollEnd }
    }
}

define-command smooth-scroll-disable -docstring "disable smooth scrolling for window" %{
    # undo window-level mappings
    evaluate-commands %sh{
        # $kak_quoted_opt_scroll_keys_normal, $kak_quoted_opt_scroll_keys_goto, $kak_quoted_opt_scroll_keys_object
        for mode in normal goto object; do
            eval option="\$kak_quoted_opt_scroll_keys_$mode"
            eval "set -- $option"
            for key; do
                lhs=${key%%=*}
                printf "unmap window %s '%s'\\n" "$mode" "$lhs"
            done
        done
    }
    # remove our hooks
    remove-hooks window scroll

    # restore faces if we somehow didn't before
    unset-face window PrimaryCursor
    unset-face window PrimaryCursorEol
}

define-command smooth-scroll-map-key -params 3 -docstring %{
    smooth-scroll-map-key <mode> <lhs> <rhs>: map key <lhs> to key <rhs> for
    mode <mode> and enable smooth scrolling for that operation
} %{
    evaluate-commands %sh{
        mode=$1
        lhs=$2
        rhs=$3
        q_rhs=$(printf '%s' "$rhs" | sed -e 's/</#lt#/g' -e 's/>/<gt>/g' -e 's/#lt#/<lt>/g')

        case $mode in
            normal)  # handle page scroll keys specially
                case $rhs in
                    "<c-f>") printf "map window %s '%s' ': smooth-scroll-by-page  1 ''%s''<ret>'\\n" "$mode" "$lhs" "$q_rhs" ;;
                    "<c-b>") printf "map window %s '%s' ': smooth-scroll-by-page -1 ''%s''<ret>'\\n" "$mode" "$lhs" "$q_rhs" ;;
                    "<c-d>") printf "map window %s '%s' ': smooth-scroll-by-page  2 ''%s''<ret>'\\n" "$mode" "$lhs" "$q_rhs" ;;
                    "<c-u>") printf "map window %s '%s' ': smooth-scroll-by-page -2 ''%s''<ret>'\\n" "$mode" "$lhs" "$q_rhs" ;;
                    *)       printf "map window %s '%s' ': smooth-scroll-execute-keys ''%s''<ret>'\\n" "$mode" "$lhs" "$q_rhs"
                esac
                ;;
            goto)  # save selections to jump list to emulate native behavior and add docstrings to some items
                case $rhs in
                    [gk]) save='<c-s>'; doc='-docstring "buffer top"' ;;
                    j)    save='<c-s>'; doc='-docstring "buffer bottom"' ;;
                    e)    save='<c-s>'; doc='-docstring "buffer end"' ;;
                    .)    save='<c-s>'; doc='-docstring "last buffer change"' ;;
                    *)    save='';      doc="";
                esac
                printf "map window goto '%s' '<esc>%s: smooth-scroll-execute-keys %s ''%s''<ret>' %s\\n" "$lhs" "$save" "%opt{scroll_mode}" "$q_rhs" "$doc"
                ;;
            object)  # add docstrings to some items
                case $rhs in
                    [B{}]) doc='-docstring "brackets block"' ;;
                    p)     doc='-docstring "paragraph"' ;;
                    i)     doc='-docstring "indent"' ;;
                    *)     doc=""
                esac
                printf "map window object '%s' '<esc>: smooth-scroll-execute-keys %s ''%s''<ret>' %s\\n"  "$lhs" "%opt{scroll_mode}" "$q_rhs" "$doc"
                ;;
            *)
                printf 'fail "mode %s is not supported for smooth-scroll-map-key"\n' "$mode"
        esac
    }
}

define-command smooth-scroll-execute-keys -params .. -docstring %{
    smooth-scroll-execute-keys <keys>: execute keys as given, scrolling smoothly
    if window needs to be scrolled. does not modify the buffer even if the keys
    would normally do so
} %{
    # execute key in draft context to figure out the final selection and window_range
    evaluate-commands -draft %{
        execute-keys %val{count} %arg{@}
        set-option window scroll_window %val{window_range}
        set-option window scroll_selections %val{selections_desc}
    }

    # check if we moved the viewport, then smoothly scroll there if we did
    evaluate-commands %sh{
        if [ "$kak_window_range" != "$kak_opt_scroll_window" ] && [ -z "$kak_opt_scroll_running" ]; then
            diff=$(( ${kak_opt_scroll_window%% *} - ${kak_window_range%% *} ))
            abs_diff=${diff#-}
            if [ "$abs_diff" -gt 1 ]; then  # we moved the viewport by at least 2
                # scroll to new position smoothly (selection will be restored when done)
                printf 'execute-keys <space>\n'
                printf 'smooth-scroll-move %s\n' "$diff"
                exit 0
            fi
        fi
        # we haven't moved the viewport enough so just apply selection
        printf 'select %s\n' "$kak_opt_scroll_selections"
    }
}

define-command smooth-scroll-move -params 1 -hidden -docstring %{
    smooth-scroll-move <amount>: smoothly scroll abs(amount) rows down if positive,
    up if negative. when completed, selections will be restored to the value in
    %opt{scroll_selections}
} %{
    evaluate-commands %sh{
        amount=$1
        abs_amount=${amount#-}

        if [ "$abs_amount" -gt 1 ]; then
            # try to run the python version
            if type python3 >/dev/null 2>&1 && [ -f "$kak_opt_scroll_py" ]; then
                python3 -S "$kak_opt_scroll_py" "$amount" >/dev/null 2>&1 </dev/null &
                printf 'set-option window scroll_running %s\n' "$!"
                exit 0
            fi

            # fall back to pure sh
            if [ "$kak_opt_scroll_fallback" = "false" ]; then
                printf 'set-option global scroll_fallback true\n'
                printf 'echo -debug kakoune-smooth-scroll: WARNING -- cannot execute python version, falling back to pure sh\n'
            fi
        fi

        eval "$kak_opt_scroll_options"
        speed=${speed:-0}
        interval=${interval:-10}
        max_duration=${max_duration:-1000}
        if [ "$speed" -eq 0 ]; then
            speed=1
        fi

        if [ "$abs_amount" = "$amount" ]; then
            keys="${speed}j${speed}vj"
        else
            keys="${speed}k${speed}vk"
        fi
        cmd="printf 'exec -client %s %s; eval -client %s ""trigger-user-hook ScrollStep""\\n' ""$kak_client"" ""$keys"" ""$kak_client"" | kak -p ""$kak_session"""

        times=$(( abs_amount / speed ))
        if [ $(( times * interval )) -gt "$max_duration" ]; then
            interval=$(printf 'scale=3; %f/(%f - 1)\n' "$max_duration" "$times" | bc)
        fi
        # printf 'echo -debug interval=%f max_duration=%d speed=%d times=%d\n' "$interval" "$max_duration" "$speed" "$times"
        (
            i=0
            t1=$(date +%s.%N)
            while [ $i -lt $times ]; do
                eval "$cmd"
                t2=$(date +%s.%N)
                sleep_for=$(printf 'scale=3; %f/1000 - (%f - %f)\n' "$interval" "$t2" "$t1" | bc)
                # printf 'echo -debug i=%d sleep_for=%s\n' $i "$sleep_for" | kak -p "$kak_session"
                if [ "$sleep_for" = "${sleep_for#-}" ]; then
                    sleep "$sleep_for"
                fi
                t1=$t2
                i=$(( i + 1 ))
            done
            printf "evaluate-commands -client %s '%s'\\n" "$kak_client" 'set-option window scroll_running ""' | kak -p "$kak_session"
        ) >/dev/null 2>&1 </dev/null &
        printf 'set-option window scroll_running %s\n' "$!"
    }
}

define-command smooth-scroll-by-page -params 2 -hidden -docstring %{
    smooth-scroll-by-page <unit> <key>: scroll smoothly by (1 / <unit>) pages,
    positive for down, negative for up. if the cursor doesn't have to move, scroll
    manually. otherwise, emulate the key press given by <key>
} %{
    evaluate-commands %sh{
        if [ "$kak_count" = 0 ]; then
            kak_count=1
        fi
        distance=$(( kak_count * (kak_window_height - 2) / $1 ))  # from src/normal.cc#L1398
        if [ "$kak_cursor_line" -ge $(( ${kak_window_range%% *} + distance )) ] \
        && [ "$kak_cursor_line" -le $(( ${kak_window_range%% *} + distance + kak_window_height )) ];
        then
            # the cursor doesn't need to move, save the selection and move manually
            printf 'set-option window scroll_selections %s\n' "$kak_selections_desc"
            printf 'smooth-scroll-move %s\n' "$distance"
        else
            # the cursor has to move, so emulate the key press
            printf 'smooth-scroll-execute-keys "%s"\n' "$2"
        fi
    }
}
