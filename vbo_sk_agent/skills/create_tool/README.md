# Create Tool

> Hướng dẫn tạo interactive tool cho SketchUp — 4 patterns cơ bản + kỹ thuật phát triển nâng cao.

## Khi Nào Dùng Skill Này
- User muốn tạo tool tương tác (pick entity, vẽ line, select region, multi-step workflow)
- Cần tool có preview realtime (highlight, rubber-band line, selection rectangle)
- Cần nhận input từ mouse/keyboard trong viewport

## Khi Nào KHÔNG Dùng
- Chỉ cần dialog nhập liệu → dùng `create_dialog_form`
- Chỉ cần query/modify model không tương tác → viết code trực tiếp

---

## Decision Tree — Chọn Pattern Nào?

```
User cần gì?
├── Pick/chọn entity từ model?
│   └── Pattern 1: HoverClick
├── Vẽ line/đường giữa 2 điểm?
│   └── Pattern 2: ClickClick
├── Chọn vùng (kéo rectangle)?
│   └── Pattern 3: ClickDrag
├── Workflow nhiều bước tuần tự?
│   └── Pattern 4: MultiState
└── Vẽ đường nhiều đoạn liên tiếp?
    └── Pattern 5a: Polyline (phát triển từ ClickClick)
```

---

## Native Tool Contract

### Methods BẮT BUỘC

| Method | Mô tả |
|--------|--------|
| `activate` | Tool được kích hoạt — init state, set cursor, status bar |
| `deactivate(view)` | Tool bị tắt — cleanup, invalidate view |
| `onMouseMove(flags, x, y, view)` | Mouse di chuyển — update preview |
| `onLButtonDown(flags, x, y, view)` | Click trái — primary action |
| `draw(view)` | Vẽ preview lên viewport (gọi mỗi frame khi cần) |

### Methods OPTIONAL (thường dùng)

| Method | Mô tả |
|--------|--------|
| `onLButtonUp(flags, x, y, view)` | Thả click — dùng cho ClickDrag |
| `onKeyDown(key, repeat, flags, view)` | Phím bấm — Esc cancel, arrow lock axis |
| `onUserText(text, view)` | VCB input — user gõ số vào Measurements box |
| `onReturn(view)` | Enter — confirm action |
| `getExtents` | Trả BoundingBox cover tất cả điểm vẽ (tránh bị clip!) |
| `onSetCursor` | Set cursor icon — return cursor_id |
| `resume(view)` | Tool được resume sau khi suspend (vd: sau orbit) |
| `suspend(view)` | Tool bị suspend tạm (user orbit/pan) |
| `getInstructorContentDirectory` | Path tới instructor HTML |

### Activate Tool

```ruby
Sketchup.active_model.select_tool(MyTool.new)
```

---

## Pattern 1: HoverClick Picker

### Concept
Mouse hover → highlight entity → click để pick. Dùng `PickHelper` để tìm entity dưới cursor.

### 1a: Highlight Edge On Hover

```ruby
class EdgePickerTool
  def activate
    @hover_edge = nil
    @picked_edges = []
    Sketchup.status_text = "Hover edge để highlight, click để chọn. Esc để thoát."
  end

  def deactivate(view)
    view.invalidate
  end

  def onMouseMove(flags, x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    edge = ph.best_picked
    edge = nil unless edge.is_a?(Sketchup::Edge)

    if edge != @hover_edge
      @hover_edge = edge
      view.invalidate
    end
  end

  def onLButtonDown(flags, x, y, view)
    if @hover_edge
      @picked_edges << @hover_edge
      view.invalidate
    end
  end

  def onKeyDown(key, repeat, flags, view)
    if key == VK_ESCAPE
      Sketchup.active_model.select_tool(nil)
    end
  end

  def draw(view)
    # Highlight edge đang hover (màu vàng)
    if @hover_edge
      view.drawing_color = Sketchup::Color.new(255, 200, 0)
      view.line_width = 3
      view.draw(GL_LINES, @hover_edge.vertices.map(&:position))
    end

    # Vẽ edges đã pick (màu xanh)
    @picked_edges.each {|e|
      view.drawing_color = Sketchup::Color.new(0, 150, 255)
      view.line_width = 2
      view.draw(GL_LINES, e.vertices.map(&:position))
    }
  end

  def getExtents
    bb = Geom::BoundingBox.new
    bb.add(@hover_edge.vertices.map(&:position)) if @hover_edge
    @picked_edges.each {|e| bb.add(e.vertices.map(&:position)) }
    bb
  end
end
```

