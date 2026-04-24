# VBO SkAgent Skill: Model Traversal
# Version: 1.0.0 | License: free | Safety: query
# Duyệt đệ quy entities trong selection — trả về pid paths

module TraverseModel
  def self.run(types: nil, depth: -1, include_hidden: false)
    model = Sketchup.active_model
    sel = model.selection.to_a
    return { count: 0, entities: [], duration_ms: 0 } if sel.empty?

    results = []
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    sel.each {|e|
      next if !include_hidden && (e.hidden? || !e.layer.visible?)
      collect([e], types, depth, include_hidden, results)
    }

    duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round
    { count: results.length, entities: results, duration_ms: duration }
  end

  def self.collect(path, types, max_depth, include_hidden, results)
    e = path[-1]
    type_str = e.class.name.split('::').last

    if types.nil? || types.include?(type_str)
      results << path.map(&:persistent_id)
    end

    return unless e.respond_to?(:definition)
    return unless max_depth == -1 || path.length < max_depth

    e.definition.entities.each {|child|
      next if !include_hidden && (child.hidden? || !child.layer.visible?)
      collect(path + [child], types, max_depth, include_hidden, results)
    }
  end

  private_class_method :collect
end
