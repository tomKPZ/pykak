# Pykak
Pykak allows plugin authors to script Kakoune with python.  The implementation uses IPC rather than forking new processes.

### Goals
- Ease of use
- Speed
- Minimalism
- Automatic resource cleanup

### Non-goals
- Completely replacing kakscript
- Providing a python interface for every Kakoune command

### System requirements
- Kakoune
- Python 3

## Installation
If using `plug.kak`:
```
plug 'tomKPZ/pykak'
```

Otherwise, clone the repo and add the following to your `kakrc`:
```
source /path/to/pykak/pykak.kak
```

### Configuration
`pk_interpreter`: Specify which python interpreter to use.  Defaults to `python3`.

The pykak server will be lazy-loaded on the first call to `python`.  You can also manually start the server with `pk_start`.

Example configuration with `plug.kak`:
```
plug 'tomKPZ/pykak' %{
    set global pk_interpreter pypy3 # defaults to python3
    pk_start # this is optional
}
```

## Usage

### Python
Python code can be run with the `python` command.  You can also use `py` which is aliased to `python`.

### Evaluating Kakoune commands

`keval(cmds)` can be used to run Kakoune commands.  Multiple commands may be separated by newlines or `;` as in regular kakscript.

[Default Kakoune commands](https://github.com/mawww/kakoune/blob/master/doc/pages/commands.asciidoc)

```python
def example %{
    python %{
        keval('echo "Hello, world!"')
    }
}
```

### Getters
`opt(x)`, `reg(x)`, and `val(x)` are equivalent to Kakoune's `%opt{x}`, `%reg{x}`, and `%val{x}`.  Unlike with variables in `%sh{}` expansions, these getters fetch values on-the-fly.

Quoted variants are also available: `optq(x)`, `regq(x)`, and `valq(x)`.  The quoted variants should be used when expecting list-type data.

[Default Kakoune options](https://github.com/mawww/kakoune/blob/master/doc/pages/options.asciidoc#builtin-options)
[Default Kakoune registers](https://github.com/mawww/kakoune/blob/master/doc/pages/registers.asciidoc#default-registers)
[Default Kakoune values](https://github.com/mawww/kakoune/blob/master/doc/pages/expansions.asciidoc#value-expansions)

```python
def getter_example %{
    python %{
        wm_str = opt('windowing_modules')
        wm_list = optq('windowing_modules')
        keval('echo -debug ' + quote(wm_str))
        keval('echo -debug ' + quote(str(wm_list)))
    }
}
```
Possible output:
```
tmux screen kitty iterm wayland x11
['tmux', 'screen', 'kitty', 'iterm', 'wayland', 'x11']
```

### Arguments
The `python` command accepts arguments before the main code block.  The arguments are accessible via `args`.  While Kakoune's `%arg{n}` is 1-indexed, `args[n]` is 0-indexed.  The below snippet prints `foo bar foo bar foo bar`.

```python
python foo bar 3 %{
    keval('echo ' + quote(args[:-1] * int(args[-1])))
}
```

Arguments can be forwarded from a command to python via Kakoune's `%arg{@}`.  Running `: foo a b c` with the below snippet prints `a b c`.

```python
def foo -params 0.. %{
    python %arg{@} %{
        keval('echo ' + quote(args))
    }
}
```

### Async IO
Pykak supports running Kakoune commands asynchronously via Kakoune's socket.

`keval_async(cmds, client=None)`: Evaluate `cmds` in Kakoune.  `cmds` is allowed to contain a `python` command.  If `client` is given, `cmds` will be executed in the context of that client.  `keval_async` may be called from any thread.  Communication with Kakoune (via `keval()` or similar) is only allowed on the main thread while Kakoune is servicing a `python` command.

```python
def async-example %{ py %{
    def foo(client):
        time.sleep(2)
        keval_async('echo hello world', client)
    threading.Thread(target=foo, args=[val('client')]).start()
}}
```

### Raw IO
In most cases, raw IO is not necessary.  However, it may be useful to batch multiple IOs together.

`pk_send data` and `pk_sendq data`: Sends `data` from Kakoune to python.  The `q` variant sends the data quoted.  It only makes sense to run these commands during a `keval` since that's the only way to obtain the data, otherwise the data will be discarded.  `keval` returns a list of data sent from these commands.

The below snippet prints `['hello world', ['hello', 'world']]`.

```python
def raw-io-example %{ py %{
    replies = keval('''
       pk_send hello world
       pk_sendq hello world
    ''')
    keval('echo ' + quote(str(replies)))
}}
```

## Examples

### Sort selections
`| sort` will sort lines within selections.  Sometimes sorting the selection contents themselves is desired.
```python
def sort-sels %{ py %{
    sels = sorted(valq('selections'))
    keval('reg dquote %s; exec R' % quote(sels))
}}
```

### Alternative word movement
In Vim, `5w` operates on 5 words, but in Kakoune it selects the 5th word.  This snippet makes Kakoune match Vim's behavior.
```python
def vim-w %{ py %{
    count = int(val('count'))
    keys = 'w'
    if count > 1:
        keys += '%dW' % (count - 1)
    keval('exec ' + keys)
}}
map global normal 'w' ': vim-w<ret>'
```
