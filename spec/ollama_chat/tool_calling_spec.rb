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

  describe '#list_tools' do
    it 'prints a formatted list of tools with their status' do
      chat.session.tools_default_enabled = { 'read_file' => true, 'write_file' => false }

      # We expect to see ✓ for read_file and ☐ for write_file
      expect { chat.list_tools }.to output(/✓ .*read_file.*☐ .*write_file/m).to_stdout
    end
  end

  describe '#enable_tool' do
    it 'updates the session when a tool is selected from the menu' do
      target_tool = chat.configured_tools.find { |t| !chat.session.tools_default_enabled[t] }
      expect(target_tool).to be_present

      # Mock choose_entry to return the target tool
      expect(chat).to receive(:choose_entry).and_return(target_tool, '[EXIT]')

      expect { chat.enable_tool }.to change {
        chat.session.tools_default_enabled[target_tool]
      }.from(false).to(true)
    end

    it 'warns the user if saving the session fails' do
      target_tool = chat.configured_tools.find { |t| !chat.session.tools_default_enabled[t] }
      expect(target_tool).to be_present

      expect(chat).to receive(:choose_entry).and_return(target_tool, '[EXIT]')
      expect(chat.session).to receive(:save).and_return(false)
      expect(STDOUT).to receive(:puts).with(/Could not enable tool/)
      expect(chat).to receive(:confirm?).and_return(true)
      expect(STDOUT).to receive(:puts).with(/Exiting chooser./)
      chat.enable_tool
    end

    it 'exits without and changes when [EXIT] is chosen' do
      expect(chat).to receive(:choose_entry).and_return('[EXIT]')
      initial_state = chat.session.tools_default_enabled.dup
      chat.enable_tool
      expect(chat.session.tools_default_enabled).to eq(initial_state)
    end
  end

  describe '#disable_tool' do
    it 'updates the session when a tool is deselected' do
      target_tool = chat.configured_tools.first
      chat.session.tools_default_enabled[target_tool] = true

      expect(chat).to receive(:choose_entry).and_return(target_tool, '[EXIT]')

      expect { chat.disable_tool }.to change {
        chat.session.tools_default_enabled[target_tool]
      }.from(true).to(false)
    end

    it 'warns the user if saving the session fails' do
      target_tool = chat.configured_tools.find { |t| chat.session.tools_default_enabled[t] }
      expect(target_tool).to be_present

      chat.session.tools_default_enabled[target_tool] = true
      expect(chat).to receive(:choose_entry).and_return(target_tool, '[EXIT]')
      expect(chat.session).to receive(:save).and_return(false)
      expect(STDOUT).to receive(:puts).with(/Could not disable tool/)
      expect(chat).to receive(:confirm?).and_return(true)
      expect(STDOUT).to receive(:puts).with(/Exiting chooser./)
      chat.disable_tool
    end
  end

  describe '#tool_paths_allowed' do
    it 'returns a mapping of enabled tools to expanded existing paths' do
      tool_name = chat.configured_tools.find { |t| chat.tool_function(t)[:allowed].present? }
      expect(tool_name).to be_present
      chat.session.tools_default_enabled[tool_name] = true
      paths = chat.tool_paths_allowed
      expect(paths).to have_key(tool_name)
      expect(paths[tool_name]).to be_an(Array)
    end
  end

  describe '#handle_tool_call_results?' do
    it 'yields tool results to the provided block and then clears them' do
      # Setup: inject tool results directly into the instance variable
      chat.instance_variable_set(:@tool_call_results, {
        'read_file' => ['Content of file A', 'Content of file B']
      })

      processed = []
      chat.send(:handle_tool_call_results?) do |index, tool, content|
        processed << { idx: index, t: tool, c: content }
      end

      expect(processed).to eq([
        { idx: 0, t: 'read_file', c: 'Content of file A' },
        { idx: 1, t: 'read_file', c: 'Content of file B' }
      ])
      # Verify the buffer was cleared
      expect(chat.instance_variable_get(:@tool_call_results)).to be_empty
    end

    it 'returns false if there are no results to process' do
      chat.instance_variable_set(:@tool_call_results, {})
      expect(chat.send(:handle_tool_call_results?) { }).to be false
    end
  end
end
