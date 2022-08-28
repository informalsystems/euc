## How to use the config.json file

The config.json file schema definition is [here](config.schema.json).

If a network name in the chain registry is the same as the binary for the network (for example 'regen'),
it is enough to define the binary name using `daemon_name`. If the names are different, you need both
`daemon_name` and `chain_name` defined.

To override the version of the binary defined in the chain registry, you have to define `codebase.recommended_version`
in the network config.
