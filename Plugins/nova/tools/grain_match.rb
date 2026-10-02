module Nova
  module Tools
    # Click panels to mark them as one grain-matched set. Panels are tinted
    # blue with a red dashed outline and labelled A1, A2, B1 ... per cabinet.
    # Space exits, right-click confirms.
    class GrainMatch
      MAX_PANEL_THICKNESS = 50.mm
      PURPLE = Sketchup::Color.new(120, 30, 190)
      BLUE   = Sketchup::Color.new(60, 110, 200, 200)
      RED    = Sketchup::Color.new(220, 40, 40)
      STATUS = 'Pick the panel or part'.freeze

      def activate
        @picked = []
        @hover = nil
        Sketchup.status_text = STATUS
        Sketchup.active_model.active_view.invalidate
      end

      def deactivate(view)
        view.invalidate
      end

      def resume(view)
        Sketchup.status_text = STATUS
        view.invalidate
      end

      def onSetCursor
        true
      end

      def onMouseMove(_flags, x, y, view)
        @hover = panel_at(view, x, y)
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        p = panel_at(view, x, y)
        return unless p
        @picked.include?(p) ? @picked.delete(p) : @picked << p
        view.invalidate
      end

      def onRButtonDown(_flags, _x, _y, view)
        confirm(view)
      end

      def onKeyDown(key, _repeat, _flags, view)
        Sketchup.active_model.select_tool(nil) if key == 32
      end

      def onCancel(_reason, view)
        @picked.clear
        view.invalidate
      end

      def draw(view)
        draw_panel(view, @hover, BLUE, false) if @hover && !@picked.include?(@hover)
        @picked.each { |p| draw_panel(view, p, BLUE, true) }
        draw_labels(view)
        draw_help(view)
      end

      private

      def panels
        @panels ||= Sketchup.active_model.active_entities.select { |e| panel?(e) }
      end

      def panel?(e)
        return false unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        b = e.bounds
        [b.width, b.height, b.depth].min <= MAX_PANEL_THICKNESS
      end

      def panel_at(view, x, y)
        ph = view.pick_helper
        ph.do_pick(x, y)
        ph.all_picked.find { |e| panel?(e) }
      end

      # Front-most bounding-box face as seen from the camera.
      def face_points(view, ent)
        b = ent.bounds
        axis = [b.width, b.height, b.depth].each_with_index.min[1]
        eye = view.camera.eye
        pts = case axis
              when 0 then x = (eye.x > b.center.x ? b.max.x : b.min.x)
                          [[x, b.min.y, b.min.z], [x, b.max.y, b.min.z], [x, b.max.y, b.max.z], [x, b.min.y, b.max.z]]
              when 1 then y = (eye.y > b.center.y ? b.max.y : b.min.y)
                          [[b.min.x, y, b.min.z], [b.max.x, y, b.min.z], [b.max.x, y, b.max.z], [b.min.x, y, b.max.z]]
              else        z = (eye.z > b.center.z ? b.max.z : b.min.z)
                          [[b.min.x, b.min.y, z], [b.max.x, b.min.y, z], [b.max.x, b.max.y, z], [b.min.x, b.max.y, z]]
              end
        pts.map { |a| Geom::Point3d.new(*a) }
      end

      def draw_panel(view, ent, color, outline)
        pts = face_points(view, ent)
        view.drawing_color = color
        view.draw(GL_QUADS, pts)
        return unless outline
        view.line_stipple = '-'
        view.line_width = 2
        view.drawing_color = RED
        view.draw(GL_LINE_LOOP, pts)
        view.line_stipple = ''
      end

      def label_for(ent)
        i = panels.index(ent) || 0
        "#{('A'.ord + i / 10).chr}#{i % 10 + 1}"
      end

      def draw_labels(view)
        opts = { color: PURPLE, size: 14, bold: false }
        @picked.each do |p|
          c = view.screen_coords(p.bounds.center)
          view.draw_text(Geom::Point3d.new(c.x - 8, c.y - 8, 0), label_for(p), opts)
        end
      end

      def draw_help(view)
        opts = { color: PURPLE, size: 10 }
        lines = [
          'Click a panel or door panel to configure settings',
          'Press Space to exit current operation',
          "Total of #{@picked.size} matching-grain objects",
          'After clicking the matching-grain panel, right-click to confirm'
        ]
        lines.each_with_index do |t, i|
          view.draw_text(Geom::Point3d.new(view.vpwidth * 0.45, 40 + i * 16, 0), t, opts)
        end
      end

      def confirm(view)
        return if @picked.size < 2
        model = Sketchup.active_model
        model.start_operation('Match grain', true)
        set_id = "grain-#{Time.now.to_i}"
        @picked.each { |p| p.set_attribute('Nova', 'grain_set', set_id) }
        model.commit_operation
        @picked.clear
        view.invalidate
      end
    end
  end
end
