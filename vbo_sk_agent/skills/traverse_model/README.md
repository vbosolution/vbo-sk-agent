# Model Traversal

> Duyệt đệ quy entities trong selection — filter theo type, depth, hidden — trả về pid paths.

## Khi Nào Dùng
- Cần liệt kê / đếm entities trong selection (kể cả nested trong Group/Component)
- Cần tìm entities theo type, attribute, property
- Cần tạo BOQ, thống kê, phân tích model
- Cần thu thập dữ liệu để xử lý hàng loạt

## Khi Nào KHÔNG Dùng
- Chỉ cần thông tin top-level selection → dùng `model.selection.to_a` trực tiếp
- Cần sửa/tạo entities → viết code riêng (skill này read-only)

## API

### `TraverseModel.run(types:, depth:, include_hidden:)`

**Safety:** query (read-only, không sửa model)

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| types | Array\<String\> | nil (all) | Entity types cần lọc: `'Face'`, `'Edge'`, `'Group'`, `'ComponentInstance'`, `'ConstructionLine'`, `'Dimension'`, `'Text'`, `'Image'`, `'SectionPlane'` |
| depth | Integer | -1 | Max depth đệ quy. -1 = unlimited. 1 = chỉ top-level |
| include_hidden | Boolean | false | Bao gồm entities hidden hoặc trên layer invisible |

**Returns:** Hash

```ruby
{
  count: 1247,                    # Tổng entities tìm được
  entities: [                     # Mỗi item = 1 pid path (instance path dạng persistent_id)
    ["abc1"],                     # Entity ở top-level
    ["abc1", "def2"],             # Entity nested 1 level
    ["abc1", "def2", "ghi3"],    # Entity nested 2 levels
  ],
  duration_ms: 42                 # Thời gian chạy
}
```

**Cách dùng pid path:**

```ruby
# Cách 1: InstancePath (recommended — giữ nguyên context, world transform)
path = Sketchup::InstancePath.new(pid_path)
entity = path.leaf
world_transform = path.transformation

# Cách 2: Tìm entity cuối cùng (nhanh, nhưng mất context cha)
entity = model.find_entity_by_persistent_id(pid_path.last)
```

## Lưu Ý Quan Trọng

- **Selection rỗng → trả empty** (không fallback sang model/active)
- **`respond_to?(:definition)`** quyết định có đệ quy hay không (Group, ComponentInstance, Image)
- **Performance:** Model 10k entities < 1s, 100k entities 3-5s. `duration_ms` giúp monitor
- **Pid path** = instance path dạng persistent_id array, tương thích `Sketchup::InstancePath`
- **min SketchUp 2024**

---

## Ví Dụ Sử Dụng

### Ví dụ 1: Group Edges By Length (kể cả nested)

Tình huống: User chọn một nhóm objects, muốn biết có những edge dài bao nhiêu, mỗi loại bao nhiêu cái.

```ruby
results = TraverseModel.run(types: ['Edge'], depth: -1)
model = Sketchup.active_model

grouped = results[:entities].group_by {|pid_path|
  edge = model.find_entity_by_persistent_id(pid_path.last)
  edge.length.to_f.round(1)
}

# Output: { 100.0 => [pid_path1, pid_path2, ...], 250.5 => [...] }
summary = grouped.map {|length, paths| { length_mm: length, count: paths.length } }
summary.sort_by {|h| -h[:count] }
```

### Ví dụ 2: Simple BOQ — Group Objects By Layer

Tình huống: User chọn tất cả, muốn Bill of Quantities theo layer/tag.

```ruby
results = TraverseModel.run(types: ['Group', 'ComponentInstance'])
model = Sketchup.active_model

boq = results[:entities].group_by {|pid_path|
  ent = model.find_entity_by_persistent_id(pid_path.last)
  ent.layer.display_name
}

# Output: { "MEP" => [...], "Structure" => [...], "Furniture" => [...] }
boq.each {|layer_name, paths|
  breakdown = paths.group_by {|p|
    e = model.find_entity_by_persistent_id(p.last)
    e.respond_to?(:definition) ? e.definition.name : 'Group'
  }
  puts "#{layer_name}: #{paths.length} items"
  breakdown.each {|name, items| puts "  #{name}: #{items.length}" }
}
```

### Ví dụ 3: Find By Attribute Dictionary

Tình huống: Tìm tất cả Group/Component có attribute "VBO MEP PIPING PRO 3" với key "branch".

```ruby
results = TraverseModel.run(types: ['Group', 'ComponentInstance'])
model = Sketchup.active_model

branches = results[:entities].find_all {|pid_path|
  ent = model.find_entity_by_persistent_id(pid_path.last)
  ent.get_attribute("VBO MEP PIPING PRO 3", "branch") != nil
}

# Lấy chi tiết
branch_data = branches.map {|pid_path|
  ent = model.find_entity_by_persistent_id(pid_path.last)
  {
    pid_path: pid_path,
    branch_type: ent.get_attribute("VBO MEP PIPING PRO 3", "branch"),
    size: ent.get_attribute("VBO MEP PIPING PRO 3", "size"),
    layer: ent.layer.display_name,
  }
}

# Group by branch type
by_type = branch_data.group_by {|h| h[:branch_type] }
```

---

## Pattern Nâng Cao

### Kết hợp với InstancePath để lấy world transform

```ruby
results = TraverseModel.run(types: ['ComponentInstance'])
model = Sketchup.active_model

results[:entities].each {|pid_path|
  path = Sketchup::InstancePath.new(pid_path)
  world_pos = path.transformation.origin
  puts "#{path.leaf.definition.name} at #{world_pos}"
}
```

### Filter theo diện tích face

```ruby
results = TraverseModel.run(types: ['Face'])
model = Sketchup.active_model

large_faces = results[:entities].find_all {|pid_path|
  face = model.find_entity_by_persistent_id(pid_path.last)
  face.area > 1_000_000  # > 1m² (khi đơn vị là mm)
}
```

### Tìm entities chưa có attribute (missing data)

```ruby
results = TraverseModel.run(types: ['Group', 'ComponentInstance'])
model = Sketchup.active_model

missing = results[:entities].find_all {|pid_path|
  ent = model.find_entity_by_persistent_id(pid_path.last)
  ent.attribute_dictionary("MyPlugin").nil?
}
puts "#{missing.length} entities chưa có data"
```
