#!/bin/bash
# ============================================================
# MyEditingTimeApp Generator
# This script creates the Google Apps Script project package
# for the Editing Time Tracking App.
# ============================================================

# Create project directory
PROJECT_DIR="MyEditingTimeApp"
mkdir -p "$PROJECT_DIR"

# Create Code.gs with the main application code
cat << 'EOF' > "$PROJECT_DIR/Code.gs"
// Code.gs - Google Apps Script for Tracking Editing Time on Google Drive Files

/**
 * Main function to generate the editing time report.
 * It filters files based on criteria, fetches editing events,
 * groups events into sessions, calculates total editing time,
 * and generates a report.
 */
function generateEditingTimeReport() {
  // Define criteria for file selection:
  // Example: Google Docs modified in the last 30 days.
  var fileCriteria = {
    mimeType: 'application/vnd.google-apps.document',
    modifiedAfter: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
  };
  
  var files = getFilesByCriteria(fileCriteria);
  var reportResults = [];
  
  for (var i = 0; i < files.length; i++) {
    var file = files[i];
    var events = fetchEditingEvents(file.getId());
    if (events.length === 0) {
      continue;
    }
    var sessions = groupEventsIntoSessions(events);
    var totalTime = 0;
    for (var j = 0; j < sessions.length; j++) {
      totalTime += calculateSessionDuration(sessions[j]);
    }
    reportResults.push({
      fileId: file.getId(),
      fileName: file.getName(),
      totalEditingTimeMinutes: totalTime
    });
  }
  
  generateReport(reportResults);
}

/**
 * Retrieves files from Google Drive matching the given criteria.
 * Uses DriveApp to filter by MIME type and modification date.
 */
function getFilesByCriteria(criteria) {
  var files = [];
  var fileIterator = DriveApp.getFilesByType(criteria.mimeType);
  while (fileIterator.hasNext()) {
    var file = fileIterator.next();
    if (file.getLastUpdated() >= criteria.modifiedAfter) {
      files.push(file);
    }
  }
  return files;
}

/**
 * Fetches editing events for a file using the Drive Activity API.
 * NOTE: You must enable the Drive Activity API and set the proper OAuth scopes.
 */
function fetchEditingEvents(fileId) {
  var events = [];
  var url = 'https://driveactivity.googleapis.com/v2/activity:query';
  
  // Construct request payload
  var payload = {
    "itemName": "items/" + fileId,
    "filter": "detail.action_detail_case:EDIT"
  };
  
  var options = {
    'method': 'post',
    'contentType': 'application/json',
    'payload': JSON.stringify(payload),
    'muteHttpExceptions': true
  };
  
  try {
    var response = UrlFetchApp.fetch(url, options);
    var result = JSON.parse(response.getContentText());
    if (result.activities) {
      for (var i = 0; i < result.activities.length; i++) {
        var activity = result.activities[i];
        var timestamp = extractTimestamp(activity);
        if (timestamp) {
          events.push({ timestamp: new Date(timestamp) });
        }
      }
    }
  } catch(e) {
    Logger.log("Error fetching events for file " + fileId + ": " + e);
  }
  
  // Sort events by timestamp
  events.sort(function(a, b) {
    return a.timestamp - b.timestamp;
  });
  
  return events;
}

/**
 * Extracts a timestamp from a Drive Activity event.
 * Adjust this function based on the actual structure of the event object.
 */
function extractTimestamp(activity) {
  if (activity.timestamp) {
    return activity.timestamp;
  } else if (activity.timeRange && activity.timeRange.endTime) {
    return activity.timeRange.endTime;
  }
  return null;
}

/**
 * Groups a list of events into sessions.
 * A new session starts if the gap between events exceeds 5 minutes.
 */
function groupEventsIntoSessions(events) {
  var sessions = [];
  if (events.length === 0) return sessions;
  
  var thresholdMillis = 5 * 60 * 1000; // 5 minutes in milliseconds
  var currentSession = [events[0]];
  
  for (var i = 1; i < events.length; i++) {
    var gap = events[i].timestamp - events[i-1].timestamp;
    if (gap <= thresholdMillis) {
      currentSession.push(events[i]);
    } else {
      sessions.push(currentSession);
      currentSession = [events[i]];
    }
  }
  sessions.push(currentSession);
  return sessions;
}

/**
 * Calculates the duration of a session in minutes.
 * The duration is the difference between the last and first event timestamps,
 * with a minimum duration of 1 minute per session.
 */
function calculateSessionDuration(session) {
  if (session.length === 0) return 0;
  var durationMillis = session[session.length - 1].timestamp - session[0].timestamp;
  var durationMinutes = Math.max(1, Math.round(durationMillis / (60 * 1000)));
  return durationMinutes;
}

/**
 * Generates a report from the editing time results.
 * Currently logs the report; you could extend this to write to a spreadsheet.
 */
function generateReport(results) {
  if (results.length === 0) {
    Logger.log("No editing events found for the specified criteria.");
    return;
  }
  
  Logger.log("Editing Time Report:");
  for (var i = 0; i < results.length; i++) {
    var r = results[i];
    Logger.log("File: " + r.fileName + " (ID: " + r.fileId + ") - Total Editing Time: " + r.totalEditingTimeMinutes + " minutes");
  }
}
EOF

# Create appsscript.json for project configuration and OAuth scopes
cat << 'EOF' > "$PROJECT_DIR/appsscript.json"
{
  "timeZone": "America/Los_Angeles",
  "exceptionLogging": "STACKDRIVER",
  "oauthScopes": [
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/script.external_request",
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/script.scriptapp"
  ],
  "dependencies": {},
  "runtimeVersion": "V8"
}
EOF

# Create README.md with project documentation
cat << 'EOF' > "$PROJECT_DIR/README.md"
# MyEditingTimeApp

## Overview
MyEditingTimeApp is a Google Apps Script application designed to estimate the time you spend editing Google Drive files based on specific criteria. It uses the Drive Activity API to fetch editing events, groups them into sessions (using a 5‑minute threshold), calculates the total editing time (with a minimum session length of 1 minute), and generates a report.

## Functional Specifications
- **File Filtering:** Retrieves files (e.g., Google Docs modified in the last 30 days).
- **Event Retrieval:** Uses the Drive Activity API to fetch edit events.
- **Session Grouping:** Groups editing events into sessions if they occur within 5 minutes.
- **Time Calculation:** Computes total editing time per file.
- **Reporting:** Outputs a report via Logger (or can be extended to use a spreadsheet).

## Deployment Instructions
1. Run this bash script to create the project package:
   \`\`\`
   ./<this_script_name>.sh
   \`\`\`
2. Open [Google Apps Script](https://script.google.com/) and create a new project.
3. Import the files from the \`MyEditingTimeApp\` directory (Code.gs and appsscript.json).
4. Review the README.md for further details.

## Note
Ensure the Drive Activity API is enabled in your Google Cloud project and that you have the necessary OAuth scopes.
EOF

echo "Software package 'MyEditingTimeApp' created successfully."
echo "Files have been generated in the '$PROJECT_DIR' directory."
echo "To deploy, open Google Apps Script and import the Code.gs and appsscript.json files."
