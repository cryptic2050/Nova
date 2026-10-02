require 'json'

module Nova
  # id => [tooltip, icon file (without extension)]
  COMMANDS = {
    grain:   ['Grain matching',        'grain'],
    door:    ['Open / close doors',    'door'],
    quick:   ['Quick toolbar (radial)', 'quick'],
    nesting: ['Nesting layout',        'nesting'],
    settings:['Settings',              'settings'],
    check:   ['Check model',           'check']
  }.freeze

  def self.icon(name)
    File.join(PLUGIN_ROOT, 'icons', "#{name}.svg")
  end

  def self.run(id)
    case id
    when :grain   then Sketchup.active_model.select_tool(Tools::GrainMatch.new)
    when :door    then Sketchup.active_model.select_tool(Tools::DoorToggle.new)
    when :quick   then UI::QuickToolbar.show
    when :nesting then UI::Nesting.show
    when :settings, :check
      ::UI.messagebox("#{COMMANDS[id][0]}: not implemented yet.")
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

  require File.join(PLUGIN_ROOT, 'tools', 'grain_match')
  require File.join(PLUGIN_ROOT, 'tools', 'door_toggle')
  require File.join(PLUGIN_ROOT, 'ui', 'quick_toolbar')
  require File.join(PLUGIN_ROOT, 'ui', 'nesting')

  unless file_loaded?(__FILE__)
    # Two rows, like the reference: main tools on top, panel tools below.
    [['Nova', %i[settings nesting grain door check]],
     ['Nova Quick', %i[quick]]].each do |name, ids|
      tb = ::UI::Toolbar.new(name)
      ids.each { |i| tb.add_item(command(i)) }
      tb.show
    end
    menu = ::UI.menu('Extensions').add_submenu('Nova')
    COMMANDS.each_key { |i| menu.add_item(command(i)) }
    file_loaded(__FILE__)
  end
end
