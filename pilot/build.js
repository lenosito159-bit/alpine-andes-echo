import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { Script } from 'node:vm';
const root = new URL('.', import.meta.url);
const read = (path) => readFile(new URL(path, root), 'utf8');
const icon = `data:image/svg+xml;base64,${Buffer.from(await read('icon.svg')).toString('base64')}`;
const scripts = (await Promise.all(['src/domain.js', 'src/storage.js', 'src/app.js'].map(read)))
  .map((source) => source.replace(/^import [\s\S]*?;\n/gm, '').replace(/^export /gm, ''))
  .join('\n')
  .replaceAll('./icon.svg', icon);
const styles = await read('styles.css');
const html = (await read('index.html'))
  .replace('<html lang="es-PE">', '<html lang="es-PE" data-standalone="true">')
  .replace('href="./icon.svg"', `href="${icon}"`)
  .replace(/\s*<link rel="manifest"[^>]+>/, '')
  .replace(/<link rel="stylesheet" href="\.\/styles\.css"\s*\/?>/, () => `<style>${styles}</style>`)
  .replace(
    '<script type="module" src="./src/app.js"></script>',
    () => `<script type="module">\n${scripts}\n</script>`,
  );
new Script(scripts);
if (html.includes('src="./src/app.js"') || html.includes('href="./styles.css"')) {
  throw new Error('El documento autónomo conserva recursos externos; no se generó la entrega.');
}
await mkdir(new URL('dist/', root), { recursive: true });
await writeFile(new URL('dist/Zivlo-Peru.html', root), html);
console.log('Creado dist/Zivlo-Peru.html: aplicación autónoma sin dependencias externas.');
