# Create Dialog Form

> Hướng dẫn tạo HtmlDialog form với VBO UI library — professional, consistent, đúng phong cách VBO.

## Khi Nào Dùng Skill Này
- User cần form nhập liệu (settings, parameters, options)
- Cần UI dialog cho plugin (about, help, configuration)
- Cần panel hiển thị dữ liệu (table, list, dashboard)

## Khi Nào KHÔNG Dùng
- Chỉ cần confirm đơn giản (Yes/No) → dùng `UI.messagebox`
- Cần file picker → dùng `UI.openpanel` / `UI.savepanel`
- Cần color picker đơn giản → dùng `UI.inputbox`

## Prerequisites

VBO Core phải installed → CSS files available tại:
```
../../../000_vbo_core/ui/css/main.css
../../../000_vbo_core/ui/css/layout.css
../../../000_vbo_core/ui/css/fields.css
../../../000_vbo_core/ui/css/popup.css
../../../000_vbo_core/ui/css/accordion.css
../../../000_vbo_core/ui/css/tab.css
```

---

## HTML Template Chuẩn (Skeleton)

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/main.css">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/fields.css">
  <style>
    body { overflow: hidden; padding: 8px; }
    .form-container { display: flex; flex-direction: column; height: 100%; gap: 8px; }
    .form-content { flex: 1; overflow-y: auto; }
    .form-footer { display: flex; justify-content: center; gap: 8px; padding: 8px 0; }
  </style>
</head>
<body>
  <div class="form-container">
    <div class="form-content">
      <!-- Form fields here -->
    </div>
    <div class="form-footer">
      <button class="popup-button" onclick="cancel()">Cancel</button>
      <button class="popup-button popup-button-info" onclick="submit()">OK</button>
    </div>
  </div>

  <script>
    function submit() {
      var data = collectFormData();
      sketchup.on_submit(JSON.stringify(data));
    }

    function cancel() {
      sketchup.on_cancel();
    }

    function collectFormData() {
      // Thu thập data từ form
      return {
        // field_name: value, ...
      };
    }
  </script>
</body>
</html>
```

---

## Available Components

### Text Input

```html
<div class="form-field">
  <div class="field-header"><label>Tên</label></div>
  <input type="text" id="name" placeholder="Nhập tên...">
</div>
```

### Number Input

```html
<div class="form-field">
  <div class="field-header"><label>Chiều dài (mm)</label></div>
  <input type="number" id="length" value="100" min="0" step="0.1">
</div>
```

### Select / Dropdown

```html
<div class="form-field">
  <div class="field-header"><label>Loại ống</label></div>
  <select id="pipe_type">
    <option value="round">Tròn</option>
    <option value="rect">Chữ nhật</option>
    <option value="oval">Oval</option>
  </select>
</div>
```

### Checkbox

```html
<div class="enum-field">
  <label>
    <input type="checkbox" id="include_fittings" checked>
    <span>Bao gồm fittings</span>
  </label>
</div>
```

### Radio Buttons

```html
<div class="form-field">
  <div class="field-header"><label>Hướng</label></div>
  <div class="radio-option">
    <label><input type="radio" name="direction" value="up" checked> Lên</label>
  </div>
  <div class="radio-option">
    <label><input type="radio" name="direction" value="down"> Xuống</label>
  </div>
  <div class="radio-option">
    <label><input type="radio" name="direction" value="left"> Trái</label>
  </div>
</div>
```

### Toggle Switch

```html
<div class="form-field" style="display: flex; align-items: center; gap: 8px;">
  <label>Auto-connect</label>
  <div class="toggle-switch" id="auto_connect" onclick="toggleSwitch(this)">
    <div class="toggle-slider"></div>
  </div>
</div>

<script>
function toggleSwitch(el) {
  el.classList.toggle('active');
}
function getToggleValue(id) {
  return document.getElementById(id).classList.contains('active');
}
</script>
```

### Color Picker

```html
<div class="form-field">
  <div class="field-header"><label>Màu sắc</label></div>
  <div style="display: flex; gap: 8px; align-items: center;">
    <input type="color" id="color" value="#ff9900" style="width: 32px; height: 24px; border: 1px solid var(--color-input-border); border-radius: 4px;">
    <input type="text" id="color_hex" value="#ff9900" style="width: 80px;" oninput="document.getElementById('color').value = this.value">
  </div>
