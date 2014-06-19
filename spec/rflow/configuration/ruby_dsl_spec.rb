require 'spec_helper'
require 'rflow/configuration'

class RFlow
  class Configuration
    describe RubyDSL do
      before(:each) do
        ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
        Configuration.migrate_database
      end

      it "should correctly process an empty DSL" do
        described_class.configure {}

        expect(Shard).to have(0).shards
        expect(Component).to have(0).components
        expect(Port).to have(0).ports
        expect(Connection).to have(0).connections
      end

      it "should correctly process a component declaration" do
        described_class.configure do |c|
          c.component 'boom', 'town', 'opt1' => 'OPT1', 'opt2' => 'OPT2'
        end

        expect(Shard).to have(1).shard
        expect(Component).to have(1).component
        expect(Port).to have(0).ports
        expect(Connection).to have(0).connections

        Component.first.tap do |c|
          expect(c.name).to eq('boom')
          expect(c.specification).to eq('town')
          expect(c.options).to eq('opt1' => 'OPT1', 'opt2' => 'OPT2')
        end
      end

      it "should correctly process a connect declaration" do
        described_class.configure do |c|
          c.component 'first', 'First'
          c.component 'second', 'Second'
          c.connect 'first#out' => 'second#in'
          c.connect 'first#out' => 'second#in[inkey]'
          c.connect 'first#out[outkey]' => 'second#in'
          c.connect 'first#out[outkey]' => 'second#in[inkey]'
        end

        expect(Shard).to have(1).shard
        expect(Component).to have(2).components
        expect(Port).to have(2).ports
        expect(Connection).to have(4).connections

        first_component = Component.find_by_name('first').tap do |c|
          expect(c.specification).to eq('First')
          expect(c).to have(0).input_ports
          expect(c).to have(1).output_port

          out_port = c.output_ports.first
          expect(out_port.name).to eq('out')

          expect(out_port).to have(4).connections
          out_port.connections.tap do |connections|
            connections.each {|c| expect(c.delivery).to eq 'round-robin' }
            expect(connections[0].input_port_key).to be_nil
            expect(connections[0].output_port_key).to be_nil
            expect(connections[1].input_port_key).to eq('inkey')
            expect(connections[1].output_port_key).to be_nil
            expect(connections[2].input_port_key).to be_nil
            expect(connections[2].output_port_key).to eq('outkey')
            expect(connections[3].input_port_key).to eq('inkey')
            expect(connections[3].output_port_key).to eq('outkey')
          end
        end

        Component.find_by_name('second').tap do |c|
          expect(c.specification).to eq('Second')
          expect(c).to have(1).input_port
          expect(c).to have(0).output_ports

          in_port = c.input_ports.first
          expect(in_port.name).to eq('in')

          expect(in_port).to have(4).connections
          expect(in_port.connections).to eq(first_component.output_ports.first.connections)
        end
      end

      it "should correctly process shard declarations" do
        described_class.configure do |c|
          c.component 'first', 'First', :opt1 => 'opt1'

          c.shard "s1", :process => 2 do |s|
            s.component 'second', 'Second', :opt1 => 'opt1', "opt2" => "opt2"
          end

          c.shard "s2", :type => :process, :count => 10 do |s|
            s.component 'third', 'Third'
            s.component 'fourth', 'Fourth'
          end

          c.process "s3", :count => 10 do |s|
            s.component 'fifth', 'Fifth'
          end

          c.shard "s-ignored", :type => :process, :count => 10 do
            # ignored because there are no components
          end

          c.thread "s4", :count => 10 do |s|
            s.component 'sixth', 'Sixth'
          end

          c.shard "s5", :type => :thread, :count => 10 do |s|
            s.component 'seventh', 'Seventh'
          end

          c.component 'eighth', 'Eighth'

          c.connect 'first#out' => 'second#in'
          c.connect 'second#out[outkey]' => 'third#in[inkey]'
          c.connect 'second#out' => 'third#in2'
          c.connect 'third#out' => 'fourth#in'
          c.connect 'third#out' => 'fifth#in'
          c.connect 'third#out' => 'sixth#in'
        end

        expect(Shard).to have(6).shards
        expect(Component).to have(8).components
        expect(Port).to have(9).ports
        expect(Connection).to have(6).connections

        Shard.all.tap do |shards|
          expect(shards.map(&:name)).to eq(['DEFAULT', 's1', 's2', 's3', 's4', 's5'])
          expect(shards.map(&:type)).to eq((['RFlow::Configuration::ProcessShard'] * 4) + (['RFlow::Configuration::ThreadShard'] * 2))
          expect(shards.first.components.all.map(&:name)).to eq(['first', 'eighth'])
          expect(shards.second.components.all.map(&:name)).to eq(['second'])
          expect(shards.third.components.all.map(&:name)).to eq(['third', 'fourth'])
          expect(shards.fourth.components.all.map(&:name)).to eq(['fifth'])
        end

        expect(Port.all.map(&:name)).to eq(['out', 'in', 'out', 'in', 'in2', 'out', 'in', 'in', 'in'])

        expect(Connection.all.map(&:name)).to eq(
          ['first#out=>second#in',
           'second#out[outkey]=>third#in[inkey]',
           'second#out=>third#in2',
           'third#out=>fourth#in',
           'third#out=>fifth#in',
           'third#out=>sixth#in'])
      end

      it "should generate PUSH-PULL inproc ZeroMQ connections for in-shard connections" do
        described_class.configure do |c|

          c.shard "s1", :process => 1 do |s|
            s.component 'first', 'First', :opt1 => 'opt1'
            s.component 'second', 'Second', :opt1 => 'opt1', "opt2" => "opt2"
          end

          c.connect 'first#out' => 'second#in'
        end

        expect(Shard).to have(1).shards
        expect(Component).to have(2).components
        expect(Port).to have(2).ports
        expect(Connection).to have(1).connections

        Connection.first.tap do |conn|
          expect(conn.type).to eq('RFlow::Configuration::ZMQConnection')
          expect(conn.name).to eq('first#out=>second#in')
          expect(conn.output_port_key).to be_nil
          expect(conn.input_port_key).to be_nil
          conn.options.tap do |opts|
            expect(opts['output_socket_type']).to eq('PUSH')
            expect(opts['output_address']).to eq("inproc://rflow.#{conn.uuid}")
            expect(opts['output_responsibility']).to eq('connect')
            expect(opts['input_socket_type']).to eq('PULL')
            expect(opts['input_address']).to eq("inproc://rflow.#{conn.uuid}")
            expect(opts['input_responsibility']).to eq('bind')
          end
        end
      end

      it "should generate PUSH-PULL ipc ZeroMQ connections for one-to-one inter-shard connections" do
        described_class.configure do |c|

          c.shard "s1", :process => 1 do |s|
            s.component 'first', 'First', :opt1 => 'opt1'
          end

          c.shard "s2", :process => 1 do |s|
            s.component 'second', 'Second', :opt1 => 'opt1', "opt2" => "opt2"
          end

          c.connect 'first#out' => 'second#in'
        end

        expect(Shard).to have(2).shards
        expect(Component).to have(2).components
        expect(Port).to have(2).ports
        expect(Connection).to have(1).connections

        Connection.first.tap do |conn|
          expect(conn.type).to eq('RFlow::Configuration::ZMQConnection')
          expect(conn.name).to eq('first#out=>second#in')
          expect(conn.output_port_key).to be_nil
          expect(conn.input_port_key).to be_nil
          conn.options.tap do |opts|
            expect(opts['output_socket_type']).to eq('PUSH')
            expect(opts['output_address']).to eq("ipc://rflow.#{conn.uuid}")
            expect(opts['output_responsibility']).to eq('connect')
            expect(opts['input_socket_type']).to eq('PULL')
            expect(opts['input_address']).to eq("ipc://rflow.#{conn.uuid}")
            expect(opts['input_responsibility']).to eq('bind')
          end
        end
      end

      it "should generate PUSH-PULL ipc ZeroMQ connections for one-to-many inter-shard connections" do
        described_class.configure do |c|

          c.shard "s1", :process => 1 do |s|
            s.component 'first', 'First', :opt1 => 'opt1'
          end

          c.shard "s2", :process => 3 do |s|
            s.component 'second', 'Second', :opt1 => 'opt1', "opt2" => "opt2"
          end

          c.connect 'first#out' => 'second#in'
        end

        expect(Shard).to have(2).shards
        expect(Component).to have(2).components
        expect(Port).to have(2).ports
        expect(Connection).to have(1).connections

        Connection.first.tap do |conn|
          expect(conn.type).to eq('RFlow::Configuration::ZMQConnection')
          expect(conn.name).to eq('first#out=>second#in')
          expect(conn.output_port_key).to be_nil
          expect(conn.input_port_key).to be_nil
          conn.options.tap do |opts|
            expect(opts['output_socket_type']).to eq('PUSH')
            expect(opts['output_address']).to eq("ipc://rflow.#{conn.uuid}")
            expect(opts['output_responsibility']).to eq('bind')
            expect(opts['input_socket_type']).to eq('PULL')
            expect(opts['input_address']).to eq("ipc://rflow.#{conn.uuid}")
            expect(opts['input_responsibility']).to eq('connect')
          end
        end
      end

      it "should generate PUSH-PULL ipc ZeroMQ connections for many-to-one inter-shard connections" do
        described_class.configure do |c|

          c.shard "s1", :process => 3 do |s|
            s.component 'first', 'First', :opt1 => 'opt1'
          end

          c.shard "s2", :process => 1 do |s|
            s.component 'second', 'Second', :opt1 => 'opt1', "opt2" => "opt2"
          end

          c.connect 'first#out' => 'second#in'
        end

        expect(Shard).to have(2).shards
        expect(Component).to have(2).components
        expect(Port).to have(2).ports
        expect(Connection).to have(1).connections

        Connection.first.tap do |conn|
          expect(conn.type).to eq('RFlow::Configuration::ZMQConnection')
          expect(conn.name).to eq('first#out=>second#in')
          expect(conn.output_port_key).to be_nil
          expect(conn.input_port_key).to be_nil
          conn.options.tap do |opts|
            expect(opts['output_socket_type']).to eq('PUSH')
            expect(opts['output_address']).to eq("ipc://rflow.#{conn.uuid}")
            expect(opts['output_responsibility']).to eq('connect')
            expect(opts['input_socket_type']).to eq('PULL')
            expect(opts['input_address']).to eq("ipc://rflow.#{conn.uuid}")
            expect(opts['input_responsibility']).to eq('bind')
          end
        end
      end

      it "should generate PUSH-PULL brokered ZeroMQ connections for many-to-many inter-shard connections" do
        described_class.configure do |c|

          c.shard "s1", :process => 3 do |s|
            s.component 'first', 'First', :opt1 => 'opt1'
          end

          c.shard "s2", :process => 3 do |s|
            s.component 'second', 'Second', :opt1 => 'opt1', "opt2" => "opt2"
          end

          c.connect 'first#out' => 'second#in'
        end

        expect(Shard).to have(2).shards
        expect(Component).to have(2).components
        expect(Port).to have(2).ports
        expect(Connection).to have(1).connections

        Connection.first.tap do |conn|
          expect(conn.type).to eq('RFlow::Configuration::BrokeredZMQConnection')
          expect(conn.name).to eq('first#out=>second#in')
          expect(conn.output_port_key).to be_nil
          expect(conn.input_port_key).to be_nil
          conn.options.tap do |opts|
            expect(opts['output_socket_type']).to eq('PUSH')
            expect(opts['output_address']).to eq("ipc://rflow.#{conn.uuid}.in")
            expect(opts['output_responsibility']).to eq('connect')
            expect(opts['input_socket_type']).to eq('PULL')
            expect(opts['input_address']).to eq("ipc://rflow.#{conn.uuid}.out")
            expect(opts['input_responsibility']).to eq('connect')
          end
        end
      end

      it "should not allow two components with the same name" do
        expect {
          described_class.configure do |c|
            c.component 'first', 'First'
            c.component 'first', 'First'
          end
        }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "should not allow two shards with the same name" do
        expect {
          described_class.configure do |c|
            c.shard("s1", :process => 2) {|c| c.component 'x', 'y' }
            c.shard("s1", :process => 2) {|c| c.component 'z', 'q' }
          end
        }.to raise_error
      end
    end
  end
end
