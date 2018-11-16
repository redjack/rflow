# RFlow

[![Build Status](https://travis-ci.org/redjack/rflow.png?branch=master)](https://travis-ci.org/redjack/rflow)

RFlow is a Ruby framework inspired by
[flow-based programming](http://en.wikipedia.org/wiki/Flow-based_programming)
(FBP), which was previously inspired by
[Communicating Sequential Processes](http://en.wikipedia.org/wiki/Communicating_sequential_processes)
(CSP). It has some conceptual similarities to Javascript's
[NoFlo](http://noflojs.org/) system, Java's
[Storm](http://storm.incubator.apache.org/), and Clojure's
[core.async](http://clojure.github.io/core.async/) library.

In short, components communicate with each other by sending/receiving
messages via their output/input ports over connections. Ports are
'wired' together output->input with connections, and messages are
explicitly serialized before being sent over the connection. RFlow
supports generalized connection types and message serialization,
however only two are in current use, namely ZeroMQ connections and
Avro serialization.

RFlow currently runs as a single-threaded, evented system on top of
[EventMachine](http://rubyeventmachine.com/), meaning that any code
should be coded in an asynchronous style so as to not block the
EventMachine reactor (and thus block all the other components). Use
`EM.defer` and other such patterns, along with EventMachine plugins
for various servers and clients, to work in this style and defer
computation to background threads.

RFlow component workflows may be split into `shards` to improve
parallelism. Each shard is currently represented by a separate process,
though threads may be supported in the future. Multiple copies of a
shard may be instantiated, which will cooperate to round-robin
incoming messages.

Some of the long-term goals of RFlow are to allow for components and
portions of the workflow to be defined in any language that supports
Avro and ZeroMQ, which are numerous. For this reason, the official
specification of an RFlow workflow is a SQLite database containing
information on its components, connections, ports, settings, etc.
There is a Ruby DSL that aids in populating the database but the intent
is that multiple processes and languages could access and manipulate
the database form.

## Developer Notes

You will need ZeroMQ preinstalled. Currently, EventMachine only supports
v3.2.4, not v4.x, so install that version. Older versions like 2.2 will not
work. (You will probably get errors saying arcane things like
`assertion failed, mailbox.cpp(84)`).

## Definitions

* __Component__ - the basic unit of RFlow computation. Each
  component is a shared-nothing, individual computation module that
  communicates with the rest of the system through explicit message
  passing via input and output ports.

* __Port__ - a named entity on each component that is responsible for
  receiving data (and input port) or sending data (and output port).
  Ports can be 'keyed' or 'indexed' to allow better multiplexing of
  messages out/in a single port, as well as allow a single port to be
  accessed by an array.

* __Connection__ - a directed link between an output port and an input
  port.  RFlow supports generalized connection types; however, only
  ZeroMQ links are currently used.  Round-robin and broadcast message
  delivery are supported on a per-link basis.

* __Message__ - a bit of serialized data that is sent out an output
  port and received on an input port. Due to the serialization,
  message types and schemas are explicitly defined. In a departure
  from 'pure' FBP, RFlow supports sending multiple message types via a
  single connection.

* __Workflow__ - the common name for the digraph created when the
  components (nodes) are wired together via connections to their
  respective output/input ports.

## Component Examples

The following describes the API of an RFlow component:

```ruby
class SimpleComponent < RFlow::Component
  input_port :in
  output_port :out

  def configure!(config); end
  def run!; end
  def process_message(input_port, input_port_key, connection, message); end
  def shutdown!; end
  def cleanup!; end
end
```

* `input_port` and `output_port` define the named ports that will
  receive data or send data, respectively. These class methods create
  accessors for their respective port names, to be used later in the
  `process_message` or `run!` methods. There can be multiple (or no)
  input and output ports.

* `configure!` (called with a hash configuration) is called after the
  component is instantiated but before the workflow has been wired or
  any messages have been sent. Note that this is called outside the
  EventMachine reactor.

* `run!` is called after all the components have been wired together
  with connections and the entire workflow has been created. For a
  component that is a source of messages, this is where messages will
  be sent. For example, if the component is reading from a file, this
  is where the file will be opened, the contents read into a message,
  and the message sent out the output port. `run!` is called within
  the EventMachine reactor.

* `process_message` is an evented callback that is called whenever the
  component receives a message on one of its input ports.
  `process_message` is called within the EventMachine reactor

* `shutdown!` is called when the flow is being terminated, and is
  meant to allow the components to do penultimate processing and send
  any final messages. All components in a flow will be told to
  `shutdown!` before they are told to `cleanup!`.

* `cleanup!` is the final call to each component, and allow the
  component to clean up any external resources that it might have
  outstanding, such as file handles or network sockets.

'Source' components will often do all of their work within the `run!`
method, and often gather message data from an external source, such as
file, database, or network socket. The following component generates a
set of integers between a configured start/finish, incrementing by a
configured step:

```ruby
class RFlow::Components::GenerateIntegerSequence < RFlow::Component
  output_port :out

  def configure!(config)
    @start = config['start'].to_i
    @finish = config['finish'].to_i
    @step = config['step'] ? config['step'].to_i : 1
    # If interval seconds is not given, it will default to 0
    @interval_seconds = config['interval_seconds'].to_i
  end

  # Note that this uses the timer (sometimes with 0 interval) so as
  # not to block the reactor
  def run!
    timer = EM::PeriodicTimer.new(@interval_seconds) do
      message = RFlow::Message.new('RFlow::Message::Data::Integer')
      message.data.data_object = @start
      out.send_message message
      @start += @step
      timer.cancel if @start > @finish
    end
  end
end
```

'Middle' components receive messages on input port(s), perform a bit
of computation, and then send a message out the output port(s). The
following component accepts a Ruby expression string via its config,
and then uses that as an expression to determine what port to send an
incoming message:

```ruby
class RFlow::Components::RubyProcFilter < RFlow::Component
  input_port :in
  output_port :filtered
  output_port :dropped
  output_port :errored

  def configure!(config)
    @filter_proc = eval("lambda {|message| #{config['filter_proc_string']} }")
  end

  def process_message(input_port, input_port_key, connection, message)
    begin
      if @filter_proc.call(message)
        filtered.send_message message
      else
        dropped.send_message message
      end
    rescue Exception => e
      errored.send_message message
    end
  end
end
```

'Sink' components accept messages on an input port and do not have an
output port. They often operate on external sinks, such as writing
messages to a file, database, or network socket. The following
component writes the inspected message to a file (defined via the
configuration):

```ruby
class RFlow::Components::FileOutput < RFlow::Component
  input_port :in

  attr_accessor :output_file_path

  def configure!(config)
    self.output_file_path = config['output_file_path']
  end

  def process_message(input_port, input_port_key, connection, message)
    File.open(output_file_path, 'a') do |f|
      f.flock(File::LOCK_EX)
      f.puts message.data.data_object.inspect
      f.flush
      f.flock(File::LOCK_UN)
    end
  end
end
```

## RFlow Messages

RFlow messages are instances of
[`RFlow::Message`](lib/rflow/message.rb), which are ultimately
serialized via an Avro [schema](schema/message.avsc).

There are two parts of the message 'envelope': a provenance and the
embedded data object 'payload'.

The `provenance` is a way for a component to annotate a message with a
bit of data that should (by convention) be carried through the
workflow with the message, as well as being copied to derived
messages. For example, a TCP server component would spin up a TCP
server and, upon receiving a connection and packets on a session, it
would marshal the packets into `RFlow::Messsage`s and send them out
its output ports. Messages received on its input port, however, need
to have a way to be matched to the corresponding underlying TCP
connection. `provenance` provides a method for the TCP server
component to add a bit of metadata (namely an identifier for the TCP
connection) such that later messages that contain the same provenance
can be matched to the correct underlying TCP connection.

The other parts of the message envelope are related to the embedded
data object. In addition to the data object itself (which is encoded
with a specific Avro schema), there are a few fields that describe the
embedded data, namely the `data_type_name`, the
`data_serialization_type`, and the `data_schema`. By including all
this metadata in each message, the system is completely dynamic and
allow for multiple message types to be included on a single
connection, as well as enabling non-RFlow components to be created in
any language. This does come at the expense of larger messages which
results in greater message overhead.

For example, if we have a simple integer data type that we would like
to serialize via Avro, we can register the schema with the following
`add_available_data_type` code shown below:

```ruby
long_integer_schema = '{"type": "long"}'
RFlow::Configuration.add_available_data_type('RFlow::Message::Data::Integer', 'avro', long_integer_schema)
```

This will make the schema and message type available to RFlow, such
that it will be able to create a new message with:

```ruby
message = RFlow::Message.new('RFlow::Message::Data::Integer')
```

and will automatically reconstitute a message from the connection and
call a component's `process_message`.

The deserialized Avro Ruby object is available as the `data_object`
accessor on the `data` class, i.e.:

```ruby
message.data.data_object = 1024
```

The `data_object` is the deserialized Avro Ruby object and, as such,
allows the Avro object to be accessed as a Ruby object. In order to
provide a more convenient interface to the underlying Avro object,
RFlow allows modules to be dynamically mixed in to the `data` class
object.

For example, the module below provides a bit of extra functionality to
the above-mentioned `RFlow::Message::Data::Integer` message type,
namely to default the integer to 0 upon being mixed in, provide a
better named accessor, and add a `default?` method to the `data` object:

```ruby
module SimpleDataExtension
  def self.extended(base_data)
    base_data.data_object = 0
  end

  def int; data_object; end
  def int=(new_int); data_object = new_int; end

  def default?;
    data_object == 0
  end
end
```

Once a module is defined, it needs to be registered to the appropriate
message data type.  Note that multiple modules can be registered for a
given message data type.

```ruby
RFlow::Configuration.add_available_data_extension('RFlow::Message::Data::Integer', SimpleDataExtension)
```

The result of this is that the following code will work:

```ruby
message = RFlow::Message.new('RFlow::Message::Data::Integer')
message.data.int == 0   # => true
message.data.default?   # => true
message.data.int = 1024
messaga.data.default?   # => false
```

## RFlow Workflow Configuration

RFlow currently stores its configuration in a SQLite database which
are internally accessed via ActiveRecord.  Given that SQLite is a
rather simple and standard interface, non-RFlow components could
access it and determine their respective ZMQ connections.

DB schemas for the configuration database are in
[lib/rflow/configuration/migrations](lib/rflow/configuration/migrations)
and define the complete workflow configuration.  Note that each of the
tables uses a UUID primary key, and UUIDs are used within RFlow to
identify specific components.

* settings - general application settings, such as log levels, app
  names, directories, etc.

* shards - a list of the shards defined for the workflow, including
  UUID, type, and number of workers for the shard

* components - a list of the components including its name,
  specification (Ruby class), shard, and options. Note that the options are
  serialized to the database as YAML, and components should understand
  that the round-trip through the database might not be perfect (e.g.
  Ruby symbols might become strings). A component also has a number of
  input ports and output ports.

* ports - belonging to a component (via `component_uuid` foreign key),
  also has a `type` column for ActiveRecord STI, which gets set to
  either a `RFlow::Configuration::InputPort` or
  `RFlow::Configuration::OutputPort`.

* connections - a connection between two ports via foreign keys
  `input_port_uuid` and `output_port_uuid`. Like ports, connections
  are typed via AR STI (`RFlow::Configuration::ZMQConnection` and
  `RFlow::Configuration::BrokeredZMQConnection` are the only
  supported values for now) and have a YAML serialized `options`
  hash and a `delivery` type (`round-robin` or `broadcast`).
  A connection also (potentially) defines the port keys.

RFlow also provides a RubyDSL for configuration-like file to be used
to load the database:

```ruby
RFlow::Configuration::RubyDSL.configure do |config|
  # Configure the settings, which include paths for various files, log
  # levels, and component specific stuffs
  config.setting 'rflow.log_level', 'DEBUG'
  config.setting 'rflow.application_directory_path', '../tmp'
  config.setting 'rflow.application_name', 'testapp'

  # Instantiate components
  config.component 'generate_ints1', 'RFlow::Components::GenerateIntegerSequence', {
    'start' => 0,
    'finish' => 10,
    'step' => 3,
    'interval_seconds' => 1
  }
  config.component 'generate_ints2', 'RFlow::Components::GenerateIntegerSequence', {
    'start' => 20,
    'finish' => 30
  }
  config.component 'filter', 'RFlow::Components::RubyProcFilter', {
    'filter_proc_string' => 'lambda {|message| true}'
  }
  config.component 'output1', 'RFlow::Components::FileOutput', {
    'output_file_path' => '/tmp/out1'
  }
  config.component 'output2', 'RFlow::Components::FileOutput', {
    'output_file_path' => '/tmp/out2'
  }

  # Wire components together
  config.connect 'generate_ints1#out' => 'filter#in'
  config.connect 'generate_ints2#out' => 'filter#in'
  config.connect 'filter#filtered' => 'replicate#in'
  config.connect 'filter#out' => 'output1#in'
  config.connect 'filter#filtered' => 'output2#in'
end
```

## Parallelism

RFlow supports parallelizing workflows and splitting them into multiple
`shard`s. By default, components declared in the Ruby DSL exist in the
default shard, named `DEFAULT`. There is only one worker for the default
shard.

ZeroMQ communication between components in the same shard uses ZeroMQ's
`inproc` socket type for maximum performance. ZeroMQ communication between
components in different shards is accomplished with a ZeroMQ `ipc` socket.
In the case of a many-to-many connection (many workers in a producing
shard and many workers in a consuming shard), a ZeroMQ message broker
process is created to route the messages appropriately. By default,
senders round-robin to receivers, though broadcast delivery can be chosen
instead. Receivers fair-queue the messages from senders.  Load balancing
based on receiver responsiveness is not currently implemented.

To define a custom shard in the Ruby DSL, use the `shard` method. For
example:

```ruby
RFlow::Configuration::RubyDSL.configure do |config|
  # Configure the settings, which include paths for various files, log
  # levels, and component specific stuffs
  config.setting 'rflow.log_level', 'DEBUG'
  config.setting 'rflow.application_directory_path', '../tmp'
  config.setting 'rflow.application_name', 'testapp'

  config.shard 'integers', :process => 2 do |shard|
    shard.component 'generate_ints1', 'RFlow::Components::GenerateIntegerSequence', {
      'start' => 0,
      'finish' => 10,
      'step' => 3,
      'interval_seconds' => 1
    }
    shard.component 'generate_ints2', 'RFlow::Components::GenerateIntegerSequence', {
      'start' => 20,
      'finish' => 30
    }
  end

  # another style of specifying type and count; count defaults to 1
  config.shard 'filters', :type => :process, :count => 1 do |shard|
    shard.component 'filter', 'RFlow::Components::RubyProcFilter', {
      'filter_proc_string' => 'lambda {|message| true}'
    }
  end

  # another way of specifying type
  config.process 'filters', :count => 2 do |shard|
    shard.component 'output1', 'RFlow::Components::FileOutput', {
      'output_file_path' => '/tmp/out1'
    }
  end

  # this component will be created in the DEFAULT shard
  config.component 'output2', 'RFlow::Components::FileOutput', {
    'output_file_path' => '/tmp/out2'
  }

  # Wire components together
  config.connect 'generate_ints1#out' => 'filter#in'
  config.connect 'generate_ints2#out' => 'filter#in'
  config.connect 'filter#filtered' => 'replicate#in'
  # choosing broadcast delivery delivers a copy to each worker for
  # the shard
  config.connect 'filter#out' => 'output1#in', :delivery => 'broadcast'
  config.connect 'filter#filtered' => 'output2#in'
end
```

At runtime, shards with no components defined will have no workers and
will not be started. (So, if you put all components in a custom shard,
no `DEFAULT` workers will be seen.)

## Command-Line Operation

RFlow includes the `rflow` binary that can load a database from a Ruby
DSL, as well as start/stop the workflow application as a daemon.
Invoking the `rflow` binary without any options will give a brief help:

```
Usage: rflow [options] (start|stop|status|load)
    -d, --database DB                Config database (sqlite) path (GENERALLY REQUIRED)
    -c, --config CONFIG              Config file path (only valid for load)
    -e, --extensions FILE1[,FILE_N]  Extension file paths (will load)
    -g, --gems GEM1[,GEM_N]          Extension gems (will require)
    -l, --log LOGFILE                Initial startup log file (in addition to stdout)
    -v, --verbose [LEVEL]            Control the startup log (and stdout) verbosity (DEBUG, INFO, WARN) defaults to INFO
    -f                               Run in the foreground
        --version                    Show RFlow version and exit
    -h, --help                       Show this message and exit
```

In general, the process for getting started is to first create a
configuration database via `rflow load`:

```
rflow load -d my_config.sqlite -c my_ruby_dsl.rb
```

which will create the `my_config.sqlite` configuration database loaded
with the `my_ruby_dsl.rb` configuration DSL.

Once a config database exists, you can start up the application that
it describes with `rflow start`. The `--extensions` argument allows
loading of arbitrary Ruby code (via Ruby's `load`), which is usually
where the component implementations are stored, as well as data type
registrations.

```
rflow start -d my_config.sqlite -e my_component.rb,my_other_component.rb,my_data_type.rb
```

By default, RFlow will daemonize, write its pid file to
`./run/app.pid` and write its log file to `./log/app.log`.  The `-f`
flag will keep RFlow in the foreground.

RFlow also supports two signals that allow for useful management of a
running RFlow daemon's log. Sending a `SIGUSR1` to the running RFlow
process will cause RFlow to close and reopen its log file, which
allows for easy log management without restarting RFlow. In addition,
sending a `SIGUSR2` will toggle RFlow's log-level to `DEBUG`, and a
subsequent `SIGUSR2` will toggle the log-level back to what was
originally set. This allows for easy debugging of a running RFlow
process.

## Debugging

Debugging is trickier than you'd like in RFlow 1.x because of the daemonization
and forking of child processes. You lose access to the console and have to do it
remote-style. The best way we've found so far is:

1. Add `gem 'byebug'` to Gemfile
1. When you want to set a debug point, run something like: `remote_byebug 'localhost', 8989 + worker.index` (`worker.index` is a quick and dirty attempt at making the port differ by process in case you have multiple workers on a shard wandering around; you probably also want to log the port you're using). You'll be stopped at a breakpoint.
1. Fire up `byebug -R localhost:<port>`. Voila.
1. Leave byebug open when you're done with it, if you hit the breakpoint again it's going to assume it's still connected, and if it isn't, you can't seem to reconnect.

   Copyright 2018 Redjack LLC

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
