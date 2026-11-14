describe OllamaChat::ToolCalling do
  let :chat do
    OllamaChat::Chat.new(argv: chat_default_config).expose
  end

  connect_to_ollama_server

  describe '#tool_configured?' do
    it 'returns true if the tool is in the configuration' do
      # Assuming a standard tool like 'read_file' is in default config
      expect(chat.tool_configured?('read_file')).to be true
    end

    it 'returns false if the tool is not in the configuration' do
      expect(chat.tool_configured?('non_existent_tool')).to be false
    end
  end

  describe '#tool_function' do
    it 'retrieves the configuration object for a valid tool' do
      func = chat.tool_function('read_file')
      expect(func).not_to be_nil
      expect(func).to respond_to(:require_confirmation?)
    end
  end

  describe '#tool_registered?' do
    it 'returns true for tools registered in the global registry' do
      expect(chat.tool_registered?('read_file')).to be true
    end

    it 'returns false for unregistered tools' do
      expect(chat.tool_registered?('ghost_tool')).to be false
    end
  end

  describe '#enabled_tools' do
    it 'returns a list of tools that are both configured and enabled in the session' do
      # Set up specific state in the session
      chat.session.tools_default_enabled = { 'read_file' => true, 'write_file' => false }

      enabled = chat.enabled_tools
      expect(enabled).to include('read_file')
      expect(enabled).not_to include('write_file')
    end
  end

  describe '#tool_enabled?' do
    it 'returns true if the tool is enabled' do
      chat.session.tools_default_enabled['read_file'] = true
      expect(chat.tool_enabled?('read_file')).to be true
    end

    it 'returns false if the tool is disabled' do
      chat.session.tools_default_enabled['read_file'] = false
      expect(chat.tool_enabled?('read_file')).to be false
    end
  end

  describe '#tools' do
    it 'returns a list of hashes for enabled and registered tools' do
      expect(chat).to receive(:tools_support).and_return(double(off?: false))

      # Setup: one tool is both, one is only enabled (unregistered)
      chat.session.tools_default_enabled = { 'read_file' => true, 'ghost_tool' => true }

      tools_list = chat.tools
      expect(tools_list).to be_an(Array)
      # Only 'read_file' should make the cut since 'ghost_tool' isn't registered
      expect(tools_list.size).to eq(1)
      expect(tools_list.first).to be_a(Hash)
    end

    it 'returns an empty array if tool support is disabled' do
      # Mock the tools_support state to off
      expect(chat).to receive(:tools_support).and_return(double(off?: true))
      expect(chat.tools).to eq([])
    end
  end

  describe '#default_enabled_tools' do
    it 'returns configured tools that are marked as default and are registered' do
      defaults = chat.default_enabled_tools
      expect(defaults).to be_an(Array)
      # Verify that every returned tool is actually registered
      defaults.each { |t| expect(chat.tool_registered?(t)).to be true }
    end
  end

  describe '#configured_tools' do
    it 'returns a sorted list of all tools defined in the config' do
      tools = chat.configured_tools
      expect(tools).to be_an(Array)
      expect(tools).to eq(tools.sort)
    end
  end

  describe '#choose_tools' do
    wrapper = ->(name) { SearchUI::Wrapper.new(name) }

    it 'updates the session when tools are toggled' do
      to_enable = chat.configured_tools.find {
        !chat.session.tools_default_enabled[_1]
      }
      to_disable = chat.configured_tools.find {
        chat.session.tools_default_enabled[_1]
      }
      expect(to_enable).to be_present
      expect(to_disable).to be_present

      new_picked = chat.enabled_tools + [ to_enable ] - [ to_disable ]
      expect(chat).to receive(:choose_multi).
        and_return(new_picked.map(&wrapper))

      chat.choose_tools

      expect(chat.session.tools_default_enabled[to_enable]).to be true
      expect(chat.session.tools_default_enabled[to_disable]).to be false
    end

    it 'aborts without changes when the user presses C-c' do
      expect(chat).to receive(:choose_multi).and_return(nil)
      initial_state = chat.session.tools_default_enabled.dup
      chat.choose_tools
      expect(chat.session.tools_default_enabled).to eq(initial_state)
    end

    it 'does not save if nothing changed' do
      expect(chat).to receive(:choose_multi).
        and_return(chat.enabled_tools.map(&wrapper))
      expect(chat.session).not_to receive(:save)
      chat.choose_tools
    end
  end
end
