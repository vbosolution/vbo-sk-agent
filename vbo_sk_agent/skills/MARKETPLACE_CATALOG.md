# SkAgent Skill Marketplace

> Last updated: 2026-04-21 | Catalog version: 0.2.0
> Online catalog: https://github.com/vbosolution/skagent-skills (coming soon)

## How to Install

Tell your AI agent: **"install skill [name]"** or manually:
1. Download the skill zip from the link below
2. Extract into `vbo_sk_agent/skills/[skill_name]/`
3. Restart SketchUp (or reload SkAgent)

---

## Built-in Skills (included with SkAgent)

| Skill | Runtime | Description |
|-------|---------|-------------|
| `traverse_model` | ruby | Recursive entity traversal — filter type/depth/hidden, return pid paths |
| `look` | ruby | Vision capture — screenshot viewport + context (camera, selection, entities) |
| `create_tool` | agent | Guide to create interactive tools — 4 patterns + advanced evolution |
| `create_dialog_form` | agent | Guide to create HtmlDialog forms with VBO UI library |

---

## Free Skills (coming soon)

### Model & Geometry
| Skill | Runtime | Description | Status |
|-------|---------|-------------|--------|
| `quick_grid` | ruby | Create construction line grids | Planned |
| `batch_rename` | ruby | Bulk rename components/groups | Planned |
| `section_cut_face` | ruby | Generate section cut faces from section planes | Planned |
| `model_cleanup` | ruby | Purge unused materials/components/layers | Planned |

### Reporting & Export
| Skill | Runtime | Description | Status |
|-------|---------|-------------|--------|
| `material_report` | ruby | Material report: name, area, texture size | Planned |
| `export_csv` | hybrid | Export entity data to CSV file | Planned |
| `model_review` | hybrid | Model quality analysis + HTML report | Planned |

### Productivity & Workflow
| Skill | Runtime | Description | Status |
|-------|---------|-------------|--------|
| `check_mail` | agent | Check inbox, classify by importance | Planned |
| `disk_cleanup` | agent | Scan and clean disk space (Windows) | Planned |
| `session_log` | agent | Write session log markdown | Planned |
| `quick_notes` | agent | Quick notes to markdown file | Planned |
| `project_dashboard` | agent | Project management dashboard | Planned |
| `today_briefing` | agent | Morning briefing (mail + tasks) | Planned |

---

## Premium Skills (coming soon)

| Skill | Price | Runtime | Description |
|-------|-------|---------|-------------|
| `smart_select` | $4.99 | ruby | Advanced pattern-based entity selection |
| `auto_dimension` | $9.99 | ruby | Auto-place dimensions on floor plans |
| `mep_pipe_router` | $19.99 | ruby | Automated MEP pipe routing between points |
| `upgrade_tool_vbo_display` | included | agent | Upgrade tools to VBO Display overlay (requires VBO Core) |

---

## For Developers

Want to create and sell skills? See the VBO Developer Program:
- **Free skills**: Create a skill folder, submit via GitHub PR
- **Paid skills**: Submit source code to VBO for review + .rbe encoding
- Revenue share: 85% developer / 15% VBO

Skill format: `manifest.json` + `README.md` + `main.rb` (see any built-in skill for reference)