</div>
```

### Textarea

```html
<div class="form-field">
  <div class="field-header"><label>Ghi chú</label></div>
  <textarea id="notes" rows="3" placeholder="Nhập ghi chú..." style="width: 100%; padding: 6px 8px; border: 1px solid var(--color-input-border); border-radius: 4px; font-size: 11px; resize: vertical;"></textarea>
</div>
```

### Slider / Range

```html
<div class="form-field">
  <div class="field-header"><label>Opacity: <span id="opacity_val">80</span>%</label></div>
  <input type="range" id="opacity" min="0" max="100" value="80"
    style="width: 100%;"
    oninput="document.getElementById('opacity_val').textContent = this.value">
</div>
```

---

## Layout Components

### Accordion (collapsible sections)

```html
<link rel="stylesheet" href="../../../000_vbo_core/ui/css/accordion.css">

<div class="accordion-item expanded">
  <div class="accordion-header active" onclick="toggleAccordion(this)">
    <span class="accordion-title">Cài đặt cơ bản</span>
  </div>
  <div class="accordion-content">
    <!-- Fields here -->
  </div>
</div>

<div class="accordion-item">
  <div class="accordion-header" onclick="toggleAccordion(this)">
    <span class="accordion-title">Cài đặt nâng cao</span>
  </div>
  <div class="accordion-content" style="display: none;">
    <!-- Fields here -->
  </div>
</div>

<script>
function toggleAccordion(header) {
  var item = header.parentElement;
  var content = header.nextElementSibling;
  var isExpanded = item.classList.contains('expanded');

  item.classList.toggle('expanded');
  header.classList.toggle('active');
  content.style.display = isExpanded ? 'none' : '';
}
</script>
```

### Tabs

```html
<link rel="stylesheet" href="../../../000_vbo_core/ui/css/tab.css">

<div class="tabs-wrapper">
  <div class="tab-item active" onclick="switchTab(this, 'tab1')">General</div>
  <div class="tab-item" onclick="switchTab(this, 'tab2')">Advanced</div>
  <div class="tab-item" onclick="switchTab(this, 'tab3')">About</div>
</div>

<div id="tab1" class="tab-content">
  <!-- Tab 1 content -->
</div>
<div id="tab2" class="tab-content" style="display: none;">
  <!-- Tab 2 content -->
</div>
<div id="tab3" class="tab-content" style="display: none;">
  <!-- Tab 3 content -->
</div>

<script>
function switchTab(tabEl, contentId) {
  // Deactivate all tabs
  document.querySelectorAll('.tab-item').forEach(function(t) { t.classList.remove('active'); });
  document.querySelectorAll('.tab-content').forEach(function(c) { c.style.display = 'none'; });

  // Activate selected
  tabEl.classList.add('active');
  document.getElementById(contentId).style.display = '';
}
</script>
```

### Toolbar

```html
<div class="toolbar" style="border-bottom: 1px solid var(--color-input-border); padding: 4px;">
  <button class="toolbar-button active" title="Select" onclick="setMode('select')">
    <!-- SVG icon here -->
  </button>
  <button class="toolbar-button" title="Draw" onclick="setMode('draw')">
    <!-- SVG icon here -->
  </button>
  <span style="border-left: 1px solid var(--color-input-border); height: 16px; margin: 0 4px;"></span>
  <input class="toolbar-input" type="text" placeholder="Filter..." oninput="filterList(this.value)">
