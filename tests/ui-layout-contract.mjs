import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const [tailwind, config, operations, styles, manifest] = await Promise.all([
  readFile(new URL('../src/tailwind.css', import.meta.url), 'utf8'),
  readFile(new URL('../tailwind.config.cjs', import.meta.url), 'utf8'),
  readFile(new URL('../src/operations.js', import.meta.url), 'utf8'),
  readFile(new URL('../src/cascade-06.css', import.meta.url), 'utf8'),
  readFile(new URL('../src/manifest.json', import.meta.url), 'utf8')
]);

assert.match(config, /prefix:\s*'tw-'/);
assert.match(config, /preflight:\s*false/);
assert.match(tailwind, /@tailwind components/);
assert.match(tailwind, /@tailwind utilities/);
assert.match(manifest, /src\/tailwind\.generated\.css/);
assert.match(operations, /scope-command-bar','tw-scope-command-bar/);
assert.match(operations, /field\.after\(toggle\)/);
assert.match(operations, /แผนสะสม %/);
assert.match(styles, /#app \.table-density > \.selection-toolbar[\s\S]*margin-inline-start: auto/);
assert.match(styles, /#app \.search-box\.search-field :is\(input\.search, input\[type='search'\]\)/);
assert.match(styles, /#modal \.dialog-footer \{ position: sticky/);
assert.match(styles, /font-variant-numeric: tabular-nums/);
assert.doesNotMatch(styles, /\.main-report\s*\{/);
assert.doesNotMatch(styles, /\.p301-accessible\s*\{/);
console.log('UI layout/Tailwind integration contract passed');
