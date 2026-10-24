# Content

Subjects, chapters and cards are written in a Google Sheet. This folder turns
the sheet into the app's deck files (`assets/decks/class_N.json`). The sheet
is the source: don't edit the deck files by hand.

Needs Node 22 or later, and nothing else (no `npm install`).

## Start the sheet (once)

```
npm run template
```

This writes `out/RevUp content.xlsx` from the decks in the app. Upload it to
Google Drive, then open it with Google Sheets (File → Save as Google Sheets).
The **Read me** tab explains every column.

## Publish changes

Download the sheet (File → Download → Microsoft Excel), then:

```
npm run export -- --file "path/to/RevUp content.xlsx"
```

If the sheet is shared as "Anyone with the link: Viewer", `--sheet <link>`
downloads it directly. Add `--check` to only check, without writing.

Errors (a duplicate ID, a missing chapter, a cell Sheets turned into a date…)
stop the export and give the tab and row. Warnings, such as a flashcard asking
"Which of these…?" without showing the options, are printed but don't stop
it. Then rebuild the app, or later publish the decks to Firebase Hosting.

## Tests

```
npm test
```