</div>
```

---

## CSS Variables (Color Palette)

```css
--color-primary: #ff9900;           /* Orange — VBO brand, buttons, active states */
--color-text: #666;                 /* Default text */
--color-background: #f2f2f2;        /* Body background */
--color-input-border: #bebebe;      /* Input borders */
--color-hover: #9dc3fb;             /* Hover state */
--color-actived: #bcd8fa;           /* Active/selected state */
--color-success: #28a745;           /* Green — success */
--color-warning: #ffc107;           /* Yellow — warning */
--color-danger: #dc3545;            /* Red — error/danger */
--color-info: #3a85b7;              /* Blue — info */
```

**Font:** Verdana, 12px base, 11px inputs/small text
**Border radius:** 4px
**Spacing:** 8px unit (padding, gap, margin)

---

## Callback Convention (Ruby ↔ HTML)

### HTML → Ruby (gửi data)

```javascript
// Gửi data dạng JSON string
sketchup.on_submit(JSON.stringify({
  name: document.getElementById('name').value,
  length: parseFloat(document.getElementById('length').value),
  type: document.getElementById('pipe_type').value,
  include_fittings: document.getElementById('include_fittings').checked,
  color: document.getElementById('color').value,
}));
```

### Ruby → HTML (set data)

```ruby
# Từ Ruby, execute JavaScript trong dialog
@dialog.execute_script("document.getElementById('name').value = 'Pipe A';")
@dialog.execute_script("setFormData(#{data.to_json});")
```

### Ruby Dialog Setup

```ruby
dialog = UI::HtmlDialog.new(
  dialog_title: "My Form",
  width: 400,
  height: 300,
  resizable: true,
  style: UI::HtmlDialog::STYLE_DIALOG,
)

dialog.set_file(File.join(__dir__, 'form.html'))

dialog.add_action_callback('on_submit') {|action_context, json_str|
  data = JSON.parse(json_str, symbolize_names: true)
  # Process data...
  dialog.close
}

dialog.add_action_callback('on_cancel') {|action_context|
  dialog.close
}

dialog.show
```

---

## Icons

Bạn muốn icons? Hãy truy cập https://icon-sets.iconify.design/ và lựa icon, sau đó paste SVG code cho tôi.

SVG icons inline trong HTML:
```html
<button class="toolbar-button">
  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
    <!-- SVG path data from iconify -->
  </svg>
</button>
```

**Tips:**
- Dùng `fill="currentColor"` để icon theo màu text (hover tự đổi theo CSS)
- Size: 12px (small), 16px (base), 24px (large) — theo `--small/base/large-icon-size`

---

## Ví Dụ Đầy Đủ

### Example 1: Form Đơn Giản (Pipe Parameters)

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/main.css">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/fields.css">
  <style>
    body { overflow: hidden; padding: 12px; }
    .form-container { display: flex; flex-direction: column; height: 100%; }
    .form-content { flex: 1; display: flex; flex-direction: column; gap: 12px; }
    .form-footer { display: flex; justify-content: center; gap: 8px; padding-top: 12px; border-top: 1px solid var(--color-input-border); }
    .form-row { display: flex; gap: 8px; }
    .form-row .form-field { flex: 1; }
  </style>
</head>
<body>
  <div class="form-container">
    <div class="form-content">
      <div class="form-field">
        <div class="field-header"><label>Tên ống</label></div>
        <input type="text" id="pipe_name" placeholder="VD: DN100 Chiller Supply">
      </div>

      <div class="form-row">
        <div class="form-field">
          <div class="field-header"><label>Đường kính (mm)</label></div>
          <input type="number" id="diameter" value="100" min="15" step="5">
        </div>
        <div class="form-field">
          <div class="field-header"><label>Chiều dài (mm)</label></div>
          <input type="number" id="length" value="1000" min="1">
        </div>
      </div>

      <div class="form-field">
        <div class="field-header"><label>Material</label></div>
        <select id="material">
          <option value="steel">Thép đen</option>
          <option value="galvanized">Thép mạ kẽm</option>
          <option value="copper">Đồng</option>
          <option value="pvc">PVC</option>
          <option value="ppr">PPR</option>
        </select>
      </div>

      <div class="enum-field">
        <label>
          <input type="checkbox" id="insulated" checked>
          <span>Có bảo ôn</span>
        </label>
      </div>
    </div>

    <div class="form-footer">
      <button class="popup-button" onclick="sketchup.on_cancel()">Cancel</button>
      <button class="popup-button popup-button-info" onclick="submitForm()">Tạo Ống</button>
    </div>
  </div>

  <script>
    function submitForm() {
      var data = {
        pipe_name: document.getElementById('pipe_name').value,
        diameter: parseFloat(document.getElementById('diameter').value),
        length: parseFloat(document.getElementById('length').value),
        material: document.getElementById('material').value,
        insulated: document.getElementById('insulated').checked,
      };
      sketchup.on_submit(JSON.stringify(data));
    }
  </script>
</body>
</html>
```

