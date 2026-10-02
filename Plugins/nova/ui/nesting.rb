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

      # Collect panels carrying a Nova material attribute into sheets (placeholder packer).
      def self.sheets
        parts = Sketchup.active_model.active_entities.select do |e|
          (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance))
        end.map do |e|
          dims = [e.bounds.width, e.bounds.height, e.bounds.depth].map { |v| v.to_mm.round(1) }.sort
          { name: e.name.to_s, w: dims[2], h: dims[1], t: dims[0], material: (e.material&.name || 'Default') }
        end
        { board: [2440, 1300], parts: parts }
      end
    end
  end
end
