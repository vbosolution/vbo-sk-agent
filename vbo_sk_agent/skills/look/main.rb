# VBO SkAgent Skill: Look (Vision Capture + Ray Probe)
# Version: 1.1.0 | License: free | Safety: query
# Chụp viewport screenshot + extract context + bắn tia từ pixel → entity

require 'json'

module Look
  VISION_DIR = File.join(__dir__)

  # Lưu screenshot dimensions gần nhất để probe dùng
  @last_capture = { width: 1920, height: 1080 }

  def self.run(width: 1920, height: 1080, include_context: true, deep: false)
    model = Sketchup.active_model
    view = model.active_view
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # 1. Capture screenshot
    img_path = File.join(VISION_DIR, 'capture.png')
    view.write_image(
      filename: img_path,
      width: width,
      height: height,
      antialias: true,
      compression: 0.9
    )

    # 2. Copy to clipboard
    clipboard_ok = copy_to_clipboard(img_path)

    # 3. Extract context
    context = include_context ? extract_context(model, view, deep) : nil

    duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round

    # Lưu dimensions cho probe
    @last_capture = { width: width, height: height }

    result = {
      screenshot: img_path.tr('\\', '/'),
      clipboard: clipboard_ok,
      capture_size: [width, height],
      duration_ms: duration,
    }
    result[:context] = context if context
    result
  end

  # --- Probe: Bắn tia từ pixel trên screenshot → entity trong model ---

  def self.probe(px:, py:, capture_width: nil, capture_height: nil)
    model = Sketchup.active_model
    view = model.active_view

    cw = capture_width || @last_capture[:width]
    ch = capture_height || @last_capture[:height]

    # Scale screenshot pixel → viewport screen coords
    sx = px * (view.vpwidth.to_f / cw)
    sy = py * (view.vpheight.to_f / ch)

    probe_at(model, view, sx, sy, px, py)
  end

  def self.probe_many(points:, capture_width: nil, capture_height: nil)
    model = Sketchup.active_model
    view = model.active_view
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    cw = capture_width || @last_capture[:width]
    ch = capture_height || @last_capture[:height]

    scale_x = view.vpwidth.to_f / cw
    scale_y = view.vpheight.to_f / ch

    results = points.map {|pt|
      px, py = pt
      sx = px * scale_x
      sy = py * scale_y
      probe_at(model, view, sx, sy, px, py)
    }

    # Phân tích: group theo parent entity
    parents = {}
    results.each {|r|
      next unless r[:hit]
      # Parent = entity trước entity cuối trong path
      parent_key = if r[:pid_path].length > 1
                     r[:pid_path][-2]  # parent container
                   else
                     '__root__'        # top-level (loose geometry)
                   end
      parents[parent_key] ||= []
      parents[parent_key] << r
    }

    duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round

    {
      count: results.length,
      hits: results.count {|r| r[:hit] },
      misses: results.count {|r| !r[:hit] },
      probes: results,
      parent_groups: parents.map {|key, probes|
        {
          parent_pid: key,
          hit_count: probes.length,
          entity_types: probes.map {|p| p[:entity][:type] }.tally,
        }
      },
      duration_ms: duration,
    }
  end

  # --- Private ---

  def self.extract_context(model, view, deep)
    cam = view.camera
    sel = model.selection

    context = {
      model_name: model.title,
      model_path: model.path.empty? ? nil : model.path,
      camera: {
        eye: cam.eye.to_a.map {|v| v.to_f.round(2) },
        target: cam.target.to_a.map {|v| v.to_f.round(2) },
        up: cam.up.to_a.map {|v| v.to_f.round(3) },
        perspective: cam.perspective?,
        fov: cam.perspective? ? cam.fov.round(1) : nil,
      },
      selection_count: sel.count,
      entities: [],
    }

    # Entities to scan: selection nếu có, nếu không thì visible top-level
    items = sel.empty? ? model.active_entities.find_all {|e| e.visible? } : sel.to_a

    if deep
      # Scan sâu — dùng cùng algorithm với TraverseModel
      items.each {|e|
        next if !e.visible? || !e.layer.visible?
        collect_deep([e], context[:entities])
      }
    else
      # Top-level only
      items.each {|e|
        info = entity_info(e)
        context[:entities] << info if info
      }
    end

    context
  end

  def self.entity_info(e)
    return nil unless e.respond_to?(:bounds)
    bb = e.bounds

    info = {
      pid: (e.persistent_id rescue nil),
      type: e.class.name.split('::').last,
      name: (e.respond_to?(:name) ? e.name.to_s : ''),
      layer: e.layer.display_name,
      visible: e.visible?,
      bounds_center: bb.center.to_a.map {|v| v.to_f.round(1) },
      bounds_size: [bb.width.to_f.round(1), bb.depth.to_f.round(1), bb.height.to_f.round(1)],
    }

    if e.respond_to?(:definition)
      info[:definition_name] = e.definition.name
      info[:instance_count] = e.definition.count_used_instances
    end

    if e.is_a?(Sketchup::Face)
      info[:area] = e.area.to_f.round(1)
      info[:material] = e.material ? e.material.display_name : nil
    end

    info
  end

  def self.collect_deep(path, results)
    e = path[-1]
    info = entity_info(e)
    if info
      info[:pid_path] = path.map(&:persistent_id)
      info[:depth] = path.length - 1
      results << info
    end

    return unless e.respond_to?(:definition)

    e.definition.entities.each {|child|
      next unless child.visible? && child.layer.visible?
      collect_deep(path + [child], results)
    }
  end

  def self.copy_to_clipboard(img_path)
    # Windows only — dùng PowerShell để copy image vào clipboard
    return false unless Sketchup.platform == :platform_win

    ps_cmd = "Add-Type -AssemblyName System.Windows.Forms; " \
             "[System.Windows.Forms.Clipboard]::SetImage(" \
             "[System.Drawing.Image]::FromFile('#{img_path.tr('/', '\\')}'))"

    Thread.new {
      system("powershell", "-Command", ps_cmd)
    }
    true
  rescue
    false
  end

  def self.probe_at(model, view, sx, sy, px, py)
    result = { hit: false, pixel: [px, py], screen: [sx.round, sy.round] }

    # 1. Raytest — entity + instance path
    ray = view.pickray(sx, sy)
    hit = model.raytest(ray)
    if hit
      point, path = hit
      result[:hit] = true
      result[:point] = point.to_a.map {|v| v.to_f.round(1) }
      result[:distance] = view.camera.eye.distance(point).to_f.round(1)
      result[:pid_path] = path.map(&:persistent_id)

      entity = path.last
      result[:entity] = entity_info(entity)

      # Face normal
      if entity.is_a?(Sketchup::Face)
        result[:face_normal] = entity.normal.to_a.map {|v| v.to_f.round(3) }
      end
    end

    # 2. InputPoint — bổ sung snap info
    ip = view.inputpoint(sx, sy)
    if ip.valid?
      result[:snap] = {
        tooltip: ip.tooltip,
        position: ip.position.to_a.map {|v| v.to_f.round(1) },
      }
      result[:snap][:face_pid] = ip.face.persistent_id if ip.face
      result[:snap][:edge_pid] = ip.edge.persistent_id if ip.edge
    end

    result
  end

  private_class_method :extract_context, :entity_info, :collect_deep,
                       :copy_to_clipboard, :probe_at
end