### 1b: Highlight Face On Hover

```ruby
class FacePickerTool
  def activate
    @hover_face = nil
    Sketchup.status_text = "Hover face để highlight, click để chọn."
  end

  def deactivate(view)
    view.invalidate
  end

  def onMouseMove(flags, x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    face = ph.best_picked
    face = nil unless face.is_a?(Sketchup::Face)

    if face != @hover_face
      @hover_face = face
      view.invalidate
    end
  end

  def onLButtonDown(flags, x, y, view)
    if @hover_face
      # Xử lý face đã chọn
      puts "Picked face: area = #{@hover_face.area}"
    end
  end

  def draw(view)
    return unless @hover_face

    # Highlight face bằng polygon fill
    mesh = @hover_face.mesh
    points = []
    (1..mesh.count_polygons).each {|i|
      pts = mesh.polygon_points_at(i)
      points.concat(pts)
    }

    view.drawing_color = Sketchup::Color.new(255, 200, 0, 64)  # semi-transparent
    view.draw(GL_TRIANGLES, points)

    # Viền face
    view.drawing_color = Sketchup::Color.new(255, 200, 0)
    view.line_width = 2
    @hover_face.edges.each {|e|
      view.draw(GL_LINES, e.vertices.map(&:position))
    }
  end

  def getExtents
    bb = Geom::BoundingBox.new
    bb.add(@hover_face.vertices.map(&:position)) if @hover_face
    bb
  end
end
```

### 1c: Highlight Group/Component Bounding Box

```ruby
class GroupPickerTool
  CONTAINER_CLASSES = [Sketchup::Group, Sketchup::ComponentInstance]

  def activate
    @hover_entity = nil
    Sketchup.status_text = "Hover group/component để highlight bounding box."
  end

  def deactivate(view)
    view.invalidate
  end

  def onMouseMove(flags, x, y, view)
    ph = view.pick_helper
    ph.do_pick(x, y)
    ent = ph.best_picked
    ent = nil unless CONTAINER_CLASSES.any? {|c| ent.is_a?(c) }

    if ent != @hover_entity
      @hover_entity = ent
      view.invalidate
    end
  end

  def onLButtonDown(flags, x, y, view)
    if @hover_entity
      puts "Picked: #{@hover_entity.definition.name}"
    end
  end

  def draw(view)
    return unless @hover_entity

    bb = @hover_entity.bounds
    # 8 corners of bounding box
    min = bb.min
    max = bb.max
    pts = [
      Geom::Point3d.new(min.x, min.y, min.z),
      Geom::Point3d.new(max.x, min.y, min.z),
      Geom::Point3d.new(max.x, max.y, min.z),
      Geom::Point3d.new(min.x, max.y, min.z),
      Geom::Point3d.new(min.x, min.y, max.z),
      Geom::Point3d.new(max.x, min.y, max.z),
      Geom::Point3d.new(max.x, max.y, max.z),
      Geom::Point3d.new(min.x, max.y, max.z),
    ]

    view.line_width = 2
    view.drawing_color = Sketchup::Color.new(255, 150, 0)
    view.line_stipple = ''  # solid

    # Bottom face edges
    view.draw(GL_LINE_LOOP, pts[0..3])
    # Top face edges
    view.draw(GL_LINE_LOOP, pts[4..7])
    # Vertical edges
    (0..3).each {|i| view.draw(GL_LINES, [pts[i], pts[i + 4]]) }
  end

  def getExtents
    bb = Geom::BoundingBox.new
    bb.add(@hover_entity.bounds.min, @hover_entity.bounds.max) if @hover_entity
    bb
  end
end
```

