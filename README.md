Pathological
============

Pathological is a Ruby tool that provides a lightweight mechanism for managing your project's load path.

The problem
-----------

When you're writing a gem, you don't have to worry about paths much, because Rubygems makes sure that `lib/`
makes it into your path for you. On the other hand, if you have large Ruby projects which aren't organized as
gems, you may encounter some of the following problems:

  * If you don't have relative requires, you have to run your project from the project root.
  * If you want relative requires, you have something nasty like this in your code:

        require File.expand_path(File.join(File.dirname(__FILE__), 'myfile'))

  * Ruby 1.9.2 breaks your load path if you are expecting `.` to be in it. You might have to use
    `require_relative` or similar to remedy this.
  * You have symlinks to shared libraries or non-gemified vendor code living all over your project in order
    to keep your load paths sane.

Pathological provides one way to manage these issues.

Using pathological
------------------

Getting started with pathological is easy. First, make a file called `Pathfile` at your project root:

    $ cd path/to/myproject
    $ touch Pathfile

Now require the gem at the start of any executable ruby file:

``` ruby
#!/usr/bin/env ruby

require "rubygems" # If you're using 1.8
require "pathological"
# other requires...
```

Now your project root will be in your load path. If your project has, for example, `lib/foo.rb`, then `require
lib/foo` will work in any of your ruby files. This works because when Pathological is required it will search
up the directory tree until it finds a `Pathfile`. (It will raise an error if there this cannot be found).

Adding other paths to your load path
------------------------------------

To add more paths to your load path, just put the paths in your `Pathfile`. The paths are relative to the
location of the `Pathfile`. The paths will be inserted in the order they appear; the project root itself will
be first. If any of the paths are not valid directories, then an exception will be raised when Pathological is
required.

#### Example

Suppose that you have a directory structure like this:

    repos/
    |-shared_lib/
    | `-common.rb
    `-my_project/
      |-Pathfile
      |-run_my_project.rb
      `-foo.rb

and that `Pathfile` contains the following:

    ../shared_lib

Then inside `run_my_project.rb`:

``` ruby
require "rubygems"
require "pathological"
require "foo"
require "common"
# ...
```

Installation
------------

Pathological is packaged as a Rubygem and hence can be trivially installed with

    $ gem install pathological

Advanced usage
--------------

In some cases, you might want slightly different behavior. There are a few other options that may come in
handy in these cases. In general, extra options are specified by lines in the `Pathfile` starting with `>`.
(Similarly, comments may be specified by `#`.)

  1. `exclude-root`: exclude project root from the load path.
  2. `no-exceptions`: don't raise exceptions on bad paths.

#### Example

    # My project Pathfile
    > no-exceptions
    > exclude-root  # Don't want the root directory
    lib/            # Do include lib/
    ../my_gems/     # Include my local gem directory, if it exists

Authors
-------

Pathological was written by Ooyala engineers [Daniel MacDougall](mailto:dmac@ooyala.com) and [Caleb
Spare](mailto:caleb@ooyala.com).

Credits
-------

  * Harry Robertson for the idea to *not* use a dot-prefixed configuration file

Contributing
------------

If you would like to commit a patch, great! Just do the usual github pull request stuff and we'll check it
out.

License
-------

Pathological is licensed under the MIT license.
