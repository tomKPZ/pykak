# kakoune-smooth-scroll
Smooth scrolling for the [Kakoune](https://kakoune.org) text editor, with inertial movement

[![demo](https://caksoylar.github.io/kakoune-smooth-scroll/kakoune-smooth-scroll-v2-60fps.gif)](https://asciinema.org/a/m0DhKbv9AjAABOABKadgeYnH6?autoplay=1&loop=1)
<br/>(click for asciicast)

This plugin implements smooth scrolling similar to various plugins for Vim/Emacs etc. such as [vim-smooth-scroll](https://github.com/terryma/vim-smooth-scroll).
It gives you better visual feedback while scrolling and arguably helps you preserve your "sense of place" when making large jumps such as when using `<c-f>/<c-b>` movements.
The latest version of the plugin adds the smooth scrolling effect to most operations in `normal`, `goto` and `object` modes -- see the "Configuration" section below.

It also has support for inertial scrolling, also called the "easing out" or "soft stop" effect as seen above.
This effect is similar to Vim plugins such as [comfortable-motion.vim](https://github.com/yuttie/comfortable-motion.vim), [vim-smoothie](https://github.com/psliwka/vim-smoothie/) and [sexy-scroller.vim](https://github.com/joeytwiddle/sexy_scroller.vim).

## Installation
Download `smooth-scroll.kak` and `smooth-scroll.py` to your `autoload` folder, e.g. into `~/.config/kak/autoload`.
Or you can put them both in any location and `source path/to/smooth-scroll.kak` in your `kakrc`.

If you are using [plug.kak](https://github.com/andreyorst/plug.kak):
```kak
plug "caksoylar/kakoune-smooth-scroll" config %{
     # configuration here
}
```

## Configuration
`kakoune-smooth-scroll` operates through a mapping mechanism for keys in `normal`, `goto` and `object` modes.
Mapped keys will perform their usual functions but when they need to scroll the window the scrolling will happen smoothly.

Smooth scrolling is enabled and disabled on a per-window basis using `smooth-scroll-enable` and `smooth-scroll-disable` commands.
If you would like to automatically enable it for every window, you can use window-based hooks:
```kak
hook global WinCreate [^*].* %{
    hook -once window WinDisplay .* %{
        smooth-scroll-enable
    }
}
```

Above excludes special buffers that start with `*` like `*debug*`, `*scratch*` or `*plug*`.

### Customizing mapped keys
Keys that are mapped for each mode are customized via the `scroll_keys_normal`, `scroll_keys_goto` and `scroll_keys_object` options. If for a mode the corresponding option is not set, keys that are mapped by default are the following:

| **normal** keys                           | description                                 |
| ------                                    | ------                                      |
|`<c-f>`, `<pagedown>`, `<c-b>`, `<pageup>` | scroll one page down/up                     |
|`<c-d>`, `<c-u>`                           | scroll half a page down/up                  |
|`)`, `(`                                   | rotate main selection forward/backward      |
|`m`, `M`                                   | select/extend to next matching character    |
|`<a-semicolon>` (`<a-;>`)                  | flip direction of selection                 |
|`<percent>` (`%`)                          | select whole buffer                         |
|`n`, `<a-n>`, `N`, `<a-N>`                 | select/extend to next/previous match        |
|`u`, `U`, `<a-u>`, `<a-U>`                 | undo/redo, move backward/forward in history |

| **goto** keys                             | description                                 |
| ------                                    | ------                                      |
|`g`, `k`                                   | buffer top                                  |
|`j`                                        | buffer bottom                               |
|`e`                                        | buffer end                                  |
|`.`                                        | last buffer change                          |

| **object** keys                           | description                                 |
| ------                                    | ------                                      |
|`B`, `{`, `}`                              | braces block                                |
|`p`                                        | paragraph                                   |
|`i`                                        | indent                                      |

Default behavior is equivalent to the following configuration:
```kak
set-option global scroll_keys_normal <c-f> <c-b> <c-d> <c-u> <pageup> <pagedown> ( ) m M <a-semicolon> <percent> n <a-n> N <a-N> u U <a-u> <a-U>
set-option global scroll_keys_goto g k j e .
set-option global scroll_keys_object B { } p i
```

You can override which keys are mapped for each mode by setting the corresponding option.
For example if you only want to map page-wise motions in `normal` mode and disable any mappings for `goto` mode, you can configure it as such:
```kak
set-option global scroll_keys_normal <c-f> <c-b> <c-d> <c-u>
set-option global scroll_keys_goto
```

### Scrolling parameters
There are a few parameters related to the scrolling behavior that are adjustable through the `scroll_options` option which is a list of `<key>=<value>` pairs. Following keys are accepted and all of them are optional:
- `speed`: number of lines to scroll per tick, `0` for inertial scrolling (default: `0`)
- `interval`: average milliseconds between each tick (default: `10`)
- `max_duration`: maximum duration of a scroll in milliseconds (default: `500`)

The default configuration is equivalent to:
```kak
set-option global scroll_options speed=0 interval=10 max_duration=500
```

### Advanced usage

When defining `scroll_keys_*` options, each listed key is mapped to its regular function by default.
You might want to customize source and destination keys for each map, especially if you are already mapping other keys to these functions.
For instance if you use `<a-d>` instead of `<c-d>` and `<a-u>` instead of `<c-u>`, you can specify the option using `<src>=<dst>` pairs:
```kak
set-option global scroll_keys_normal <c-f> <c-b> <a-d>=<c-d> <a-u>=<c-u>
```

Note that these options need to be set before smooth scrolling is enabled for a window.

For more fine-tuned control you can map keys individually with `smooth-scroll-map-key`, which has an interface similar to Kakoune's `map` command:
```kak
smooth-scroll-map-key normal <a-percent> *<percent>s<ret>
```
The mappings are applied in the window scope. You can call this command inside the `WinDisplay` hook after `smooth-scroll-enable`.

An analogue to `execute-keys` is also available if you want to utilize smooth scrolling programmatically:
```kak
smooth-scroll-execute-keys /TODO|FIXME<ret>
```

Note: Smooth scrolling still has to be enabled in the window scope using `smooth-scroll-enable` for above commands to work properly.

### Customization using hooks

`kakoune-smooth-scroll` triggers three user hooks during a movement: `ScrollBegin` just before scrolling, `ScrollStep` after each scroll step and `ScrollEnd` after scrolling is finished. These can be used to customize appearance changes during scrolling. For instance, you could change line numbers to absolute while scrolling, then restore them to relative after the scroll is complete with the following hook definitions:
```kak
# say "window/nl" is the name of your per-window number-lines highlighter
hook -group smooth-scroll window User ScrollBegin %{
    add-highlighter -override window/nl number-lines
}
hook -group smooth-scroll window User ScrollEnd %{
    add-highlighter -override window/nl number-lines -relative -hlcursor
}
```

These hooks can also help with integrating with other plugins. For instance, if you are using [scrollbar.kak](https://github.com/sawdust-and-diamonds/scrollbar.kak) you can force the scrollbar to update at each scrolling step by defining the following hook:
```kak
hook window User ScrollStep %{ update-scrollbar }
```

## Caveats
- Smooth scrolling is not performed for movements that do not modify the selection, such as any movement through the `view` mode. See [related Kakoune issue](https://github.com/mawww/kakoune/issues/3616)
  - Keys that scroll by page (`<c-f>`,`<c-b>`,`<c-d>`,`<c-u>`) are handled specially to work around this limitation
- Movements that are caused by the `prompt` mode such as `/search_word<ret>` can not be mapped at the moment
- Repeating selections with `<a-.>` is not possible if the selection was made through mapped keys
  - You can disable mappings for object mode to enable repeating, using `set-option global scroll_keys_object`
- Does not work for large vertical `scrolloff` values which are frequently used for keeping the cursor centered in the window, see [issue](https://github.com/caksoylar/kakoune-smooth-scroll/issues/9)
- For optimal performance it uses a Python implementation which requires Python 3.6+ in path, falling back to `sh` if not available
  - This implementation utilizes Kakoune's internal [remote API](https://github.com/mawww/kakoune/blob/master/src/remote.hh)

## Acknowledgments
Thanks @Screwtapello and @Guest0x0 for valuable feedback and fixes!

## License
MIT