---

## Pattern 2: ClickClick Line Tool

### Concept
Click điểm 1 → preview rubber-band line → click điểm 2 → tạo geometry. Dùng `InputPoint` cho inference.

```ruby
class LineTool
  def activate
    @ip1 = Sketchup::InputPoint.new   # Điểm đầu
    @ip2 = Sketchup::InputPoint.new   # Điểm preview (cursor)
    @state = 0  # 0 = chờ click 1, 1 = chờ click 2
    @first_point = nil
    Sketchup.status_text = "Click điểm đầu."
  end

  def deactivate(view)
    view.invalidate
  end

  def onMouseMove(flags, x, y, view)
    if @state == 0
      @ip1.pick(view, x, y)
    else
      @ip2.pick(view, x, y, @ip1)  # inference từ điểm đầu
    end
    view.tooltip = @state == 0 ? @ip1.tooltip : @ip2.tooltip
    view.invalidate
  end

  def onLButtonDown(flags, x, y, view)
    if @state == 0
      @ip1.pick(view, x, y)
      @first_point = @ip1.position
      @state = 1
      Sketchup.status_text = "Click điểm cuối. Esc để cancel."
    else
      @ip2.pick(view, x, y)
      create_geometry(@first_point, @ip2.position)
      reset_tool
    end
    view.invalidate
  end

  def onKeyDown(key, repeat, flags, view)
    if key == VK_ESCAPE
      if @state == 1
        reset_tool
        view.invalidate
      else
        Sketchup.active_model.select_tool(nil)
      end
    end
  end

  # VCB input — user gõ khoảng cách
  def onUserText(text, view)
    return unless @state == 1 && @first_point

    begin
      distance = text.to_l  # Parse Length string ("100mm", "5'", etc.)
      direction = @ip2.position - @first_point
      direction.normalize!
      end_point = @first_point.offset(direction, distance)
      create_geometry(@first_point, end_point)
      reset_tool
      view.invalidate
    rescue ArgumentError
      Sketchup.status_text = "Giá trị không hợp lệ. Thử lại."
    end
  end

  def draw(view)
    # Vẽ InputPoint indicator
    if @state == 0
      @ip1.draw(view) if @ip1.valid?
    else
      @ip2.draw(view) if @ip2.valid?

      # Rubber-band line
      if @first_point && @ip2.valid?
        view.line_width = 1
        view.drawing_color = Sketchup::Color.new(0, 0, 0)
        view.line_stipple = '-'  # dashed
        view.draw(GL_LINES, [@first_point, @ip2.position])

        # Hiển thị khoảng cách
        mid = Geom.linear_combination(0.5, @first_point, 0.5, @ip2.position)
        dist = @first_point.distance(@ip2.position)
        view.draw_text(mid, Sketchup.format_length(dist))
      end
    end
  end

  def getExtents
    bb = Geom::BoundingBox.new
    bb.add(@first_point) if @first_point
    bb.add(@ip2.position) if @ip2.valid?
    bb
  end

  private

  def create_geometry(pt1, pt2)
    model = Sketchup.active_model
    model.start_operation('Draw Line', true)
    model.active_entities.add_line(pt1, pt2)
    model.commit_operation
  end

  def reset_tool
    @state = 0
    @first_point = nil
    @ip1.clear
    @ip2.clear
    Sketchup.status_text = "Click điểm đầu."
  end
end
```

### Thủ thuật InputPoint

- `@ip2.pick(view, x, y, @ip1)` — truyền ip1 làm reference → inference tự snap theo axis
- `@ip1.draw(view)` — vẽ indicator (green/red/blue dot) tự động
- `@ip1.tooltip` — text mô tả snap (vd: "On Edge", "Midpoint", "Origin")
- Parse VCB: `text.to_l` convert string ("100mm") → SketchUp Length

---

## Pattern 3: ClickDrag Rectangle Selector

### Concept
LButtonDown → kéo rectangle → LButtonUp → process entities trong vùng.

