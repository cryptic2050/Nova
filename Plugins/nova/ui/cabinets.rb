module Nova
  module UI
    # Library (left) + single parameter panel (right). Selecting a Nova cabinet loads its
    # parameters; "Apply" re-stretches it (and the rest of the run), "Insert" adds a new one.
    module Cabinets
      class SelObserver < Sketchup::SelectionObserver
        def onSelectionBulkChange(sel)
          Cabinets.push(sel)
        end
      end

      def self.show
        @dlg ||= begin
          d = ::UI::HtmlDialog.new(dialog_title: 'Nova Cabinets', width: 980, height: 640,
                                   resizable: true, style: ::UI::HtmlDialog::STYLE_DIALOG)
          d.set_file(File.join(PLUGIN_ROOT, 'ui', 'cabinets.html'))
          d.add_action_callback('ready') do |_c, _|
            d.execute_script("Nova.init(#{{ defaults: Cabinet::DEFAULTS, presets: Cabinet::PRESETS }.to_json})")
            push(Sketchup.active_model.selection)
          end
          d.add_action_callback('insert') { |_c, json| insert(JSON.parse(json)) }
          d.add_action_callback('apply') { |_c, json, move| apply(JSON.parse(json), move == 'true') }
          d.set_on_closed { Sketchup.active_model.selection.remove_observer(@obs) if @obs }
          d
        end
        @obs ||= SelObserver.new
        Sketchup.active_model.selection.add_observer(@obs)
        @dlg.visible? ? @dlg.bring_to_front : @dlg.show
      end

      def self.push(sel)
        return unless @dlg && @dlg.visible?
        g = sel.length == 1 && Cabinet.cabinet?(sel.first) ? sel.first : nil
        @dlg.execute_script("Nova.selected(#{g ? Cabinet.params_of(g).to_json : 'null'})")
      end

      # New cabinets are placed to the right of the last one so a run builds up naturally.
      def self.insert(prm)
        last = Cabinet.cabinets.max_by { |c| c.bounds.max.x }
        x = last ? last.bounds.max.x : 0
        g = Cabinet.build(prm, Geom::Transformation.translation([x, 0, 0]))
        Sketchup.active_model.selection.clear
        Sketchup.active_model.selection.add(g)
      end

      def self.apply(prm, move)
        sel = Sketchup.active_model.selection.grep(Sketchup::Group).select { |g| Cabinet.cabinet?(g) }
        return ::UI.messagebox('Select a Nova cabinet first.') if sel.empty?
        sel.each { |g| Cabinet.update(g, prm, move) }
      end
    end

    # Pre-flight check: table of Error / Warning rows; clicking a row selects the cabinet.
    module Preflight
      def self.show
        @dlg ||= begin
          d = ::UI::HtmlDialog.new(dialog_title: 'Nova Pre-flight Check', width: 640, height: 520,
                                   resizable: true, style: ::UI::HtmlDialog::STYLE_DIALOG)
          d.set_file(File.join(PLUGIN_ROOT, 'ui', 'preflight.html'))
          d.add_action_callback('ready') { |_c, _| refresh }
          d.add_action_callback('rerun') { |_c, _| refresh }
          d.add_action_callback('select') { |_c, id| select(id.to_i) }
          d.add_action_callback('indicators') { |_c, _| Sketchup.active_model.select_tool(Tools::Indicators.new(issues)) }
          d
        end
        @dlg.visible? ? @dlg.bring_to_front : @dlg.show
      end

      def self.issues
        Cabinet.cabinets.flat_map do |g|
          Checker.check(Cabinet.params_of(g)).map { |i| i.merge(cabinet: g.name, cid: g.entityID) }
        end
      end

      def self.refresh
        @dlg.execute_script("Nova.load(#{issues.to_json})")
      end

      def self.select(id)
        model = Sketchup.active_model
        e = model.find_entity_by_id(id)
        return unless e
        model.selection.clear
        model.selection.add(e)
        model.active_view.zoom(e)
      end
    end

    # Label sheet with a QR payload per panel (A1, A2, B1 ... per cabinet).
    module Labels
      def self.show
        @dlg ||= begin
          d = ::UI::HtmlDialog.new(dialog_title: 'Nova Labels', width: 760, height: 620,
                                   resizable: true, style: ::UI::HtmlDialog::STYLE_DIALOG)
          d.set_file(File.join(PLUGIN_ROOT, 'ui', 'labels.html'))
          d.add_action_callback('ready') { |_c, _| d.execute_script("Nova.load(#{labels.to_json})") }
          d
        end
        @dlg.visible? ? @dlg.bring_to_front : @dlg.show
      end

      def self.labels
        Cabinet.cabinets.each_with_index.flat_map do |g, ci|
          letter = ('A'.ord + ci % 26).chr
          i = 0
          g.entities.select { |e| Cabinet::PART_ROLES.include?(e.get_attribute(Cabinet::DICT, 'role')) }.map do |e|
            i += 1
            d = ->(k) { e.get_attribute(Cabinet::DICT, k).to_s }
            { id: "#{letter}#{i}", cabinet: g.name, part: e.name, dims: d.('dims'),
              material: d.('material'), edge: d.('edge'), grain: d.('grain'),
              qr: "#{g.name}|#{letter}#{i}|#{e.name}|#{d.('dims')}|#{d.('material')}" }
          end
        end
      end
    end
  end
end
