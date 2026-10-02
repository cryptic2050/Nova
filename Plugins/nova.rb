# Nova - cabinet design toolkit for SketchUp (registrar)
require 'sketchup.rb'
require 'extensions.rb'

module Nova
  PLUGIN_ROOT = File.join(File.dirname(__FILE__), 'nova').freeze

  unless file_loaded?(__FILE__)
    ex = SketchupExtension.new('Nova', File.join(PLUGIN_ROOT, 'main'))
    ex.description = 'Cabinet design toolbars, grain matching, door tools, quick radial menu and nesting layout.'
    ex.version     = '0.1.0'
    ex.creator     = 'Nova'
    Sketchup.register_extension(ex, true)
    file_loaded(__FILE__)
  end
end
