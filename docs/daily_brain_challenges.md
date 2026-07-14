# Specification: Brain Challenges (Every Other Day)

This document specifies the design, mechanics, and integration plan for the **Brain Challenges** mode in BigBlueBlocks. This mode offers players pre-configured puzzle boards with fixed hurdles or block formations and a set sequence of shapes, encouraging them to return to the app every other day.

---

## 1. Feature Overview & Objectives

1. **Structured Puzzle Play**: Shift the gameplay from high-score survival to strategic, goal-oriented puzzle solving.
2. **Every-Other-Day Engagement**: Dynamically cycle a new challenge every 48 hours to create a regular, recurring habit.
3. **Rewards Without Inflation**: Reward completions with distinctive, persistent trophies and completion streaks (no gameplay-disrupting skins).
4. **Offline Capability**: Retain the application's offline-first architecture by using deterministic calendar calculations or local preloaded puzzle lists.

---

## 2. Gameplay Mechanics & Rules

The Brain Challenges mode operates on a modified version of the core BigBlueBlocks engine:

### A. Pre-configured Puzzle Boards
- Each challenge starts with a pre-configured grid state.
- **Fixed Hurdles**: Coordinates representing hurdles (rendered as glowing red crossed blocks) are placed on the board. Unlike standard mode, these hurdles are **static** and do not randomize or move after pieces are placed.
- **Block Formations**: Boards can start with pre-filled player blocks in specific configurations, creating strategic spacing constraints at the beginning of the challenge.

### B. Predetermined Piece Queue
- Standard random piece generation is disabled.
- The challenge specifies an ordered sequence of pieces (e.g., `[T-Shape, Line-3, Square, L-Shape]`).
- The player's bottom tray displays the current three pieces available from the queue.
- When the player places a piece, the empty slot in the tray is immediately replenished with the next piece from the queue.
- A visual indicator shows the number of remaining pieces left in the queue.

### C. Hurdle Clearance
- Hurdles are normally indestructible blockers in standard mode.
- In **Brain Challenges**, completing a row or column that intersects a hurdle will **clear the hurdle** (removing it from the grid) and clear the player blocks in that row/column.
- Clearing all hurdles is the primary objective.

### D. Win and Lose Conditions
- **Win Condition**: The player clears all hurdles from the board.
- **Lose Conditions**:
  - The player runs out of moves (placements) before clearing all hurdles.
  - The player cannot place any of the active tray pieces on the board (grid lock), even if moves remain.

---

## 3. Data Schema & Models

Challenges are configured via a structured JSON-based model. This allows the app to load a static database of puzzles or fetch new ones in the future.

### Challenge Configuration Schema
```json
{
  "challengeId": "challenge_2026_d196",
  "title": "Hurdle Havoc",
  "dayIndex": 196,
  "maxMoves": 12,
  "fixedHurdles": [
    {"x": 3, "y": 3},
    {"x": 4, "y": 4}
  ],
  "initialBlocks": [
    {"coordinate": {"x": 0, "y": 3}, "colorIndex": 2},
    {"coordinate": {"x": 1, "y": 3}, "colorIndex": 2},
    {"coordinate": {"x": 2, "y": 3}, "colorIndex": 3}
  ],
  "pieceQueue": [
    {"type": "I_3", "colorIndex": 3},
    {"type": "O_4", "colorIndex": 2},
    {"type": "L_3", "colorIndex": 4},
    {"type": "T_4", "colorIndex": 3}
  ],
  "trophy": {
    "name": "Sapphire Cross",
    "icon": "trophy_sapphire_cross"
  }
}
```

### Grid State Model
During a challenge run, the 8x8 grid represents state as follows:
- `0`: Empty Cell
- `1`: Hurdle (Static)
- `2, 3, 4`: Player placed blocks (different colors)

---

## 4. UI/UX Flow & Wireframes

### A. Main Dashboard Entry Point
- A prominent "Brain Challenge" card on the main menu.
- Displays:
  - Active challenge title.
  - Current completion status (Completed / In Progress).
  - Time remaining until the next challenge (e.g., `Reset in 1d 4h`).
  - Active completion streak indicator (e.g., `5-Day Streak 🔥`).

### B. Gameplay Screen (Challenge Mode)
- **Top Bar**: Displays the remaining moves counter (e.g., `Moves Left: 8/12`) and remaining hurdles count (e.g., `Hurdles: 2/4`).
- **Board Grid**: Shows the static hurdles and pre-placed blocks.
- **Piece Tray**: Standard three-slot drawer, showing a preview of upcoming queue shapes (e.g., small "Next up: [shape]" indicator).
- **Control Options**: A "Restart Challenge" button, permitting infinite retries within the active 48-hour window.

### C. Reward & Achievement Flow
- **Trophy Room / Cabinet**: Accessible from the menu or a profile overlay. Renders a grid of shelves containing earned trophies.
- **Completed Trophies**: Highlighted in vibrant gold/color. Selecting a trophy reveals details: *Completed on [Date], Cleared in 8 moves*.
- **Unearned/Missed Trophies**: Displayed as grayed-out silhouettes.

---

## 5. Retention Mechanics & Engagement

To drive player retention every other day, the app leverages two primary local features:

### A. Local Bi-Daily Reminders
1. **Adaptive Scheduling**: When a challenge is completed, the app automatically schedules a notification for exactly 48 hours later (when the next challenge goes live).
2. **Nudge Notifications**: If a challenge is active but unplayed, a local notification fires in the evening of the second day: *"Only 12 hours left to beat 'Hurdle Havoc' and claim your Sapphire Cross trophy! 🧠🏆"*.

### B. The Completion Streak
- Completing challenges in consecutive cycles increments the streak count.
- If a cycle passes (48 hours) without completion, the streak resets to zero.
- Streaks are prominently displayed on the challenge entry card to trigger loss aversion.

---

## 6. Persistence & Offline State Management

Progress is stored locally using `SharedPreferences`.

### Keys to Persist
- `active_challenge_id`: Stores the ID of the challenge currently in progress.
- `active_challenge_moves`: Remaining moves for the current session.
- `active_challenge_grid`: Serialized 8x8 list representing the current layout.
- `completed_challenges`: Set of strings containing IDs of completed challenges (e.g., `['challenge_2026_d194', 'challenge_2026_d196']`).
- `earned_trophies`: JSON-serialized list of earned trophy objects.
- `current_streak`: Integer representing the current bi-daily completion streak.
- `last_completion_timestamp`: Epoch milliseconds of the last completed challenge to validate streak continuity.
