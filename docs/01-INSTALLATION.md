## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   # ->>> shard.yml

   # ...
   dependencies:
     mel:
       github: GrottoPress/mel
       branch: master
   # ...
   ```

1. Run `shards install`

1. In your app's bootstrap, require *Mel*:

   ```crystal
   # ->>> src/app.cr

   # ...
   require "mel"
   # ...
   ```
