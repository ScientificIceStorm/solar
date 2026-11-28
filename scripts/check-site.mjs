// Syntax-checks every first-party script on the website. There is no bundler or type system.
import {execFileSync} from 'node:child_process';
import {readdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const scripts = ['site', 'site/map', 'scripts', 'test/site'].flatMap((folder) =>
  readdirSync(root + folder).filter((name) => /\.m?js$/.test(name)).map((name) => folder + '/' + name));
for (const script of scripts) execFileSync(process.execPath, ['--check', script], {cwd: root, stdio: 'inherit'});
console.log(`Checked ${scripts.length} scripts.`);
