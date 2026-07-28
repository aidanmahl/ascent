We are switching the build target to the browser. This is infrastructure
work only. Do NOT create new milestones and do NOT advance the milestone
plan — milestone 4 is still an unmet human-verification gate.

CRITICAL: Do not modify any movement code, movement tests, or values in
MovementConfig. Milestone 4 tuning has not happened yet. If web support
appears to require a movement change, stop and tell me instead of doing it.

## 1. Web export

- Confirm web export templates for 4.7.1 are installed. If missing, stop
  and tell me — I'll download them from the editor.
- Create a Web export preset named exactly "Web".
- Threads must be DISABLED. GitHub Pages cannot send the COOP/COEP headers
  that SharedArrayBuffer requires. A threaded build will not run there.
- Confirm the renderer is Compatibility. Do not change it if it is.
- Export target directory is `docs/` with `index.html` as the entry point.

## 2. Build script

Write `tools/build-web.cmd` (plus a `.ps1` if you need the timeout wrapper,
same pattern as validate). It must:
- Run `godot_console --headless --path . --export-release "Web" docs/index.html`
- Use a 600 second timeout, NOT the 120s used by validate.cmd. Web exports
  are slow, especially the first one, and a 120s kill would look like a
  build failure.
- Fail loudly with a nonzero exit if the export errors or if
  docs/index.html, the .wasm, and the .pck are not all present afterward.
- Create `docs/.nojekyll` (empty file) so GitHub Pages serves everything
  verbatim.

Do NOT wire this into validate.cmd. Tests and builds stay separate.

## 3. Web platform fixes

Only what is required for the current build to run in a browser:
- A click-to-start overlay before the game begins. Browsers block audio
  until a user gesture. This is required even though there is no audio yet.
- Remove or guard anything that assumes a desktop environment: OS file
  dialogs, absolute filesystem paths, external process calls, window
  manipulation.
- Do not implement saving yet. That is milestone 7.

## 4. Git

- `.gitignore` must NOT exclude `docs/`. The built game is committed
  deliberately so GitHub Pages can serve it.
- Commit the build output alongside source changes.
- Push to origin/main.

## 5. Verification

Be precise about what you can and cannot verify. You cannot play the game.
Do not claim it is "playable" or "working."

What you CAN verify, and must:
- `tools\validate.cmd` still exits 0. The existing test suite must be
  completely unaffected by this change.
- The export completes and produces index.html, .wasm, .pck, and .js.
- Serving `docs/` on a local HTTP server returns 200 for index.html and for
  each of those assets.
- Report the total size of `docs/`.

Then report: the local URL you served it on, the file list with sizes, and
an explicit statement of what remains unverified until I open it myself.

## 6. Update CLAUDE.md

Add a "Target platform" section: browser build, Compatibility renderer,
no threads, audio requires user gesture, `user://` is async on web, no
desktop-only APIs.

Stop when validate is green, the build is committed and pushed, and you
have reported the above.

----

The web export preset writes to the project root (ascent.html, ascent.wasm,
etc.) instead of docs/index.html as specified. GitHub Pages cannot serve
that layout.

Fix export_presets.cfg so the Web preset exports to docs/index.html.
Re-export, confirm docs/ contains index.html, .wasm, .pck, .js, and
.nojekyll, and that no export artifacts remain in the project root.

Also: tools/ contains a .cmd script using `2>nul` redirection, which
creates a literal file named "nul" when invoked from PowerShell. Replace
all `nul` redirects with a PowerShell-safe equivalent, or move the logic
into the .ps1.

Do not touch movement code or MovementConfig. Run validate.cmd, confirm
it exits 0, commit, and push.