module Nova
  module Tools
    # Draws a red square badge on every panel that has a pre-flight issue.
    class Indicators
      RED = Sketchup::Color.new(230, 40, 40)

      def initialize(issues)
        @pts = []
        model = Sketchup.active_model
        issues.each do |i|
          cab = model.find_entity_by_id(i[:cid])
          next unless cab
          tr = cab.transformation
          names = i[:panel].split(' / ')
          cab.entities.each do |e|
            @pts << (tr * e.bounds.center) if names.include?(e.name) || i[:panel] == 'Cabinet' && Cabinet::PART_ROLES.include?(e.get_attribute(Cabinet::DICT, 'role'))
          end
        end
        @pts.uniq!
      end

      def activate
        Sketchup.status_text = 'Panels with issues are marked. Press Space to exit.'
        Sketchup.active_model.active_view.invalidate
      end

      def deactivate(view)
        view.invalidate
      end

      def onKeyDown(key, _r, _f, _v)
        Sketchup.active_model.select_tool(nil) if key == 32
      end

      def draw(view)
        view.draw_points(@pts, 12, 2, RED) unless @pts.empty?
      end
    end
  end
end