### Example 2: Form Có Tabs (Settings Dialog)

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/main.css">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/fields.css">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/tab.css">
  <style>
    body { overflow: hidden; padding: 0; margin: 0; display: flex; flex-direction: column; height: 100vh; }
    .tab-content { flex: 1; padding: 12px; overflow-y: auto; display: flex; flex-direction: column; gap: 10px; }
    .form-footer { display: flex; justify-content: center; gap: 8px; padding: 8px; border-top: 1px solid var(--color-input-border); }
  </style>
</head>
<body>
  <div class="tabs-wrapper">
    <div class="tab-item active" onclick="switchTab(this, 'general')">General</div>
    <div class="tab-item" onclick="switchTab(this, 'display')">Display</div>
    <div class="tab-item" onclick="switchTab(this, 'shortcuts')">Shortcuts</div>
  </div>

  <div id="general" class="tab-content">
    <div class="form-field">
      <div class="field-header"><label>Đơn vị mặc định</label></div>
      <select id="default_unit">
        <option value="mm">Millimeters</option>
        <option value="cm">Centimeters</option>
        <option value="m">Meters</option>
        <option value="inch">Inches</option>
      </select>
    </div>
    <div class="form-field">
      <div class="field-header"><label>Số thập phân</label></div>
      <input type="number" id="decimals" value="1" min="0" max="6">
    </div>
    <div class="enum-field">
      <label><input type="checkbox" id="auto_save" checked><span>Auto-save settings</span></label>
    </div>
  </div>

  <div id="display" class="tab-content" style="display: none;">
    <div class="form-field">
      <div class="field-header"><label>Line width</label></div>
      <input type="range" id="line_width" min="1" max="5" value="2"
        oninput="document.getElementById('lw_val').textContent = this.value">
      <span id="lw_val" style="font-size: 11px; color: var(--color-text-light);">2</span>
    </div>
    <div class="form-field">
      <div class="field-header"><label>Highlight color</label></div>
      <input type="color" id="highlight_color" value="#ff9900" style="width: 48px; height: 24px; border: 1px solid var(--color-input-border); border-radius: 4px;">
    </div>
    <div class="enum-field">
      <label><input type="checkbox" id="show_labels"><span>Hiển thị nhãn</span></label>
    </div>
  </div>

  <div id="shortcuts" class="tab-content" style="display: none;">
    <div class="form-field">
      <div class="field-header"><label>Activate tool</label></div>
      <input type="text" id="key_activate" value="Ctrl+Shift+T" readonly
        onclick="this.value='Press key...'; captureKey(this);"
        style="cursor: pointer;">
    </div>
    <div class="form-field">
      <div class="field-header"><label>Toggle panel</label></div>
      <input type="text" id="key_panel" value="Ctrl+Shift+P" readonly
        onclick="this.value='Press key...'; captureKey(this);"
        style="cursor: pointer;">
    </div>
  </div>

  <div class="form-footer">
    <button class="popup-button" onclick="sketchup.on_cancel()">Cancel</button>
    <button class="popup-button popup-button-info" onclick="saveSettings()">Save</button>
  </div>

  <script>
    function switchTab(tabEl, contentId) {
      document.querySelectorAll('.tab-item').forEach(function(t) { t.classList.remove('active'); });
      document.querySelectorAll('.tab-content').forEach(function(c) { c.style.display = 'none'; });
      tabEl.classList.add('active');
      document.getElementById(contentId).style.display = '';
    }

    function captureKey(input) {
      input.onkeydown = function(e) {
        e.preventDefault();
        var parts = [];
        if (e.ctrlKey) parts.push('Ctrl');
        if (e.shiftKey) parts.push('Shift');
        if (e.altKey) parts.push('Alt');
        if (e.key !== 'Control' && e.key !== 'Shift' && e.key !== 'Alt') {
          parts.push(e.key.toUpperCase());
        }
        input.value = parts.join('+');
        input.onkeydown = null;
      };
    }

    function saveSettings() {
      var data = {
        default_unit: document.getElementById('default_unit').value,
        decimals: parseInt(document.getElementById('decimals').value),
        auto_save: document.getElementById('auto_save').checked,
        line_width: parseInt(document.getElementById('line_width').value),
        highlight_color: document.getElementById('highlight_color').value,
        show_labels: document.getElementById('show_labels').checked,
        key_activate: document.getElementById('key_activate').value,
        key_panel: document.getElementById('key_panel').value,
      };
      sketchup.on_submit(JSON.stringify(data));
    }
  </script>
