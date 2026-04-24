# Look (Vision + Ray Probe)

> Chụp viewport screenshot + extract context + bắn tia từ pixel → xác định entity trong model.

## Khi Nào Dùng
- Agent cần "nhìn" model để hiểu layout, vị trí objects
- User hỏi "nhìn xem model thế nào", "xem giúp tôi", "check viewport"
- **Vision → Model verification**: vision model nói "ghế đỏ bên trái" → probe pixel đó → lấy entity thật
- Cần camera position để tính toán (vd: đặt annotation đúng hướng nhìn)
- Cần screenshot để gửi cho vision model (Claude, GPT-4V...)
- Debug: "tại sao vẽ sai vị trí?" → nhìn viewport + probe

## Khi Nào KHÔNG Dùng
- Chỉ cần data entities → dùng `traverse_model`
- Chỉ cần thông tin camera → `model.active_view.camera` trực tiếp

## Workflow Chính: Vision → Probe → Entity

```
1. Look.run()          → chụp screenshot + context
2. Vision model        → phân tích ảnh: "ghế đỏ ở pixel (400, 300)"
3. Look.probe(px: 400, py: 300)  → bắn tia → trả entity info
4. Agent               → xác nhận entity, thao tác tiếp (select, modify, query...)
```

**Lưu ý:** `probe` phải gọi **ngay sau** `run()` — camera chưa đổi vị trí.

## API

### `Look.run(width:, height:, include_context:, deep:)`

**Safety:** query (read-only, chỉ chụp ảnh + đọc data)

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| width | Integer | 1920 | Chiều rộng screenshot (px) |
| height | Integer | 1080 | Chiều cao screenshot (px) |
| include_context | Boolean | true | Bao gồm camera + entities metadata |
| deep | Boolean | false | true = scan nested entities (như traverse_model). false = top-level only |

**Returns:** Hash

```ruby
{
  screenshot: "path/to/skills/look/capture.png",
  clipboard: true,        # Đã copy vào clipboard (Windows)
  duration_ms: 150,
  context: {
    model_name: "Building A",
    model_path: "C:/Projects/building_a.skp",
    camera: {
      eye: [43.40, -284.79, 152.93],
      target: [36.63, -254.69, 133.49],
      up: [-0.117, 0.520, 0.846],
      perspective: true,
      fov: 35.0,
    },
    selection_count: 3,
    entities: [
      {
        pid: "abc123",
        type: "ComponentInstance",
        name: "Pipe DN100",
        layer: "MEP",
        visible: true,
        bounds_center: [100.0, 200.0, 50.0],
        bounds_size: [500.0, 100.0, 100.0],
        definition_name: "VBO_Pipe_DN100",
        instance_count: 12,
      },
      {
        pid: "def456",
        type: "Face",
        area: 2500000.0,
        material: "Concrete",
        # ...
      },
    ],
  },
}
```

## Output Files

| File | Mô tả |
|------|--------|
| `skills/look/capture.png` | Screenshot viewport, overwrite mỗi lần gọi |

Screenshot tự động copy vào **clipboard** (Windows) — agent có thể paste trực tiếp vào Claude/GPT vision.

## Lưu Ý

- **Clipboard copy** chạy async (Thread) để không block SketchUp
- **`deep: true`** scan giống `traverse_model` — trên model lớn sẽ chậm hơn
- **Selection rỗng** → scan tất cả visible entities top-level (khác `traverse_model` trả empty)
- **`capture.png`** bị overwrite mỗi lần gọi — nếu cần lưu, copy file trước khi gọi lại
- **Perspective vs Parallel:** `fov` chỉ có khi `perspective: true`

---

## Ví Dụ Sử Dụng

### Chụp nhanh để "nhìn"

```ruby
result = Look.run
# Agent đọc screenshot từ result[:screenshot]
# Context có camera position + entities visible
```

### Chụp nhỏ (thumbnail) không cần context

```ruby
result = Look.run(width: 640, height: 480, include_context: false)
# Chỉ screenshot, nhanh hơn
```

### Scan sâu — liệt kê tất cả entities visible

```ruby
result = Look.run(deep: true)
# result[:context][:entities] chứa cả nested entities với pid_path + depth
result[:context][:entities].each {|e|
  puts "#{'  ' * e[:depth]}#{e[:type]}: #{e[:name]} (#{e[:layer]})"
}
```

### Dùng camera data để tính toán

```ruby
result = Look.run
cam = result[:context][:camera]
eye = Geom::Point3d.new(cam[:eye])
target = Geom::Point3d.new(cam[:target])
view_direction = target - eye
view_direction.normalize!
# Biết hướng nhìn → đặt annotation đúng hướng
```

