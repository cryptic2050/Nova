module Nova
  module Tools
    # Click a door to swing it open / closed about its hinge edge.
    class DoorToggle
      STATUS = 'Click to activate.'.freeze
      OPEN_ANGLE = 100.degrees

      def activate
        Sketchup.status_text = STATUS
      end

      def resume(_view)
        Sketchup.status_text = STATUS
      end

      def onSetCursor
        true
      end

      def onKeyDown(key, _r, _f, _v)
        Sketchup.active_model.select_tool(nil) if key == 32
      end

      def onLButtonDown(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        door = ph.all_picked.find { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        return unless door
        toggle(door)
        view.invalidate
      end

      private

      def toggle(door)
        model = Sketchup.active_model
        model.start_operation('Toggle door', true)
        opened = door.get_attribute('Nova', 'open', false)
        b = door.bounds
        hinge = Geom::Point3d.new(b.min.x, b.min.y, b.min.z)
        angle = opened ? -OPEN_ANGLE : OPEN_ANGLE
        door.transform!(Geom::Transformation.rotation(hinge, Z_AXIS, angle))
        door.set_attribute('Nova', 'open', !opened)
        model.commit_operation
      end
    end
  end
end