</body>
</html>
```

### Example 3: Form Có Accordion (Multi-section Options)

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/main.css">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/fields.css">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/accordion.css">
  <style>
    body { overflow-y: auto; padding: 8px; }
    .accordion-content { display: flex; flex-direction: column; gap: 8px; }
    .form-footer { display: flex; justify-content: center; gap: 8px; padding: 12px 0; }
  </style>
</head>
<body>
  <div class="accordion-item expanded">
    <div class="accordion-header active" onclick="toggleAccordion(this)">
      <span class="accordion-title">Geometry</span>
    </div>
    <div class="accordion-content">
      <div class="form-field">
        <div class="field-header"><label>Width (mm)</label></div>
        <input type="number" id="width" value="600">
      </div>
      <div class="form-field">
        <div class="field-header"><label>Height (mm)</label></div>
        <input type="number" id="height" value="400">
      </div>
      <div class="form-field">
        <div class="field-header"><label>Thickness (mm)</label></div>
        <input type="number" id="thickness" value="1.2" step="0.1">
      </div>
    </div>
  </div>

  <div class="accordion-item">
    <div class="accordion-header" onclick="toggleAccordion(this)">
      <span class="accordion-title">Material & Finish</span>
    </div>
    <div class="accordion-content" style="display: none;">
      <div class="form-field">
        <div class="field-header"><label>Material</label></div>
        <select id="material">
          <option value="galvanized">Galvanized Steel</option>
          <option value="stainless">Stainless Steel</option>
          <option value="aluminum">Aluminum</option>
        </select>
      </div>
      <div class="form-field">
        <div class="field-header"><label>Màu sắc</label></div>
        <input type="color" id="mat_color" value="#c0c0c0" style="width: 48px; height: 24px; border: 1px solid var(--color-input-border); border-radius: 4px;">
      </div>
    </div>
  </div>

  <div class="accordion-item">
    <div class="accordion-header" onclick="toggleAccordion(this)">
      <span class="accordion-title">Connections</span>
    </div>
    <div class="accordion-content" style="display: none;">
      <div class="form-field">
        <div class="field-header"><label>Connection type</label></div>
        <div class="radio-option"><label><input type="radio" name="conn" value="flange" checked> Flange</label></div>
        <div class="radio-option"><label><input type="radio" name="conn" value="slip"> Slip-in</label></div>
        <div class="radio-option"><label><input type="radio" name="conn" value="weld"> Welded</label></div>
      </div>
      <div class="enum-field">
        <label><input type="checkbox" id="gasket"><span>Include gasket</span></label>
      </div>
    </div>
  </div>

  <div class="form-footer">
    <button class="popup-button" onclick="sketchup.on_cancel()">Cancel</button>
    <button class="popup-button popup-button-info" onclick="submitForm()">Create</button>
  </div>

  <script>
    function toggleAccordion(header) {
      var item = header.parentElement;
      var content = header.nextElementSibling;
      var isExpanded = item.classList.contains('expanded');
      item.classList.toggle('expanded');
      header.classList.toggle('active');
      content.style.display = isExpanded ? 'none' : '';
    }

    function submitForm() {
      var data = {
        width: parseFloat(document.getElementById('width').value),
        height: parseFloat(document.getElementById('height').value),
        thickness: parseFloat(document.getElementById('thickness').value),
        material: document.getElementById('material').value,
        mat_color: document.getElementById('mat_color').value,
        connection: document.querySelector('input[name="conn"]:checked').value,
        gasket: document.getElementById('gasket').checked,
      };
      sketchup.on_submit(JSON.stringify(data));
    }
  </script>
</body>
</html>
```

