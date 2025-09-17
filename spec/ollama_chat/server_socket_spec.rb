require 'spec_helper'

describe OllamaChat::ServerSocket do
  let :instance do
    Object.extend(described_class)
  end

  describe '#send_to_server_socket' do
    let(:config) { double('Config') }
    let(:server) { double('Server') }

    context 'without runtime_dir' do

      before do
        expect(OllamaChat::ServerSocket).to receive(:create_socket_server).
          with(config: config, runtime_dir: nil, working_dir: nil).and_return(server)
      end

      context 'with default parameters' do
        it 'uses correct defaults' do
          message = { content: 'test', type: :socket_input, parse: false }

          expect(server).to receive(:transmit).with(message).and_return(nil)

          result = OllamaChat::ServerSocket.send_to_server_socket('test', config: config)

          expect(result).to be_nil
        end
      end

      context 'with :socket_input type and parse: true' do
        it 'sends message with parse flag and returns nil' do
          message = { content: 'test', type: :socket_input, parse: true }

          expect(server).to receive(:transmit).with(message).and_return(nil)

          result = OllamaChat::ServerSocket.send_to_server_socket(
            'test',
            config: config,
            type: :socket_input,
            parse: true
          )

          expect(result).to be_nil
        end
      end

      context 'with :socket_input_with_response type and parse: false' do
        it 'sends message and returns response with parse flag' do
          message = { content: 'test', type: :socket_input_with_response, parse: false }
          response = double('Response')

          expect(server).to receive(:transmit_with_response).with(message).
            and_return(response)

          result = OllamaChat::ServerSocket.send_to_server_socket(
            'test',
            config: config,
            type: :socket_input_with_response,
            parse: false
          )

          expect(result).to eq(response)
        end
      end

      context 'with :socket_input_with_response type and parse: true' do
        it 'sends message and returns response with parse flag' do
          message = { content: 'test', type: :socket_input_with_response, parse: true }
          response = double('Response')

          expect(server).to receive(:transmit_with_response).with(message).
            and_return(response)

          result = OllamaChat::ServerSocket.send_to_server_socket(
            'test',
            config: config,
            type: :socket_input_with_response,
            parse: true
          )

          expect(result).to eq(response)
        end
      end
    end

    context 'with working_dir' do
      before do
        expect(OllamaChat::ServerSocket).to receive(:create_socket_server).
          with(config: config, runtime_dir: nil, working_dir: 'foo/path').
          and_return(server)
      end

      context 'with working_dir parameter' do
        it 'uses correct parameter' do
          message = { content: 'test', type: :socket_input, parse: false }
          expect(server).to receive(:transmit).with(message).and_return(nil)

          result = OllamaChat::ServerSocket.send_to_server_socket(
            'test', config: config, working_dir: 'foo/path'
          )

          expect(result).to be_nil
        end
      end
    end

    context 'with runtime_dir parameter' do
      before do
        expect(OllamaChat::ServerSocket).to receive(:create_socket_server).
          with(config: config, runtime_dir: '/foo/bar', working_dir: nil).
          and_return(server)
      end

      it 'uses correct defaults' do
        message = { content: 'test', type: :socket_input, parse: false }

        expect(server).to receive(:transmit).with(message).and_return(nil)


        result = OllamaChat::ServerSocket.send_to_server_socket(
          'test', config: config, runtime_dir: '/foo/bar'
        )

        expect(result).to be_nil
      end
    end
  end

  describe '#create_socket_server' do
    context 'with working dir dependent socket' do
      it 'can be created with configured runtime_dir' do
        config = double('Config', working_dir_dependent_socket: true)
        expect(UnixSocks::Server).to receive(:new).with(
          socket_name: /\Aollama_chat-\h{32}.sock\z/,
        ).and_return :unix_socks_server

        result = OllamaChat::ServerSocket.create_socket_server(config: config)
        expect(result).to eq :unix_socks_server
      end
    end

    context 'with default runtime_dir and name' do
      it 'can be created with default runtime_dir' do
        config = double('Config', working_dir_dependent_socket: false)
        expect(UnixSocks::Server).to receive(:new).with(
          socket_name: 'ollama_chat.sock'
        ).and_return :unix_socks_server

        result = OllamaChat::ServerSocket.create_socket_server(config: config)
        expect(result).to eq :unix_socks_server
      end
    end
  end

  describe '#server_socket_message' do
    it 'can be set' do
      message = double('message')
      instance.server_socket_message = message
      expect(instance.server_socket_message).to eq(message)
    end

    it 'can be read' do
      message = double('message')
      instance.server_socket_message = message
      expect(instance.server_socket_message).to eq(message)
    end
  end

  describe '#init_server_socket' do
    it 'can be initialized' do
      config = double('Config')
      expect(instance).to receive(:config).and_return config
      server = double('Server', receive_in_background: :receive_in_background)
      expect(described_class).to receive(:create_socket_server).and_return server
      expect(instance.init_server_socket).to eq :receive_in_background
    end
  end
end