```ruby
class RectSelectTool
  def activate
    @start_point = nil  # Screen coords [x, y]
    @end_point = nil
    @dragging = false
    @selected = []
    Sketchup.status_text = "Kéo để chọn vùng. Left→Right = Window, Right→Left = Crossing."
  end

  def deactivate(view)
    view.invalidate
  end

  def onLButtonDown(flags, x, y, view)
    @start_point = [x, y]
    @end_point = [x, y]
    @dragging = true
  end

  def onMouseMove(flags, x, y, view)
    if @dragging
      @end_point = [x, y]
      view.invalidate
    end
  end

  def onLButtonUp(flags, x, y, view)
    return unless @dragging
    @dragging = false
    @end_point = [x, y]

    # Tính toán selection
    process_selection(view)
    view.invalidate
  end

  def draw(view)
    return unless @dragging && @start_point && @end_point

    x1, y1 = @start_point
    x2, y2 = @end_point

    # Window (left→right) = solid blue, Crossing (right→left) = dashed green
    is_window = x2 > x1
    if is_window
      view.drawing_color = Sketchup::Color.new(0, 100, 200, 32)
      view.line_stipple = ''
    else
      view.drawing_color = Sketchup::Color.new(0, 200, 100, 32)
      view.line_stipple = '-'
    end

    # Fill rectangle (2D screen coords)
    pts = [
      [x1, y1, 0], [x2, y1, 0],
      [x2, y2, 0], [x1, y2, 0],
    ]
    view.draw2d(GL_QUADS, pts)

    # Border
    view.line_width = 1
    view.drawing_color = is_window ? Sketchup::Color.new(0, 100, 200) : Sketchup::Color.new(0, 200, 100)
    view.draw2d(GL_LINE_LOOP, pts)
  end

  private

  def process_selection(view)
    x1, y1 = @start_point
    x2, y2 = @end_point
    is_window = x2 > x1

    model = Sketchup.active_model
    entities = model.active_entities

    @selected = entities.find_all {|e|
      next false if e.hidden? || !e.layer.visible?
      next false unless e.respond_to?(:bounds)

      if is_window
        # Window: entity phải nằm hoàn to��n trong rectangle
        entity_inside_rect?(e, x1, y1, x2, y2, view)
      else
        # Crossing: entity chỉ cần giao với rectangle
        entity_crosses_rect?(e, x1, y1, x2, y2, view)
      end
    }

    model.selection.clear
    model.selection.add(@selected)
    Sketchup.status_text = "Đã chọn #{@selected.length} entities."
  end

  def entity_inside_rect?(entity, x1, y1, x2, y2, view)
    # Check tất cả corners của bounding box
    bb = entity.bounds
    min_x, max_x = [x1, x2].sort
    min_y, max_y = [y1, y2].sort

    (0..7).all? {|i|
      pt = bb.corner(i)
      screen = view.screen_coords(pt)
      screen.x >= min_x && screen.x <= max_x &&
      screen.y >= min_y && screen.y <= max_y
    }
  end

  def entity_crosses_rect?(entity, x1, y1, x2, y2, view)
    bb = entity.bounds
    min_x, max_x = [x1, x2].sort
    min_y, max_y = [y1, y2].sort

    (0..7).any? {|i|
      pt = bb.corner(i)
      screen = view.screen_coords(pt)
      screen.x >= min_x && screen.x <= max_x &&
      screen.y >= min_y && screen.y <= max_y
    }
  end
end
```

### Thủ thuật ClickDrag

- `draw2d` dùng screen coordinates (pixels), `draw` dùng 3D model coordinates
- `view.screen_coords(pt3d)` → project 3D point sang screen [x, y]
- Phân biệt Window vs Crossing bằng hướng kéo (left→right vs right→left)
- Drag threshold: nếu distance < 2px → coi như single click, không phải drag

---

## Pattern 4: MultiState Tool

### Concept
Tool có nhiều bước tuần tự. Mỗi state xử lý input khác nhau.

