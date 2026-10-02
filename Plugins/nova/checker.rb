module Nova
  # Pre-flight check: pure functions over the cabinet's panel list.
  module Checker
    STRUCTURAL = %w[carcass shelf rail plinth back].freeze

    def self.check(prm)
      p = Cabinet.normalize(prm)
      issues = []
      add = ->(level, type, panel, msg) { issues << { level: level, type: type, panel: panel, message: msg } }
      t = p[:thickness]

      if p[:type] != 'panel'
        if p[:width] - 2 * t <= 50 || p[:height] - p[:toe_kick] - 2 * t <= 50
          add.('Error', 'Invalid dimensions', 'Cabinet', 'Cabinet is too small for its panel thickness / toe kick')
          return issues
        end
        add.('Warning', 'Missing parts', 'Back', 'Cabinet has no back panel') if p[:back] == 'none'
        space = (p[:height] - t) - (p[:toe_kick] + t) - p[:shelves] * t
        add.('Error', 'Insertion collisions', 'Shelves', 'Too many shelves for the inner height') if space / (p[:shelves] + 1) < 50
      end

      parts = Cabinet.panels(p)
      parts.each do |pn|
        next if Cabinet::HARDWARE_ROLES.include?(pn[:role])
        fronts = %w[door drawer_front decor].include?(pn[:role])
        dims = [pn[:w], pn[:d], pn[:h]]
        if dims.min < 8 && pn[:role] != 'back'
          add.('Error', 'Impossible drilling', pn[:name], 'Panel too thin to machine')
        elsif dims.sort[1] < 30 && !%w[back plinth decor rail].include?(pn[:role])
          add.('Error', 'Impossible drilling', pn[:name], 'Panel too narrow for hardware drilling')
        end
        if fronts && pn[:edge] != ['all']
          add.('Error', 'Wrong edge-banding', pn[:name], 'Visible front is not edge-banded on all sides')
        elsif pn[:role] == 'carcass' && pn[:edge].none? { |e| %w[front all].include?(e) }
          add.('Warning', 'Wrong edge-banding', pn[:name], 'Visible front edge is not banded')
        end
        next unless pn[:role] == 'door'
        add.('Error', 'Impossible drilling', pn[:name], 'Door under 16 mm cannot take a 35 mm hinge cup') if p[:thickness] < 16
        add.('Warning', 'Oversize door', pn[:name], 'Door wider than 600 mm') if pn[:w] > 600
        add.('Warning', 'Invalid grain panels', pn[:name], 'Door is wider than tall but grain runs vertically') if pn[:w] > pn[:h] && pn[:grain] == 'vertical'
      end

      solid = parts.select { |pn| STRUCTURAL.include?(pn[:role]) }
      solid.combination(2) do |a, b|
        if overlap?(a, b)
          add.('Error', 'Insertion collisions', "#{a[:name]} / #{b[:name]}", 'Panels overlap')
        end
      end
      issues
    end

    def self.overlap?(a, b)
      %i[x y z].zip(%i[w d h]).all? do |o, s|
        [a[o] + a[s], b[o] + b[s]].min - [a[o], b[o]].max > 0.01
      end
    end
  end
end
