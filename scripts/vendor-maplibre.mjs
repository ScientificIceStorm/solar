// Copies the official MapLibre GL JS build from node_modules into site/vendor/ so the site
// keeps deploying as plain static files. Run `npm run build` after changing the version.
import {copyFile, mkdir, readFile, rm, writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';

const root = new URL('../', import.meta.url);
const source = new URL('node_modules/maplibre-gl/', root);
const target = new URL('site/vendor/maplibre-gl/', root);
export const files = ['dist/maplibre-gl.mjs', 'dist/maplibre-gl-worker.mjs', 'dist/maplibre-gl.css', 'LICENSE.txt'];

const {version} = JSON.parse(await readFile(new URL('package.json', source), 'utf8'));
await rm(target, {recursive: true, force: true});
await mkdir(target, {recursive: true});
for (const file of files) {
  const destination = new URL(file.split('/').pop(), target);
  await copyFile(new URL(file, source), destination);
  // The source maps are not published, so drop the comments that would request them.
  if (/\.(mjs|css)$/.test(file)) {
    const text = await readFile(destination, 'utf8');
    await writeFile(destination, text.replace(/\n?(\/\/|\/\*)# sourceMappingURL=\S+( \*\/)?\s*$/, '\n'));
  }
}
await writeFile(new URL('version.js', target), `export const maplibreVersion = '${version}';\n`);
console.log(`Copied MapLibre GL JS ${version} to ${fileURLToPath(target)}`);
