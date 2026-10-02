module Nova
  module UI
    # Radial "QuickToolBar": circular buttons arranged in rings around the cursor.
    module QuickToolbar
      def self.show
        @dlg ||= begin
          d = ::UI::HtmlDialog.new(dialog_title: 'QuickToolBar', width: 420, height: 440,
                                   style: ::UI::HtmlDialog::STYLE_UTILITY)
          d.set_file(File.join(PLUGIN_ROOT, 'ui', 'quick_toolbar.html'))
          d.add_action_callback('run') { |_c, id| Nova.run(id.to_sym); d.close }
          d
        end
        @dlg.visible? ? @dlg.bring_to_front : @dlg.show
      end
    end
  end
end