```ruby
class MultiStateTool
  def activate
    @state = 0
    @point1 = nil
    @point2 = nil
    @direction = nil
    @ip = Sketchup::InputPoint.new
    update_status
  end

  def deactivate(view)
    view.invalidate
  end

  def onMouseMove(flags, x, y, view)
    @ip.pick(view, x, y)
    view.invalidate
  end

  def onLButtonDown(flags, x, y, view)
    @ip.pick(view, x, y)

    case @state
    when 0  # Pick base point
      @point1 = @ip.position
      @state = 1
    when 1  # Pick second point (defines direction)
      @point2 = @ip.position
      @direction = @point2 - @point1
      @state = 2
    when 2  # Pick height / confirm
      height_point = @ip.position
      create_result(@point1, @point2, height_point)
      reset_tool
    end

    update_status
    view.invalidate
  end

  def onKeyDown(key, repeat, flags, view)
    if key == VK_ESCAPE
      if @state > 0
        @state -= 1  # Go back one state
        update_status
        view.invalidate
      else
        Sketchup.active_model.select_tool(nil)
      end
    end
  end

  def draw(view)
    @ip.draw(view) if @ip.valid?

    case @state
    when 1
      # Preview line from point1 to cursor
      if @point1 && @ip.valid?
        view.line_width = 1
        view.drawing_color = Sketchup::Color.new(255, 0, 0)
        view.draw(GL_LINES, [@point1, @ip.position])
      end
    when 2
      # Preview base line + height line
      if @point1 && @point2 && @ip.valid?
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(255, 0, 0)
        view.draw(GL_LINES, [@point1, @point2])

        view.line_width = 1
        view.drawing_color = Sketchup::Color.new(0, 0, 255)
        view.line_stipple = '-'
        view.draw(GL_LINES, [@point2, @ip.position])
      end
    end
  end

  def getExtents
    bb = Geom::BoundingBox.new
    bb.add(@point1) if @point1
    bb.add(@point2) if @point2
    bb.add(@ip.position) if @ip.valid?
    bb
  end

  private

  def update_status
    messages = [
      "State 0: Click điểm gốc.",
      "State 1: Click điểm thứ 2 (xác định hướng).",
      "State 2: Click để xác định chiều cao. Esc để quay lại.",
    ]
    Sketchup.status_text = messages[@state]
  end

  def create_result(pt1, pt2, pt3)
    model = Sketchup.active_model
    model.start_operation('Multi-State Result', true)
    # Tạo geometry tùy mục đích tool
    ents = model.active_entities
    ents.add_line(pt1, pt2)
    ents.add_line(pt2, pt3)
    model.commit_operation
  end

  def reset_tool
    @state = 0
    @point1 = nil
    @point2 = nil
    @direction = nil
    @ip.clear
    update_status
  end
end
```

### Thủ thuật MultiState

- Esc nên go back 1 state (không thoát tool ngay) — UX thân thiện hơn
- Mỗi state có status text riêng
- `draw` render khác nhau theo state
- Có thể combine với VCB: mỗi state accept input khác nhau

---

## Pattern 5: Phát Triển Nâng Cao

### 5a: Polyline Tool (chain từ ClickClick)

**Key insight:** Thay vì reset về state 0 sau click 2, đổi điểm cuối thành điểm đầu mới → tiếp tục state 1.

