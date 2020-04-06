# moonkey
A Redis Module that executes string keys as Lua scripts.


## Abstract
Redis implements Lua script caching by forcing the user to specify the exact
SHA value of the script. This has the advantage of ensuring that clients never
get surprised by the script's behaviour, since changing the script, changes the SHA.

This module breaks this premise to offer the user a way of saving inside a string key
the whole lua script, and then have clients invoke the script by specifying the key name.

The upside is that this way we can combine script execution with ACL restrictions more easily
by allowing the user only to execute lua scripts preloaded by us. 

One issue currently not solved is that this module doesn't work in a clustered environment as 
the lua script will inevitably live in a specific hash slot, making it only available on one
shard at a time. For this reason, **this module will not load in Cluster mode**.


## Usage

`MK.EVALKEY scriptkey numkeys [key...] [arg...]`

Executes the script stored in `scriptkey`. The remaining arguments behave like in `EVAL` and `EVALSHA`.

Use `SET` and `GET` to manipulate script keys.


## Interaction with ACLs

To allow a user to run a specific script, you must give them access to the
`MK.EVALKEY` command, and to the key containing the Lua script they should be 
allowed to run.

```
> ACL SETUSER kristoff on +MK.EVALKEY ~myscript 
```

The Lua script can hardcode key names within it and any side effect applied to
them will be allowed **even if the user has no permission to access them**. This
is a different behaviour compared to `EVAL` and `EVALSHA`, where the lua interpreter
inherits all user restrictions.

```
> SET myscript "return {redis.call('get', 'test')}"
```

To have ACL restrictions apply to the keys manipulated by the lua script,
make sure to expose their access through the `KEYS` argument, just like normally done
with lua scripts.

```
> SET myscript "return {redis.call('get', KEYS[1])}"
```

### Note on hardcoding key names
Hardcoding key names in Lua scripts is generally considered a mistake but
since we are assuming that this module is by nature incompatible with 
Redis Cluster, then the practice has a different meaning considering the 
potentially useful interaction with ACLs.


## Downloading

Grab a compiled copy from the [Releases section](/releases) on GitHub, or compile the module yourself.
For now only a precompiled macOS version is available, soon I will also add a Linux version.

## Compiling

Requires [Zig](https://ziglang.org) > 0.5 (so 0.6 or master branch at the moment of writing)

```
$ cd redis-moonkey
$ zig build-lib -lc -dynamic -isystem . moonkey.zig
```

## Loading the module
In `redis-cli`:
```
> MODULE LOAD /path/to/module.so (or module.dylib on macOS)
```


