module Nova
  module UI
    # Dark nesting-layout window: sheet list on the left, sheet view on the right.
    module Nesting
      def self.show
        @dlg ||= begin
          d = ::UI::HtmlDialog.new(dialog_title: 'Nova Nesting', width: 1100, height: 700,
                                   resizable: true, style: ::UI::HtmlDialog::STYLE_DIALOG)
          d.set_file(File.join(PLUGIN_ROOT, 'ui', 'nesting.html'))
          d.add_action_callback('ready') { |_c, _| d.execute_script("Nova.load(#{sheets.to_json})") }
          d
        end
        @dlg.visible? ? @dlg.bring_to_front : @dlg.show
      end

      # Every panel (carcass, doors, backs ...) becomes a part to nest.
      def self.sheets
        parts = []
        Cabinet.each_panel do |e, _tr|
          dims = e.get_attribute(Cabinet::DICT, 'dims').to_s.split('x').map(&:to_f)
          next unless dims.size == 3
          parts << { name: e.name, w: dims[0], h: dims[1], t: dims[2], material: e.get_attribute(Cabinet::DICT, 'material').to_s }
        end
        { board: [2440, 1300], parts: parts }
      end
    end
  end
end