```ruby
class PolylineTool
  def activate
    @ip = Sketchup::InputPoint.new
    @points = []      # Mảng điểm đã click
    @state = 0        # 0 = chờ click đầu tiên, 1 = đang vẽ (chờ click tiếp)
    Sketchup.status_text = "Click điểm đầu tiên."
  end

  def deactivate(view)
    view.invalidate
  end

  def onMouseMove(flags, x, y, view)
    @ip.pick(view, x, y)
    view.invalidate
  end

  def onLButtonDown(flags, x, y, view)
    @ip.pick(view, x, y)
    @points << @ip.position.clone

    if @state == 0
      @state = 1
      Sketchup.status_text = "Click điểm tiếp theo. Double-click hoặc Enter để kết thúc. Esc để cancel."
    end
    # KHÔNG reset state — giữ state 1, đợi click tiếp
    view.invalidate
  end

  def onLButtonDoubleClick(flags, x, y, view)
    # Double-click = kết thúc polyline
    finish_polyline
    view.invalidate
  end

  def onReturn(view)
    # Enter = kết thúc polyline
    finish_polyline
    view.invalidate
  end

  def onKeyDown(key, repeat, flags, view)
    if key == VK_ESCAPE
      if @points.length > 1
        # Undo last point
        @points.pop
        view.invalidate
      else
        Sketchup.active_model.select_tool(nil)
      end
    end
  end

  def draw(view)
    @ip.draw(view) if @ip.valid?

    return if @points.empty?

    # Vẽ segments đã confirm
    if @points.length > 1
      view.line_width = 2
      view.drawing_color = Sketchup::Color.new(0, 0, 0)
      view.line_stipple = ''
      view.draw(GL_LINE_STRIP, @points)
    end

    # Rubber-band từ điểm cuối đến cursor
    if @state == 1 && @ip.valid?
      view.line_width = 1
      view.drawing_color = Sketchup::Color.new(0, 0, 0)
      view.line_stipple = '-'
      view.draw(GL_LINES, [@points.last, @ip.position])

      # Hiển thị segment length
      dist = @points.last.distance(@ip.position)
      mid = Geom.linear_combination(0.5, @points.last, 0.5, @ip.position)
      view.draw_text(mid, Sketchup.format_length(dist))
    end

    # Vẽ vertices
    view.draw_points(@points, 6, 2, Sketchup::Color.new(255, 0, 0))
  end

  def getExtents
    bb = Geom::BoundingBox.new
    bb.add(@points) unless @points.empty?
    bb.add(@ip.position) if @ip.valid?
    bb
  end

  private

  def finish_polyline
    return if @points.length < 2

    model = Sketchup.active_model
    model.start_operation('Draw Polyline', true)
    ents = model.active_entities
    (0...@points.length - 1).each {|i|
      ents.add_line(@points[i], @points[i + 1])
    }
    model.commit_operation

    # Reset
    @points = []
    @state = 0
    Sketchup.status_text = "Click điểm đầu tiên."
  end
end
```

### 5b: Follow-Me Sweep Tool (kế thừa Polyline)

**Key insight:** Kế thừa PolylineTool, chỉ đổi `finish_polyline` → dùng `followme` trên face đã chọn trước.

**Workflow:**
1. User chọn 1 Face (profile) trước khi activate tool
2. Activate SweepTool
3. Vẽ polyline path (giống Pattern 5a)
4. Khi finish → tạo edges từ polyline → followme face along path

```ruby
class SweepTool < PolylineTool
  def activate
    super
    @profile_face = find_selected_face
    if @profile_face
      Sketchup.status_text = "Face profile đã chọn. Click điểm đầu của sweep path."
    else
      Sketchup.status_text = "LỖI: Chọn 1 Face làm profile trước khi dùng tool này!"
      Sketchup.active_model.select_tool(nil)
    end
  end

  private

  def find_selected_face
    sel = Sketchup.active_model.selection
    faces = sel.grep(Sketchup::Face)
    faces.first  # Lấy face đầu tiên trong selection
  end

  def finish_polyline
    return if @points.length < 2
    return unless @profile_face

    model = Sketchup.active_model
    model.start_operation('Sweep (Follow Me)', true)

    begin
      ents = model.active_entities

      # Tạo path edges từ polyline points
      path_edges = []
      (0...@points.length - 1).each {|i|
        edge = ents.add_line(@points[i], @points[i + 1])
        path_edges << edge
      }

      # Follow Me: extrude profile face along path
      @profile_face.followme(path_edges)

      model.commit_operation
    rescue => e
      model.abort_operation
      puts "Sweep failed: #{e.message}"
    end

    # Reset
    @points = []
    @state = 0
    Sketchup.status_text = "Done! Chọn face mới và activate lại để sweep tiếp."
  end
end
```

