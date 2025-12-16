# Dialogue Writing Guide

## Overview

This system uses **Dialogue Manager 3** with a custom `DialogueFlow` autoload that handles empathy-based branching.

## Core Concepts

### Empathy System
- Empathy ranges from **0 to 100** (starts at 50)
- **Threshold** (default 50): determines branch direction for neutral choices
- **Good branch**: empathy increases each step (+5 default)
- **Bad branch**: empathy decreases each step (-10 default)

### Choice Alignments
| Alignment | Effect |
|-----------|--------|
| `positive` | Switch to good branch |
| `negative` | Switch to bad branch |
| `neutral` | Good if empathy ≥ threshold, else bad |

## Basic Syntax

### Starting a Dialogue Title
```
~ title_name
```

### Character Lines
```
Character: What they say.
```

### Player Choices
```
- Choice text #optional_tag
    Character: Response to that choice.
    => next_title
```

## Branching System

### Method 1: Call choice() then jump to branch-specific titles
```
- I'll help you. #positive
    do DialogueFlow.choice("positive")
    => step2_good

- I don't care. #negative
    do DialogueFlow.choice("negative")
    => step2_bad
```

### Method 2: Use conditions for inline branching
```
- Maybe... #neutral
    do DialogueFlow.choice("neutral")
    [if DialogueFlow.is_good()] Character: Thanks for understanding.
    [if DialogueFlow.is_bad()] Character: Whatever.
    [if DialogueFlow.is_good()] => step2_good
    [if DialogueFlow.is_bad()] => step2_bad
```

### Method 3: Direct empathy modification
```
do DialogueFlow.empathy += 10
do DialogueFlow.empathy -= 5
```

## File Structure Template

```
~ start

Character: Opening line.

- Positive choice #positive
    do DialogueFlow.choice("positive")
    => step1_good

- Neutral choice #neutral
    do DialogueFlow.choice("neutral")
    [if DialogueFlow.is_good()] => step1_good
    [if DialogueFlow.is_bad()] => step1_bad

- Negative choice #negative
    do DialogueFlow.choice("negative")
    => step1_bad

# ===== GOOD BRANCH =====
~ step1_good
Character: Good branch dialogue...
=> ending_good

# ===== BAD BRANCH =====
~ step1_bad
Character: Bad branch dialogue...
=> ending_bad

# ===== ENDINGS =====
~ ending_good
Character: Good ending.
=> END

~ ending_bad
Character: Bad ending.
=> END
```

## Naming Convention

For parallel branches, use suffix naming:
- `step1_good`, `step1_bad`
- `step2_good`, `step2_bad`
- `ending_good`, `ending_bad`

## Triggering Dialogue from Code

```gdscript
# Load and run dialogue
var dialogue = preload("res://dialogue/my_dialogue.dialogue")
DialogueFlow.run_dialogue(dialogue, "start")

# Or with a specific starting title
DialogueFlow.run_dialogue(dialogue, "some_other_title")
```

## Available DialogueFlow Functions

| Function | Usage in .dialogue |
|----------|-------------------|
| `choice(alignment)` | `do DialogueFlow.choice("positive")` |
| `is_good()` | `[if DialogueFlow.is_good()]` |
| `is_bad()` | `[if DialogueFlow.is_bad()]` |
| `empathy` | `do DialogueFlow.empathy += 10` |

## Tips

1. **Always call `choice()` before branching** - it updates empathy and branch state
2. **Use comments** with `#` at line start for organization
3. **Tag choices** with `#positive`, `#neutral`, `#negative` for clarity (optional but recommended)
4. **Test both branches** - press G in-game to test the example dialogue
