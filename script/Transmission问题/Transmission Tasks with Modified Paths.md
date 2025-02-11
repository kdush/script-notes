## Scenario Description
While dismantling a wall switch, I accidentally triggered the whole-house air switch, causing the server to restart. After the reboot, I discovered that all Transmission tasks had been reset to the default directory. Since there are too many tasks to move manually, I hope to use a script to batch move the tasks back to their original directories.

## Problem Analysis
1. First, I confirmed that the original files still exist; the results showed that no files were lost.
2. Checking the Transmission configuration file (settings.json) revealed that all task download paths had been changed to the default download directory. Therefore, restoring all task download paths to the specified directory is all that is needed.
3. Although my Transmission runs in a Docker container, the script is executed directly inside the container, so there is no need to consider directory mapping; it can be treated as an independent system.
4. The actual file storage path is located under `/downloads/incomplete/`, but most tasks have their download paths modified to `/downloads/incomplete/movie/xxx`, and all tasks are in the Stopped state.

## Proposed Solution
1. Retrieve the task list and store task information in an array.
2. Recursively traverse the directory tree under `/downloads/incomplete/` to search for all files and folders.
3. Compare the names of the files/folders with those in the task list. If a match is found, update the task’s download path to the correct specified directory.

[fix_path.sh]: ./fix_path.sh