### Example 4: Toolbar + Form Combo (Tool Options Panel)

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/main.css">
  <link rel="stylesheet" href="../../../000_vbo_core/ui/css/fields.css">
  <style>
    body { overflow: hidden; padding: 0; margin: 0; display: flex; flex-direction: column; height: 100vh; }
    .toolbar { border-bottom: 1px solid var(--color-input-border); padding: 4px 8px; display: flex; align-items: center; gap: 4px; }
    .toolbar-button { width: 24px; height: 24px; border: none; background: transparent; border-radius: 4px; cursor: pointer; display: flex; align-items: center; justify-content: center; }
    .toolbar-button:hover { background: var(--color-hover); }
    .toolbar-button.active { border-bottom: 2px solid var(--color-primary); }
    .toolbar-sep { border-left: 1px solid var(--color-input-border); height: 16px; margin: 0 4px; }
    .panel { flex: 1; padding: 8px; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; }
    .status-bar { padding: 4px 8px; font-size: 10px; color: var(--color-text-light); border-top: 1px solid var(--color-input-border); }
  </style>
</head>
<body>
  <div class="toolbar">
    <button class="toolbar-button active" id="btn_draw" title="Draw mode" onclick="setMode('draw')">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25z"/></svg>
    </button>
    <button class="toolbar-button" id="btn_edit" title="Edit mode" onclick="setMode('edit')">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
    </button>
    <div class="toolbar-sep"></div>
    <input class="toolbar-input" type="text" id="filter" placeholder="Filter..." style="width: 80px;" oninput="filterItems(this.value)">
    <div style="flex: 1;"></div>
    <button class="toolbar-button" title="Settings" onclick="sketchup.open_settings()">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.07.62-.07.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>
    </button>
  </div>

  <div class="panel">
    <div class="form-field">
      <div class="field-header"><label>Size (mm)</label></div>
      <input type="number" id="size" value="100" min="10">
    </div>
    <div class="form-field">
      <div class="field-header"><label>Spacing (mm)</label></div>
      <input type="number" id="spacing" value="500" min="50">
    </div>
    <div class="form-field">
      <div class="field-header"><label>Alignment</label></div>
      <select id="alignment">
        <option value="center">Center</option>
        <option value="left">Left</option>
        <option value="right">Right</option>
      </select>
    </div>
    <div class="enum-field">
      <label><input type="checkbox" id="snap_grid" checked><span>Snap to grid</span></label>
    </div>
  </div>

  <div class="status-bar">
    <span id="status">Ready</span>
  </div>

  <script>
    var currentMode = 'draw';

    function setMode(mode) {
      currentMode = mode;
      document.querySelectorAll('.toolbar-button').forEach(function(b) { b.classList.remove('active'); });
      document.getElementById('btn_' + mode).classList.add('active');
      document.getElementById('status').textContent = mode.charAt(0).toUpperCase() + mode.slice(1) + ' mode';
      sketchup.on_mode_change(mode);
    }

    function filterItems(text) {
      // Custom filter logic
      sketchup.on_filter(text);
    }
  </script>
</body>
</html>
```

---

## Tips

1. **Responsive:** Dùng flex layout, không fixed width — dialog resize tốt
2. **DPI:** CSS var `--scale-factor` tự scale; nếu cần thêm, dùng `UI.scale_factor` từ Ruby gửi sang
3. **Scrollbar:** Thêm class `panel-scrollable` để có thin scrollbar đẹp
4. **Focus style:** Input focus tự có border highlight (từ fields.css)
5. **Dark mode:** Chưa hỗ trợ �� VBO UI dùng light theme cố định
6. **Placeholder:** Dùng italic, màu nhạt `#b8b8b8` (đã có trong CSS)
7. **Validation:** Highlight lỗi bằng `border-color: var(--color-danger)` + text đỏ bên dưới
