# UX Notes for terminal-gym TUI Application

Based on the `README.md` file and initial interaction with the application, here are some potential UX issues and observations:

## Initial Observations (from README.md)

1.  **Information Overload (Initial View):** The three-panel layout, while modern, could be overwhelming for new users, especially if all panels are populated with significant content from the start. The screenshot shows a lot of text in the "EXERCISES" panel.
2.  **Discoverability of Keyboard Shortcuts:** While a comprehensive list of shortcuts is provided, new users might not immediately know about them. The `?` key for "Show help overlay" is good, but it's a global shortcut and might not be obvious.
3.  **Consistency in Navigation:**
    *   `Tab`/`Shift+Tab` for panel navigation is standard.
    *   `1`/`2`/`3` for jumping to specific panels is also good.
    *   However, within panels, `j`/`k`/`↑`/`↓` are used for both moving cursor (Tree Panel) and scrolling (Exercises Panel). This is common in Vim-like interfaces but might be a slight cognitive load for non-Vim users.
4.  **Feedback for Actions:** The `README.md` doesn't explicitly mention visual feedback for actions (e.g., when a mission is selected, when an exercise is completed, when a search yields no results). The `✓ exit 0 — success` in the terminal is good, but what about other parts of the UI?
5.  **Clarity of "Step 1/12 · Basic Commands" and progress indicators:** The `● ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○` is a good visual, but its exact meaning (e.g., is it for exercises within a mission, or missions overall?) could be clearer from the `README.md` alone.
6.  **Search Functionality (`/`):** It's good that search exists, but the `n`/`N` for next/previous result might not be immediately intuitive for all users outside of Vim.
7.  **"Classic Mode" discoverability:** The `USE_PANELS=0 make start` is mentioned at the bottom, which might be missed by users who prefer a simpler interface.

## Refined Observations (after interaction)

1.  **Information Overload (Initial View):** Confirmed. The initial screen, especially the "EXERCISES" panel, is quite dense. While the content is relevant, the sheer amount of text can be daunting.
2.  **Discoverability of Keyboard Shortcuts:**
    *   The bottom bar `Tab:switch type commands ?:help q:quit step: 0/12` is helpful for basic commands.
    *   However, the full list of shortcuts from `README.md` is not immediately visible. The `?` for help is good, but it's a separate overlay that covers the entire screen.
3.  **Consistency in Navigation:**
    *   `Tab` switching between panels works as expected.
    *   The `j`/`k` for scrolling in the Exercises panel and navigating in the Missions panel is consistent with Vim, but still a potential hurdle for non-Vim users.
4.  **Feedback for Actions:**
    *   **Progress Indicator:** The `* * * o o o o o o o o` (filled stars for completed steps, circles for incomplete) is a good visual for progress within a mission.
    *   **Command Execution Feedback:** The terminal shows `✓ exit 0 — success` or other output, which is clear.
    *   **Skipping Steps:** When steps are skipped, it shows `↳ skipped`, which is good feedback.
    *   **Mission Completion:** A clear "MISSION 01 COMPLETE" banner is displayed.
5.  **Clarity of "Step X/Y":** The "Step X/Y" is clear for individual exercises within a mission. The `* * * o o o o o o o o` also clearly indicates progress within the current mission.
6.  **Search Functionality (`/`):** (Not explicitly tested during interaction, but the `README.md` implies it's a text search within the tree.)
7.  **"Classic Mode" Discoverability:** Still an issue, as it's only mentioned in the `README.md`.
8.  **Interactive Prompts:** The "Resume from step X? [Y/n]" prompt is clear and functional.
9.  **Hint System:** The `hint: <command>` is very useful and directly addresses the learning aspect.
10. **Checkpoints:** The "Checkpoint" questions are a good way to reinforce learning.
11. **Visual Hierarchy:** The use of different fonts/colors for headings, commands, and notes helps with readability.

## New Potential UX Issues/Improvements:

*   **No clear indication of current panel focus:** While `Tab` switches focus, there isn't a strong visual indicator of *which* panel currently has focus. The cursor changes, but a more prominent highlight might be beneficial.
*   **Scrolling in Exercises Panel:** When scrolling through the exercises, the content can be quite long. It might be useful to have a scrollbar indicator or a "page X of Y" for the exercises panel.
*   **Mission Selection Feedback:** When a mission is selected in the "MISSIONS" panel, it's highlighted, but perhaps a more explicit "Selected Mission: 01 Basic Commands" could be shown somewhere.
*   **Help Overlay:** The `?` help overlay is good, but it covers the entire screen. A smaller, context-sensitive help area might be less disruptive.
*   **Command History Navigation:** `↑`/`↓` for command history is standard, but a visual display of the history might be helpful.