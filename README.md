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
```
def sort-sels %{ py %{
    sels = sorted(valq('selections'))
    keval('reg dquote %s; exec R' % quote(sels))
}}
```
