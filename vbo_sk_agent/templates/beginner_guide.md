# VBO SkAgent — Beginner Guide

Step-by-step prompts to build your first SketchUp plugin with AI.
Just copy a prompt, replace the `[BRACKETS]` with your own description, and paste it into your AI tool.

---

## Step 0: Quick POC (Proof of Concept)

> Use when: You have a simple idea and want to test if it's even possible — before creating a full plugin.

```
I want to try something: [DESCRIBE YOUR IDEA — e.g. "select all faces larger than 10m² and color them red"].

Can you prototype this directly via command.rb first?
Don't create a full plugin yet — just run it as a quick test in SketchUp.
If it works, we'll turn it into a proper plugin later.
```

**Why start here?** Many ideas can be validated in 30 seconds through the bridge. If it doesn't work, you save hours. If it works, you have working code to build on.

---

## Step 1: Create a New Plugin

> Use when: Your POC worked (or your idea needs a full plugin from the start).

```
I want to create a new SketchUp plugin called "[YOUR PLUGIN NAME]".
It should: [SHORT DESCRIPTION — e.g. "draw a 3D pipe between two points"]

Please:
1. Create the folder structure in the Plugins directory
2. Create the entry point file with SketchupExtension registration
3. Create a loader with menu under Extensions
4. Add a placeholder main file with a simple test (draw a line or show a messagebox)
5. Load it into SketchUp via the bridge and confirm it works
```

---

## Step 2: Plan Before You Code

> Use when: You have an idea but don't know where to start.

```
I want my plugin "[YOUR PLUGIN NAME]" to do the following:
- [Feature 1 — e.g. "Let user click two points to draw a pipe"]
- [Feature 2 — e.g. "Show a dialog to pick pipe diameter"]
- [Feature 3 — e.g. "Calculate total pipe length"]

Please create a development plan:
1. Break this into phases (start simple, add features gradually)
2. List the files needed and what each file does
3. Identify which SketchUp API classes I'll need
4. Start with Phase 1 only — we'll do the rest later
```

---

## Step 3: Build Phase 1

> Use when: You have a plan and want to start coding the first feature.

```
Let's implement Phase 1 of "[YOUR PLUGIN NAME]":
[DESCRIBE PHASE 1 — e.g. "User activates the tool, clicks two points, a line is drawn between them"]

Please:
1. Write the code for this phase
2. Load it into SketchUp via the bridge
3. Test it — run a quick check to confirm it loaded without errors
4. Tell me what to do in SketchUp to test it manually (what to click, what to expect)
```

---

## Step 4: Fix Bugs (with limits)

> Use when: Something isn't working and you want AI to find and fix the problem.

```
I tested [WHAT YOU DID] and got this problem:
[DESCRIBE THE ISSUE — e.g. "nothing happens when I click" or "I see an error in the console"]

Please:
1. Inspect the current code
2. Write a test via the bridge to reproduce the issue
3. Fix the bug
4. Reload the fixed code into SketchUp
5. Run the test again to confirm the fix works

IMPORTANT: Maximum 3 retry attempts. If still failing after 3 tries,
stop and explain what's wrong — do NOT keep retrying.
Show me the code before running anything that modifies the model.
```

**Warning:** Always set a retry limit. Without one, AI may keep retrying and corrupt your model. If AI can't fix it in 3 tries, the problem likely needs a different approach — let AI explain the issue so you can decide together.

---

## Step 5: Add a Dialog

> Use when: Your plugin needs user input (numbers, dropdowns, checkboxes).

```
Add a dialog to "[YOUR PLUGIN NAME]" that lets the user:
- [Input 1 — e.g. "Enter pipe diameter (default: 50mm)"]
- [Input 2 — e.g. "Choose material from a dropdown"]
- [Button — e.g. "Click OK to apply"]

Use SketchUp's UI::HtmlDialog. Keep the design simple and clean.
Load it into SketchUp and test that the dialog opens correctly.
```

---

## Step 6: Add a Toolbar

> Use when: You want toolbar buttons for your plugin features.

```
Add a toolbar to "[YOUR PLUGIN NAME]" with these buttons:
- [Button 1 — e.g. "Draw Pipe — activates the pipe drawing tool"]
- [Button 2 — e.g. "Settings — opens the settings dialog"]

Use simple icons (you can use colored rectangles or basic shapes for now).
Load it into SketchUp and confirm the toolbar appears.
```

---

## Step 7: Continue to Next Phase

> Use when: Previous phase works and you're ready for more features.

```
Phase 1 of "[YOUR PLUGIN NAME]" is working. Let's move to Phase 2:
[DESCRIBE PHASE 2]

Please:
1. Review what we have so far
2. Plan what needs to change or be added
3. Implement, load into SketchUp, and test
4. Tell me what to test manually
```

---

## Step 8: Final Check

> Use when: Plugin is feature-complete and you want to verify everything works.

```
Please do a full check on "[YOUR PLUGIN NAME]":
1. Load all files into SketchUp via the bridge
2. Check for any Ruby errors or warnings
3. List all features and confirm each one works
4. Check for common issues: menu duplication, missing icons, undone operations
5. Give me a summary: what works, what needs fixing
```

---

## Step 9: Learn the API

> Use when: You want to know how to do something specific in SketchUp.

```
I want to [DESCRIBE — e.g. "change the color of a selected face to red"].
What SketchUp Ruby API should I use? Show me a working example
and run it in SketchUp to demonstrate.
```

---

## Step 10: Package Your Plugin

> Use when: Plugin is ready to share or distribute.

```
My plugin "[YOUR PLUGIN NAME]" is ready. Please:
1. Review the file structure and make sure it follows SketchUp extension conventions
2. Create a .rbz file (zip the entry point + folder)
3. Tell me how to install it on another computer
```

---

## Sell Your Plugin

Built something great? You can sell it through the **VBO Developer Program**.

**How it works:**
1. Finish and test your plugin thoroughly
2. Email **support@vbosolution.com** with:
   - Plugin name + short description
   - Your .rbz file or GitHub repo link
   - Demo video or screenshots (if available)
3. VBO reviews your code and helps with security (code encryption if needed)
4. Revenue split: **85% for you / 15% for VBO**
5. Your plugin gets listed on the VBO store + Extension Warehouse

**What you get:**
- Distribution channel with existing SketchUp customers worldwide
- Automatic license & activation system (no need to build your own)
- Code encryption to protect your source
- Technical support from the VBO team

Contact: **support@vbosolution.com**
