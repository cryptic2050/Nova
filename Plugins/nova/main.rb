require 'json'

module Nova
  # id => [tooltip, icon file (without extension)]
  COMMANDS = {
    cabinets:  ['Cabinet library & parameters', 'cabinets'],
    grain:     ['Grain matching',               'grain'],
    door:      ['Open / close doors',           'door'],
    labels:    ['Labels & QR codes',            'labels'],
    preflight: ['Pre-flight check',             'preflight'],
    nesting:   ['Nesting layout',               'nesting'],
    quick:     ['Quick toolbar (radial)',       'quick'],
    settings:  ['Settings',                     'settings']
  }.freeze

  def self.icon(name)
    File.join(PLUGIN_ROOT, 'icons', "#{name}.svg")
  end

  def self.run(id)
    case id
    when :cabinets  then UI::Cabinets.show
    when :grain     then Sketchup.active_model.select_tool(Tools::GrainMatch.new)
    when :door      then Sketchup.active_model.select_tool(Tools::DoorToggle.new)
    when :labels    then UI::Labels.show
    when :preflight then UI::Preflight.show
    when :nesting   then UI::Nesting.show
    when :quick     then UI::QuickToolbar.show
    when :settings  then ::UI.messagebox("#{COMMANDS[id][0]}: not implemented yet.")
    end
  end

  def self.command(id)
    @commands ||= {}
    @commands[id] ||= begin
      tip, icon = COMMANDS[id]
      cmd = ::UI::Command.new(tip) { run(id) }
      cmd.tooltip = tip
      cmd.status_bar_text = tip
      cmd.small_icon = cmd.large_icon = icon(icon)
      cmd
    end
  end

  require File.join(PLUGIN_ROOT, 'cabinet')
  require File.join(PLUGIN_ROOT, 'checker')
  require File.join(PLUGIN_ROOT, 'tools', 'grain_match')
  require File.join(PLUGIN_ROOT, 'tools', 'door_toggle')
  require File.join(PLUGIN_ROOT, 'tools', 'indicators')
  require File.join(PLUGIN_ROOT, 'ui', 'quick_toolbar')
  require File.join(PLUGIN_ROOT, 'ui', 'nesting')
  require File.join(PLUGIN_ROOT, 'ui', 'cabinets')

  unless file_loaded?(__FILE__)
    [['Nova', %i[settings cabinets nesting labels preflight]],
     ['Nova Tools', %i[grain door quick]]].each do |name, ids|
      tb = ::UI::Toolbar.new(name)
      ids.each { |i| tb.add_item(command(i)) }
      tb.show
    end
    menu = ::UI.menu('Extensions').add_submenu('Nova')
    COMMANDS.each_key { |i| menu.add_item(command(i)) }
    file_loaded(__FILE__)
  end
end
