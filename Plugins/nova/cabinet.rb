require 'json'

module Nova
  # Parametric cabinet model. `panels` is pure Ruby (mm, no SketchUp calls) so it can be
  # unit-tested; `build` / `update` turn the panel list into SketchUp groups.
  # Axes: x = width, y = depth (front at y 0, pointing -y), z = up.
  module Cabinet
    DICT = 'Nova'.freeze
    PART_ROLES = %w[carcass shelf rail plinth back door drawer_front decor].freeze
    HARDWARE_ROLES = %w[handle hinge leg].freeze

    DEFAULTS = {
      type: 'base', width: 600, height: 720, depth: 560, thickness: 18, toe_kick: 100,
      back: 'inset', back_thickness: 6, shelves: 1, doors: 2, drawers: 0, drawer_height: 180,
      gap: 3, hinge: 'left', handle: 'profile', handle_pos: 'top', handle_orient: 'vertical',
      handle_offset: 50, edge_banding: true, toe: 'legs',
      carcass_material: 'MATTE WHITE CHIPBOARD', door_material: 'Tuscan Oak',
      carcass_edge: 'MATTE WHITE EDGE BAND', door_edge: 'MATTE WHITE EDGE BAND'
    }.freeze

    # Material names / colours taken from the reference model (60cm single door cabinet).
    MATERIALS = {
      'MATTE WHITE CHIPBOARD' => [209, 209, 209], 'MATTE WHITE EDGE BAND' => [255, 255, 255],
      'HG COOL GREY' => [94, 94, 94], 'HG COOL GREY EDGE BAND' => [117, 117, 117],
      'BACK PANEL' => [247, 221, 176], 'U PROFILE HANDLE' => [63, 63, 63],
      'Kitchen Legs' => [0, 194, 224], 'Tuscan Oak' => [219, 190, 157]
    }.freeze
    NUMERIC = %i[width height depth thickness toe_kick back_thickness drawer_height gap handle_offset].freeze
    INTEGER = %i[shelves doors drawers].freeze

    PRESETS = [
      { cat: 'Base',  name: 'Base 2 doors',   p: { type: 'base', width: 800, doors: 2, shelves: 1 } },
      { cat: 'Base',  name: 'Base 1 door',    p: { type: 'base', width: 450, doors: 1, shelves: 1 } },
      { cat: 'Base',  name: 'Base 3 drawers', p: { type: 'base', width: 600, doors: 0, drawers: 3, shelves: 0, handle_orient: 'horizontal', handle_pos: 'centre' } },
      { cat: 'Base',  name: 'Drawer + doors', p: { type: 'base', width: 800, doors: 2, drawers: 1, shelves: 1 } },
      { cat: 'Wall',  name: 'Wall 2 doors',   p: { type: 'wall', width: 800, height: 720, depth: 320, toe_kick: 0, doors: 2, shelves: 1, handle_pos: 'bottom' } },
      { cat: 'Wall',  name: 'Wall 1 door',    p: { type: 'wall', width: 400, height: 720, depth: 320, toe_kick: 0, doors: 1, shelves: 1, handle_pos: 'bottom' } },
      { cat: 'Tall',  name: 'Tall pantry',    p: { type: 'tall', width: 600, height: 2100, depth: 560, doors: 2, shelves: 4, handle_pos: 'centre' } },
      { cat: 'Tall',  name: 'Wardrobe',       p: { type: 'tall', width: 1000, height: 2300, depth: 600, doors: 2, shelves: 2, handle_pos: 'centre' } },
      { cat: 'Corner', name: 'Blind corner base', p: { type: 'base', width: 900, doors: 2, shelves: 1 } },
      { cat: 'Corner', name: 'Corner wall',  p: { type: 'wall', width: 600, height: 720, depth: 320, toe_kick: 0, doors: 1, shelves: 1, handle_pos: 'bottom' } },
      { cat: 'Decor', name: 'End panel',      p: { type: 'panel', width: 600, height: 720, thickness: 18 } },
      { cat: 'Decor', name: 'Pilaster',       p: { type: 'panel', width: 80, height: 2300, thickness: 30 } },
      { cat: 'Decor', name: 'Feature panel',  p: { type: 'panel', width: 1200, height: 2300, thickness: 18 } }
    ].freeze

    def self.normalize(prm)
      p = DEFAULTS.merge((prm || {}).each_with_object({}) { |(k, v), h| h[k.to_sym] = v })
      NUMERIC.each { |k| p[k] = p[k].to_f }
      INTEGER.each { |k| p[k] = p[k].to_i }
      p[:edge_banding] = p[:edge_banding] && p[:edge_banding].to_s != 'false'
      p
    end

    def self.part(name, role, x, y, z, w, d, h, o = {})
      { name: name, def: name, role: role, x: x, y: y, z: z, w: w, d: d, h: h,
        grain: 'vertical', material: 'MATTE WHITE CHIPBOARD', edge: ['none'], edge_material: nil }.merge(o)
    end

    def self.panels(prm)
      p = normalize(prm)
      w, h, d, t = p.values_at(:width, :height, :depth, :thickness)
      edge = ->(sides) { p[:edge_banding] ? sides : ['none'] }
      cm = { material: p[:carcass_material], edge_material: p[:carcass_edge] }
      if p[:type] == 'panel'
        return [part('Panel', 'decor', 0, 0, 0, w, t, h, def: 'feature panel', material: p[:door_material],
                                                           edge_material: p[:door_edge], edge: edge.(['all']))]
      end

      kick = p[:toe_kick]
      overlay = p[:back] == 'overlay'
      bt = p[:back] == 'none' ? 0 : p[:back_thickness]
      body_d = d - (overlay ? bt : 0)
      inset = p[:back] == 'inset' ? bt : 0
      list = []
      list << part('Left side', 'carcass', 0, 0, 0, t, body_d, h, **cm, def: 'side panel', edge: edge.(['front']))
      list << part('Right side', 'carcass', w - t, 0, 0, t, body_d, h, **cm, def: 'side panel', edge: edge.(['front']))
      list << part('Bottom', 'carcass', t, 0, kick, w - 2 * t, body_d - inset, t, **cm, def: 'base panel', edge: edge.(['front']), grain: 'horizontal')
      if p[:type] == 'base'
        list << part('Front rail', 'rail', t, 0, h - t, w - 2 * t, 100, t, **cm, def: 'brace', grain: 'horizontal')
        list << part('Back rail', 'rail', t, body_d - inset - 100, h - t, w - 2 * t, 100, t, **cm, def: 'brace', grain: 'horizontal')
      else
        list << part('Top', 'carcass', t, 0, h - t, w - 2 * t, body_d - inset, t, **cm, def: 'base panel', edge: edge.(['front']), grain: 'horizontal')
      end
      if kick > 0 && p[:type] != 'wall'
        if p[:toe] == 'plinth'
          list << part('Plinth', 'plinth', t, 60, 0, w - 2 * t, t, kick, **cm, def: 'plinth', grain: 'horizontal')
        elsif p[:toe] == 'legs'
          [[t + 10, 60], [w - t - 50, 60], [t + 10, body_d - inset - 100], [w - t - 50, body_d - inset - 100]]
            .each_with_index do |(lx, ly), i|
            list << part("Leg #{i + 1}", 'leg', lx, ly, 0, 40, 40, kick, def: 'KITCHEN LEG', material: 'Kitchen Legs', grain: 'none')
          end
        end
      end

      n = p[:shelves]
      space = (h - t) - (kick + t) - n * t
      n.times do |i|
        z = kick + t + (space / (n + 1)) * (i + 1) + t * i
        list << part("Shelf #{i + 1}", 'shelf', t, 0, z, w - 2 * t, body_d - inset - 20, t,
                     **cm, def: 'shelf', edge: edge.(['front']), grain: 'horizontal')
      end
      if overlay
        list << part('Back', 'back', 0, body_d, kick, w, bt, h - kick, def: back_name(w), material: 'BACK PANEL')
      elsif p[:back] == 'inset'
        list << part('Back', 'back', t, body_d - bt, kick + t, w - 2 * t, bt, h - kick - 2 * t, def: back_name(w), material: 'BACK PANEL')
      end
      list.concat(fronts(p, w, h, t, kick))
      list
    end

    def self.back_name(w)
      "#{(w / 10).round}CM CABINET BACKBOARD"
    end

    def self.fronts(p, w, h, t, kick)
      g = p[:gap]
      z0 = kick + g / 2
      z1 = h - g / 2
      avail = w - g
      out = []
      nd = p[:drawers]
      if nd > 0
        each = p[:doors] == 0 ? (z1 - z0 - (nd - 1) * g) / nd : p[:drawer_height]
        nd.times do |i|
          zi = z1 - (i + 1) * each - i * g
          out << part("Drawer #{i + 1}", 'drawer_front', g / 2, -t, zi, avail, t, each,
                      def: "#{(avail / 10).round}CM DRAWER FRONT", material: p[:door_material],
                      edge_material: p[:door_edge], grain: 'horizontal', edge: edge_all(p))
          out.concat(handle(p, "Drawer #{i + 1}", g / 2, zi, avail, each, t, nil))
        end
        z1 -= nd * (each + g) if p[:doors] > 0
      end
      doors = p[:doors]
      return out if doors == 0 || z1 - z0 <= 0
      dw = (avail - (doors - 1) * g) / doors
      doors.times do |j|
        x = g / 2 + j * (dw + g)
        name = "Door #{j + 1}"
        out << part(name, 'door', x, -t, z0, dw, t, z1 - z0, def: "#{(dw / 10).round}CM DOOR",
                                                              material: p[:door_material], edge_material: p[:door_edge], edge: edge_all(p))
        hinge = doors == 1 ? p[:hinge] : (j.even? ? 'left' : 'right')
        out.concat(handle(p, name, x, z0, dw, z1 - z0, t, hinge))
        count = (z1 - z0) > 1500 ? 3 : 2
        count.times do |k|
          z = k == 0 ? z0 + 100 : (k == count - 1 ? z1 - 135 : (z0 + z1) / 2 - 17.5)
          hx = hinge == 'left' ? x + 5 : x + dw - 40
          out << part("Hinge #{j + 1}-#{k + 1}", 'hinge', hx, -13, z, 35, 13, 35, def: 'hinge cup', material: 'HG COOL GREY', grain: 'none')
        end
      end
      out
    end

    def self.edge_all(p)
      p[:edge_banding] ? ['all'] : ['none']
    end

    # Handle rules: centre / offset from the free edge, vertical or horizontal.
    def self.handle(p, name, x, z, fw, fh, t, hinge)
      return [] if p[:handle] == 'none'
      horiz = hinge.nil? || p[:handle_orient] == 'horizontal'
      if p[:handle] == 'profile'
        # Profile handle running along the free edge (vertical) or the top edge (horizontal).
        if horiz
          return [part("Handle #{name}", 'handle', x, -t - 20, z + fh - 20, fw, 20, 20, def: 'profile handle single',
                                                    material: 'U PROFILE HANDLE', grain: 'none')]
        end
        hx = hinge == 'left' ? x + fw - 20 : x
        return [part("Handle #{name}", 'handle', hx, -t - 20, z, 20, 20, fh, def: 'profile handle single',
                                                  material: 'U PROFILE HANDLE', grain: 'none')]
      end
      knob = p[:handle] == 'knob'
      hw, hh = knob ? [30, 30] : (horiz ? [128, 10] : [10, 128])
      off = p[:handle_offset]
      hx = if hinge.nil?
             x + (fw - hw) / 2
           elsif hinge == 'left'
             x + fw - off - hw / 2
           else
             x + off - hw / 2
           end
      cz = case p[:handle_pos]
           when 'centre' then z + fh / 2
           when 'bottom' then z + off
           else z + fh - off
           end
      [part("Handle #{name}", 'handle', hx, -t - 25, cz - hh / 2, hw, 25, hh, def: knob ? 'knob' : 'bar handle',
                                                  material: 'U PROFILE HANDLE', grain: 'none')]
    end

    # ---- SketchUp side -------------------------------------------------------------

    def self.material(name)
      mats = Sketchup.active_model.materials
      mats[name] || mats.add(name).tap { |m| m.color = Sketchup::Color.new(*(MATERIALS[name] || [200, 200, 200])) }
    end

    # One shared component definition per distinct part (name, size, material, edging),
    # named like the reference model ('side panel', 'side panel#2', '30CM DOOR' ...).
    def self.definition_for(pn)
      model = Sketchup.active_model
      key = [pn[:def], pn[:w].round(2), pn[:d].round(2), pn[:h].round(2), pn[:material],
             pn[:edge_material], pn[:edge].join(',')].join('|')
      found = model.definitions.find { |d| d.get_attribute(DICT, 'key') == key }
      return found if found
      defn = model.definitions.add(pn[:def])
      defn.set_attribute(DICT, 'key', key)
      pts = [[0, 0], [pn[:w], 0], [pn[:w], pn[:d]], [0, pn[:d]]].map { |a, b| Geom::Point3d.new(a.mm, b.mm, 0) }
      f = defn.entities.add_face(pts)
      f.reverse! if f.normal.z < 0
      f.pushpull(pn[:h].mm)
      paint(defn, pn)
      defn
    end

    # Broad faces get the board material; edge faces get the edge-band material.
    def self.paint(defn, pn)
      faces = defn.entities.grep(Sketchup::Face)
      broad = faces.max_by(2, &:area)
      mat = material(pn[:material])
      emat = pn[:edge_material] ? material(pn[:edge_material]) : mat
      faces.each do |f|
        m = if broad.include?(f) then mat
            elsif pn[:edge] == ['all'] then emat
            elsif pn[:edge].include?('front') && f.normal.y < -0.99 then emat
            else mat
            end
        f.material = f.back_material = m
      end
    end

    def self.make_part(ents, pn)
      inst = ents.add_instance(definition_for(pn), Geom::Transformation.translation([pn[:x].mm, pn[:y].mm, pn[:z].mm]))
      inst.name = pn[:name]
      inst.set_attribute(DICT, 'role', pn[:role])
      inst.set_attribute(DICT, 'grain', pn[:grain])
      inst.set_attribute(DICT, 'material', pn[:material])
      inst.set_attribute(DICT, 'edge', pn[:edge].join(','))
      l, w, th = [pn[:w], pn[:d], pn[:h]].sort.reverse
      inst.set_attribute(DICT, 'dims', [l, w, th].map { |v| v.round(1) }.join('x'))
      inst
    end

    def self.fill(group, prm)
      panels(prm).each { |pn| make_part(group.entities, pn) }
      group.set_attribute(DICT, 'cabinet', true)
      group.set_attribute(DICT, 'params', JSON.generate(normalize(prm)))
      group.name = "#{normalize(prm)[:type].capitalize} #{normalize(prm)[:width].to_i}"
    end

    def self.build(prm, tr = nil)
      model = Sketchup.active_model
      model.start_operation('Insert cabinet', true)
      g = model.active_entities.add_group
      g.transformation = tr if tr
      fill(g, prm)
      model.commit_operation
      g
    end

    def self.cabinet?(e)
      e.is_a?(Sketchup::Group) && e.get_attribute(DICT, 'cabinet')
    end

    def self.params_of(group)
      normalize(JSON.parse(group.get_attribute(DICT, 'params', '{}')))
    end

    def self.cabinets(ents = Sketchup.active_model.active_entities)
      ents.select { |e| cabinet?(e) }
    end

    # Rebuild a cabinet from new parameters; optionally slide the rest of the run along.
    def self.update(group, prm, move_neighbours = true)
      model = Sketchup.active_model
      old = params_of(group)
      new = normalize(prm)
      model.start_operation('Update cabinet', true)
      group.entities.clear!
      fill(group, new)
      delta = new[:width] - old[:width]
      if move_neighbours && delta != 0
        ax = group.transformation.xaxis.normalize
        origin = group.transformation.origin
        cabinets(model.active_entities).each do |o|
          next if o == group
          rel = o.transformation.origin - origin
          next unless rel.dot(ax) >= old[:width].mm - 0.1.mm && rel.cross(ax).length < 1.mm
          o.transform!(Geom::Transformation.translation(ax.clone.tap { |v| v.length = delta.mm }))
        end
      end
      model.commit_operation
    end

    # Yields [part_group, parent_transformation] for every panel under `ents`.
    def self.each_panel(ents = Sketchup.active_model.active_entities, tr = Geom::Transformation.new, &blk)
      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        if PART_ROLES.include?(e.get_attribute(DICT, 'role'))
          blk.call(e, tr)
        else
          sub = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          each_panel(sub, tr * e.transformation, &blk)
        end
      end
    end
  end
end
