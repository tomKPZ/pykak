# Pykak
Pykak allows plugin authors to script Kakoune with python.  The implementation uses IPC rather than forking new processes.

## Goals
- Ease of use: python
- Speed: %sh{} is not used other than to start the pykak server
- Minimalism
- Automatic resource cleanup on exit

## Non-goals
- Completely replacing kakscript
- Providing a python interface for every Kakoune command

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

## Async IO
Pykak supports running Kakoune commands asynchronously via Kakoune's socket.

`keval_async(cmds, client=None)`: Evaluate `cmds` in Kakoune.  `cmds` is allowed to contain a `python` command.  If `client` is given, `cmds` will be executed in the context of that client.  `keval_async` may be called from any thread.

```python
def async-example %{ py %{
    def foo(client):
        time.sleep(2)
        keval_async('echo hello world', client)
    threading.Thread(target=foo, args=[val('client')]).start()
}}
```

## Raw IO
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
