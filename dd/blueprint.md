# Professional To-Do List App Blueprint

## Overview

A visually stunning and feature-rich to-do list application designed for a modern, intuitive user experience. The app is built with a strong focus on aesthetics, interactivity, and robust architecture, including local persistence to ensure user data is always saved.

## Next Steps

The application is now stable and visually polished. Here are some potential next steps to further enhance its functionality:

1.  **Cloud Sync with Firebase:** Integrate Firebase Firestore to enable real-time data synchronization across multiple devices.
2.  **User Authentication:** Add user authentication to allow users to have their own private to-do lists.
3.  **Push Notifications:** Implement reminders for tasks with due dates.

## Features

*   **Add, Edit & Manage Tasks:** Users can add, view, edit, and mark tasks as complete.
*   **Sub-tasks:** Users can break down complex tasks into smaller, more manageable sub-tasks. Sub-tasks can be added, and their completion status can be toggled within the task editing view.
*   **Task Priorities:** Assign a priority (High, Medium, Low) to each task, visualized with a colored indicator for easy identification.
*   **Advanced Filtering & Sorting:**
    *   Filter tasks to view "All," "Pending," or "Completed."
    *   Sort tasks by priority to bring the most important items to the top.
*   **Dynamic Search:** A search icon in the `AppBar` toggles a search field, allowing users to filter tasks by title in real-time.
*   **Task Persistence:** Tasks are automatically saved to the device and loaded when the app starts, so data is never lost.
*   **Swipe-to-Delete with Undo:** Tasks can be deleted with an intuitive swipe gesture. An "Undo" option is provided in a `SnackBar` to prevent accidental deletions.
*   **Dynamic Animations:** The task list uses `AnimatedList` and `flutter_staggered_animations` for smooth, professional animations when tasks are added or removed.
*   **Theme Control:** A theme toggle allows users to switch between **Light Mode**, **Dark Mode**, and the **System Default** theme.
*   **Enhanced Empty State:** When no tasks are present, a helpful and visually appealing message is displayed.

## Design & Style

*   **Aesthetics:** The app uses a Material 3 design system with a sophisticated color palette and a subtle, off-white/off-black background for a premium feel.
*   **Typography:** It incorporates custom fonts from the `google_fonts` library (`Oswald` for titles, `Roboto` for body text) to create a clear and expressive visual hierarchy.
*   **UI Components:**
    *   Tasks are displayed in individual `Card` widgets with a soft, multi-layered drop shadow and a refined layout.
    *   Interactive elements like the `FloatingActionButton` and `Checkbox` feature a subtle "glow" effect for enhanced interactivity.
    *   A `SegmentedButton` in the `AppBar` provides intuitive controls for filtering tasks.
*   **Layout:** The layout is clean, visually balanced, and responsive, ensuring a great experience on both mobile and web.

## Architecture

*   **State Management:** The app leverages the `provider` package for robust and scalable state management.
    *   `ThemeProvider`: Manages the application's theme state.
    *   `TaskProvider`: Manages the list of tasks, including all CRUD operations, filtering, sorting, and persistence.
*   **Dependencies:**
    *   `provider`: For state management.
    *   `google_fonts`: For custom typography.
    *   `shared_preferences`: For local data persistence.
    *   `flutter_staggered_animations`: For advanced list animations.
