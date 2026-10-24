# Runtime source ownership

Edit the ordered source sections listed in manifest.json, then run `node tools.mjs source`.
`app.js` and `styles.css` at repository root are generated delivery files. `node tools.mjs verify-source` rejects stale generated files; build and CI enforce this check.

JavaScript sections deliberately share one module scope: existing exports, event owners and function identity stay intact. These are build-time sections, not independently imported browser modules. No additional network requests, bundler dependency or framework is introduced. Report renderers remain isolated in their existing sections.

CSS sections retain explicit cascade order in the manifest. Do not sort selectors or move declarations across media queries. New changes belong to the relevant section rather than an appended override layer. Existing historical overrides are retained where deleting them would change approved rendering.