**Lưu ý Follow Me:**
- Face profile phải nằm vuông góc với path tại điểm đầu (hoặc gần vuông góc)
- Path edges phải liên tiếp (connected)
- Nếu path tự giao (self-intersecting) → follow me sẽ fail
- Face phải ở cùng context (active_entities) với path

---

## Draw Graphics Guide

### 2D vs 3D Coordinates

| Method | Coordinates | Dùng khi |
|--------|-------------|----------|
| `view.draw(mode, points)` | 3D model space | Vẽ trong model (auto-project) |
| `view.draw2d(mode, points)` | 2D screen pixels | Vẽ overlay UI (rectangle, text, icon) |

### Screen ↔ Model Conversion

```ruby
# 3D → 2D (project to screen)
screen_pt = view.screen_coords(point3d)  # → Geom::Point3d (z=0)

# 2D → 3D (unproject — cần thêm info)
ray = view.pickray(x, y)  # [point, direction]
# Intersect ray với plane để lấy điểm 3D
```

### DPI Scaling

```ruby
# Text size / line width cần scale cho high-DPI displays
scale = UI.scale_factor  # 1.0 = 96dpi, 1.5 = 144dpi, 2.0 = 192dpi

view.line_width = 2 * scale
# view.draw_text point, text, size: (12 * scale).to_i
```

### Draw Modes (OpenGL constants)

| Constant | Ý nghĩa |
|----------|---------|
| `GL_POINTS` | Điểm rời |
| `GL_LINES` | Cặp điểm → line segments (2n points = n lines) |
| `GL_LINE_STRIP` | Polyline liên tiếp (n points = n-1 lines) |
| `GL_LINE_LOOP` | Polyline khép kín (n points = n lines) |
| `GL_TRIANGLES` | Tam giác fill (3n points = n triangles) |
| `GL_QUADS` | Tứ giác fill (4n points = n quads) |
| `GL_POLYGON` | Polygon fill |

### Line Stipple (nét đứt)

```ruby
view.line_stipple = ''    # Solid
view.line_stipple = '-'   # Dashed
view.line_stipple = '.'   # Dotted
view.line_stipple = '-.'  # Dash-dot
```

### getExtents TRAP

**Vấn đề:** Nếu `getExtents` không cover điểm sẽ vẽ → SketchUp clip (không hiển thị).

**Giải ph��p:** Luôn add TẤT CẢ điểm sẽ dùng trong `draw` vào BoundingBox:

```ruby
def getExtents
  bb = Geom::BoundingBox.new
  # Add MỌI point sẽ vẽ
  bb.add(@point1) if @point1
  bb.add(@point2) if @point2
  bb.add(@ip.position) if @ip.valid?
  bb.add(@preview_points) if @preview_points
  bb
end
```

**Nếu bỏ qua getExtents → preview sẽ biến mất khi zoom out!**

### draw_points (vẽ điểm marker)

```ruby
# style: 1=open_square, 2=filled_square, 3=plus, 4=cross,
#        5=star, 6=open_circle, 7=filled_circle
view.draw_points(points_array, size, style, color)
```

### draw_text

```ruby
# Vẽ text tại 3D point (auto-project to screen)
view.draw_text(point3d, "Hello")

# Với options (SU 2020+)
view.draw_text(point3d, "Hello",
  size: 14,
  bold: true,
  color: Sketchup::Color.new(255, 0, 0)
)
```

---

## Tips Chung

1. **Luôn gọi `view.invalidate`** sau khi thay đổi state — SketchUp mới gọi `draw`
2. **Cursor:** Dùng `UI.create_cursor(path, hot_x, hot_y)` tạo cursor custom
3. **Operation wrapping:** Mọi thay đổi model PHẢI wrap trong `start_operation` / `commit_operation`
4. **`start_operation(name, true)`** — param thứ 2 = `disable_ui` (true = transparent, có thể merge với operation trước)
5. **Esc convention:** State > 0 → back 1 state. State 0 → thoát tool
6. **VCB always available:** User có thể gõ số bất cứ lúc nào → handle `onUserText`
