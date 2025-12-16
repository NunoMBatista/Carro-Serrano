# Dialogue System Specifications

## Overview
- Two parallel dialogue branches: **good** and **bad**.
- Each step presents three choices: **positive**, **neutral**, **negative**.
- Branch switching rules:
	- Positive choice → switch to good branch (or stay if already there).
	- Negative choice → switch to bad branch (or stay if already there).
	- Neutral choice → if empathy ≥ threshold, switch/stay good; else switch/stay bad.
- Empathy effects per step:
	- In good branch: empathy increases by `empathy_gain_per_step` (clamped to 0–100).
	- In bad branch: empathy decreases by `empathy_loss_per_step` (clamped to 0–100).
- Starting branch for each hitchhiker dialogue (after the first): good if empathy ≥ threshold, else bad.
- Branch titles are defined as ordered lists for good and bad paths.

## Implementation (current code)
- Autoload `DialogueFlow` (`scripts/dialogue_flow.gd`): orchestrates branch selection, step advancement, and empathy changes.
	- Exports: `empathy_threshold`, `empathy_gain_per_step`, `empathy_loss_per_step`, `dialogue_resource`, `good_branch_titles`, `bad_branch_titles`, `debug_overlay_enabled`.
	- State: `current_branch`, `current_step`, `is_dialogue_active`.
	- Start: `start_hitchhiker_dialogue(idx)` sets starting branch by empathy and begins at step 0.
	- On response: `handle_response_selected(response)` reads `response.tags` or `response.get_tag_value("alignment")` to detect alignment (positive/neutral/negative), switches branch per rules, advances step, and starts the next title if available. Responses pointing to `END`/`END_CONVERSATION`/empty are handed off to the default DM flow.
	- Titles: `_current_title()` picks the indexed title from the active branch list; empty if out of range.
	- Debug: optional overlay shows empathy, branch, step.
	- Mouse: `_start_current_title` frees mouse (`VISIBLE`) so options can be clicked.

- Autoload `PlaytestLogger` (`scripts/playtest_logger.gd`): tracks empathy and logs actions/events. Empathy setters clamp 0–100.

- `GameManager` (`scripts/game_manager.gd`):
	- D dialogue: runs `PROTOTYPE_DIALOGUE`, sets both branches to `["start"]`.
	- G test dialogue: loads `dialogue/test_branch.dialogue`, branches `["good_1","good_2"]` and `["bad_1","bad_2"]`.
	- Both start with mouse visible and delegate to `DialogueFlow`.

- `example_balloon.gd` (Dialogue Manager balloon):
	- Frees/locks mouse visible during dialogue; re-captures on finish.
	- Hides response menu immediately on selection; if response ends conversation, hides and frees.

## Authoring dialogues
- Write two parallel sequences of title blocks: e.g., `good_1 -> good_2 -> ...` and `bad_1 -> bad_2 -> ...`.
- Set `DialogueFlow.good_branch_titles` and `DialogueFlow.bad_branch_titles` to the ordered titles.
- Tag each response with `#alignment=positive|neutral|negative` (or include those words in tags) so branching knows which way to flip.
- Use `=> END` (or `END_CONVERSATION`) to terminate a path; DialogueFlow will hand off to default DM flow when `next_id` is END.

## Empathy & branch logic summary
- Starting branch per encounter: good if `empathy >= empathy_threshold`, else bad.
- Per step: apply empathy delta based on current branch (gain if good, loss if bad, clamped 0–100).
- Choice alignment effects: positive → good; negative → bad; neutral → good if empathy ≥ threshold else bad.
- Step advancement: after each response, increment step and move to the corresponding title in the active branch; if no title exists, stop and let DM end.

## Debug and mouse behavior
- Debug overlay (toggle `debug_overlay_enabled`) shows empathy, branch, step.
- Mouse is set to `VISIBLE` when a dialogue step starts; balloon re-captures on finish so camera can move again.

## Known issues (current behavior)
- Some reports of the G test dialogue restarting once after an END path; mitigations added (active flag reset, explicit `dialogue_ended` emits), but if it persists, check for multiple balloons or external listeners re-opening dialogue.