---

## API: Probe (Bắn Tia)

### `Look.probe(px:, py:, capture_width:, capture_height:)`

Bắn 1 tia từ pixel trên screenshot → xác định entity tại vị trí đó.

**Safety:** query (read-only)

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| px | Integer | (required) | Pixel X trên screenshot |
| py | Integer | (required) | Pixel Y trên screenshot |
| capture_width | Integer | auto | Override width (mặc định từ lần `run()` gần nhất) |
| capture_height | Integer | auto | Override height |

**Returns:** Hash

```ruby
{
  hit: true,
  pixel: [400, 300],
  screen: [312, 234],            # Viewport coords sau khi scale
  point: [1500.0, 800.0, 0.0],  # World coords điểm chạm
  distance: 2500.0,              # Khoảng cách từ camera (mm)
  pid_path: ["abc1", "def2"],    # Instance path (persistent_ids)
  entity: {
    pid: "def2",
    type: "ComponentInstance",
    name: "Red Chair",
    layer: "Furniture",
    definition_name: "Chair_Model_A",
    instance_count: 4,
    bounds_center: [1500.0, 800.0, 450.0],
    bounds_size: [500.0, 500.0, 900.0],
  },
  face_normal: [0.0, 0.0, 1.0],  # Chỉ khi hit Face
  snap: {
    tooltip: "On Face in Group",  # InputPoint snap description
    position: [1500.0, 800.0, 0.0],
    face_pid: "xyz789",
    edge_pid: nil,
  },
}
```

### `Look.probe_many(points:, capture_width:, capture_height:)`

Bắn nhiều tia cùng lúc + **phân tích parent groups** (phát hiện vật thể chưa group).

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| points | Array\<Array\<Integer\>\> | (required) | `[[px1,py1], [px2,py2], ...]` |
| capture_width | Integer | auto | Override width |
| capture_height | Integer | auto | Override height |

**Returns:** Hash

```ruby
{
  count: 5,
  hits: 4,
  misses: 1,
  probes: [ ... ],        # Array kết quả từng probe
  parent_groups: [         # Group theo parent entity
    {
      parent_pid: "abc1",  # Nhiều hits cùng parent → cùng 1 object
      hit_count: 3,
      entity_types: { "Face" => 2, "Edge" => 1 },
    },
    {
      parent_pid: "__root__",  # Loose geometry (chưa group)
      hit_count: 1,
      entity_types: { "Face" => 1 },
    },
  ],
  duration_ms: 15,
}
```

---

## Ví Dụ: Vision → Probe

### Xác nhận "ghế đỏ bên trái"

```ruby
# 1. Chụp
capture = Look.run
# → Gửi capture[:screenshot] cho vision model
# → Vision: "Ghế đỏ ở khoảng pixel (350, 400)"

# 2. Probe
hit = Look.probe(px: 350, py: 400)
if hit[:hit]
  puts "Entity: #{hit[:entity][:name]} (#{hit[:entity][:type]})"
  puts "Definition: #{hit[:entity][:definition_name]}"
  puts "Layer: #{hit[:entity][:layer]}"
  # → "Entity: Red Chair (ComponentInstance)"
end
```

### Quét vùng — phát hiện vật thể chưa group

Vision nói "có 1 cái bàn ở giữa" nhưng có thể bàn đó chưa group.
Bắn grid 3x3 quanh vùng đó:

```ruby
# Tạo grid 3x3 quanh pixel (500, 400), spacing 30px
center_x, center_y = 500, 400
points = (-1..1).flat_map {|dx|
  (-1..1).map {|dy| [center_x + dx * 30, center_y + dy * 30] }
}

result = Look.probe_many(points: points)

puts "Hits: #{result[:hits]}/#{result[:count]}"
result[:parent_groups].each {|g|
  if g[:parent_pid] == '__root__'
    puts "⚠️ Loose geometry: #{g[:hit_count]} hits (chưa group!)"
  else
    puts "Group #{g[:parent_pid]}: #{g[:hit_count]} hits — #{g[:entity_types]}"
  end
}
```

### Probe dọc theo đường — trace edge/pipe

```ruby
# Probe 10 điểm dọc từ pixel (100,300) → (900,300)
points = (0..9).map {|i| [100 + i * 80, 300] }

result = Look.probe_many(points: points)
# Phân tích: bao nhiêu entities dọc đường? Có liên tục không?
pids = result[:probes].find_all {|p| p[:hit] }.map {|p| p[:pid_path].last }.uniq
puts "#{pids.length} distinct entities along the line"
```
