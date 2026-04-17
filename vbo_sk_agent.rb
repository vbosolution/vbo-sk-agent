module VBO
  module SkAgent
    PLUGIN_NAME    = 'VBO SkAgent'.freeze
    PLUGIN_VERSION = '1.0.0'.freeze

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new(PLUGIN_NAME, File.join(__dir__, 'vbo_sk_agent/loader'))
      ex.description = 'AI Agent Bridge for SketchUp — Let AI code your plugins in real-time.'
      ex.version     = PLUGIN_VERSION
      ex.copyright   = '2026 VBO — MIT License'
      ex.creator     = 'Lê Việt Trường (Tiger Le)'
      Sketchup.register_extension(ex, true)
    end
  end
end
file_loaded(__FILE__)
