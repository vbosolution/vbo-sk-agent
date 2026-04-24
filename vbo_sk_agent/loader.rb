Sketchup.require File.join(File.dirname(__FILE__), 'config')
Sketchup.require File.join(File.dirname(__FILE__), 'bridge')
Sketchup.require File.join(File.dirname(__FILE__), 'skills_loader')

module VBO::SkAgent
  file = __FILE__
  unless file_loaded?(file)

    # --- Menu ---
    menu = UI.menu('Extensions').add_submenu('VBO SkAgent')
    menu.add_item('Toggle Bridge') { Bridge.toggle }
    menu.add_item('Dashboard')     { Dashboard.toggle }
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
    cmd_toggle.tooltip = 'Toggle AI Agent Bridge'
    cmd_toggle.status_bar_text = 'Connect/Disconnect AI Agent Bridge'
    cmd_toggle.set_validation_proc {
      Bridge.watching? ? MF_CHECKED : MF_UNCHECKED
    }
    tb.add_item(cmd_toggle)

    cmd_dash = UI::Command.new('Dashboard') { Dashboard.toggle }
    cmd_dash.small_icon = File.join(icons, 'dashboard.svg')
    cmd_dash.large_icon = File.join(icons, 'dashboard.svg')
    cmd_dash.tooltip = 'SkAgent Dashboard'
    cmd_dash.status_bar_text = 'View bridge status, paths, and command history'
    tb.add_item(cmd_dash)

    UI.start_timer(0.1, false) { tb.restore }

    # --- Load Skills ---
    UI.start_timer(0.5, false) { SkillsLoader.load_all }

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
