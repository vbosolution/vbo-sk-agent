Sketchup.require File.join(File.dirname(__FILE__), 'config')
Sketchup.require File.join(File.dirname(__FILE__), 'bridge')
Sketchup.require File.join(File.dirname(__FILE__), 'skills_loader')
Sketchup.require File.join(File.dirname(__FILE__), 'mcp', 'server')

module VBO::SkAgent
  file = __FILE__
  unless file_loaded?(file)

    # --- Menu ---
    menu = UI.menu('Extensions').add_submenu('VBO SkAgent')
    menu.add_item('Toggle Bridge (File-based)') { Bridge.toggle }
    cmd_mcp_menu = menu.add_item('Toggle MCP Server') {
      McpServer.running ? McpServer.stop : McpServer.start
    }
    menu.set_validation_proc(cmd_mcp_menu) {
      McpServer.running ? MF_CHECKED : MF_UNCHECKED
    }
    menu.add_item('Dashboard') { Dashboard.toggle }
    menu.add_separator
    cmd_safety = menu.add_item('Safety Mode') {
      current = Config.get('safety_mode')
      Config.set('safety_mode', !current)
    }
    menu.set_validation_proc(cmd_safety) {
      Config.get('safety_mode') ? MF_CHECKED : MF_UNCHECKED
    }

    # --- Toolbar ---
    tb = UI::Toolbar.new('VBO SkAgent')
    icons = File.join(__dir__, 'icons')

    cmd_toggle = UI::Command.new('Toggle Bridge') { Bridge.toggle }
    cmd_toggle.small_icon = File.join(icons, 'bridge.svg')
    cmd_toggle.large_icon = File.join(icons, 'bridge.svg')
    cmd_toggle.tooltip = 'Toggle File-based Bridge'
    cmd_toggle.status_bar_text = 'Connect/Disconnect File-based Bridge (always works, ~500ms)'
    cmd_toggle.set_validation_proc {
      Bridge.watching? ? MF_CHECKED : MF_UNCHECKED
    }
    tb.add_item(cmd_toggle)

    # MCP Server toggle (v1.2.0+) — fast transport, P50 ~13ms
    icon_mcp = File.join(icons, 'mcp.svg')
    icon_mcp = File.join(icons, 'bridge.svg') unless File.exist?(icon_mcp)
    cmd_mcp = UI::Command.new('Toggle MCP Server') {
      McpServer.running ? McpServer.stop : McpServer.start
    }
    cmd_mcp.small_icon = icon_mcp
    cmd_mcp.large_icon = icon_mcp
    cmd_mcp.tooltip = 'Toggle MCP Server'
    cmd_mcp.status_bar_text = 'Start/Stop MCP HTTP server on port 7891 (fast transport for Claude Code, Cursor)'
    cmd_mcp.set_validation_proc {
      McpServer.running ? MF_CHECKED : MF_UNCHECKED
    }
    tb.add_item(cmd_mcp)

    cmd_dash = UI::Command.new('Dashboard') { Dashboard.toggle }
    cmd_dash.small_icon = File.join(icons, 'dashboard.svg')
    cmd_dash.large_icon = File.join(icons, 'dashboard.svg')
    cmd_dash.tooltip = 'SkAgent Dashboard'
    cmd_dash.status_bar_text = 'View bridge status, paths, and command history'
    tb.add_item(cmd_dash)

    UI.start_timer(0.1, false) { tb.restore }

    # --- Load Skills ---
    UI.start_timer(0.5, false) { SkillsLoader.load_all }

    # --- Auto-start MCP Server (v1.2.0+) ---
    UI.start_timer(1.5, false) {
      begin
        if Config.get('mcp_auto_start') && Config.get('transport_mode') != 'file_only'
          McpServer.start
        end
      rescue => e
        puts "[SkAgent] MCP auto-start failed: #{e.class}: #{e.message}"
      end
    }

    file_loaded(file)
  end

  # --- Dashboard ---
  module Dashboard
    @dialog = nil unless defined?(@dialog)

    def self.toggle
      if @dialog && @dialog.visible?
        @dialog.close
        return
      end

      # Center on screen for first launch
      w, h = 480, 580
      screen_w = [1920, (UI.respond_to?(:desktop_rect) ? UI.desktop_rect[2] : 1920)].min
      screen_h = [1080, (UI.respond_to?(:desktop_rect) ? UI.desktop_rect[3] : 1080)].min
      cx = [(screen_w - w) / 2, 0].max
      cy = [(screen_h - h) / 2, 0].max

      @dialog = UI::HtmlDialog.new(
        dialog_title: 'VBO SkAgent',
        width: w,
        height: h,
        left: cx,
        top: cy,
        resizable: true,
        style: UI::HtmlDialog::STYLE_DIALOG,
        preferences_key: 'VBO_SkAgent_Dashboard',
      )

      html_path = File.join(__dir__, 'ui', 'dashboard.html')
      @dialog.set_file(html_path)

      # --- Callbacks ---
      @dialog.add_action_callback('get_status') {|_ctx|
        json = Bridge.status_info.to_json
        @dialog.execute_script("updateStatus(#{json})")
      }

      @dialog.add_action_callback('toggle_bridge') {|_ctx|
        Bridge.toggle
        json = Bridge.status_info.to_json
        @dialog.execute_script("updateStatus(#{json})")
      }

      @dialog.add_action_callback('toggle_mcp') {|_ctx|
        Bridge.toggle_mcp
        json = Bridge.status_info.to_json
        @dialog.execute_script("updateStatus(#{json})")
      }

      @dialog.add_action_callback('set_transport_mode') {|_ctx, mode|
        valid = %w[auto mcp_only file_only]
        next unless valid.include?(mode)
        Config.set('transport_mode', mode)
        # Apply ngay: nếu mode chuyển sang file_only mà MCP đang chạy → stop
        if mode == 'file_only' && defined?(McpServer) && McpServer.running
          McpServer.stop
        elsif mode != 'file_only' && defined?(McpServer) && !McpServer.running && Config.get('mcp_auto_start')
          begin; McpServer.start; rescue => e; puts "[SkAgent] MCP start failed: #{e.message}"; end
        end
        json = Bridge.status_info.to_json
        @dialog.execute_script("updateStatus(#{json})")
      }

      @dialog.add_action_callback('set_mcp_port') {|_ctx, port|
        port_i = port.to_i
        next unless port_i >= 1024 && port_i <= 65535
        Config.set('mcp_port', port_i)
        # Restart MCP để apply port mới (nếu đang chạy)
        if defined?(McpServer) && McpServer.running
          McpServer.stop
          UI.start_timer(0.3, false) {
            begin; McpServer.start; rescue => e; puts "[SkAgent] MCP restart failed: #{e.message}"; end
            json = Bridge.status_info.to_json
            @dialog.execute_script("updateStatus(#{json})") rescue nil
          }
        end
        json = Bridge.status_info.to_json
        @dialog.execute_script("updateStatus(#{json})")
      }

      @dialog.add_action_callback('toggle_safety') {|_ctx|
        current = Config.get('safety_mode')
        Config.set('safety_mode', !current)
        json = Bridge.status_info.to_json
        @dialog.execute_script("updateStatus(#{json})")
      }

      @dialog.add_action_callback('toggle_console') {|_ctx|
        SKETCHUP_CONSOLE.visible? ? SKETCHUP_CONSOLE.hide : SKETCHUP_CONSOLE.show
      }

      @dialog.add_action_callback('clear_console') {|_ctx|
        SKETCHUP_CONSOLE.clear
      }

      @dialog.add_action_callback('open_templates') {|_ctx|
        templates_dir = File.join(__dir__, 'templates')
        UI.openURL("file:///#{templates_dir.tr('\\', '/')}")
      }

      @dialog.add_action_callback('open_plugins_folder') {|_ctx|
        UI.openURL("file:///#{Bridge.plugins_dir_path}")
      }

      @dialog.show
    end
  end
end
