const fs = require('fs');
const path = require('path');
const viet = /[àáạảãâầấậẩẫăắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]/i;

function extractStrings(dir) {
  const freq = {};
  let items;
  try { items = fs.readdirSync(dir, {withFileTypes: true}); } catch(e) { return freq; }
  for (const f of items) {
    const full = path.join(dir, f.name);
    if (f.isDirectory()) {
      const sub = extractStrings(full);
      for (const [k,v] of Object.entries(sub)) freq[k] = (freq[k]||0)+v;
    } else if (f.name.endsWith('.dart')) {
      const content = fs.readFileSync(full, 'utf8');
      // Remove // comments
      const lines = content.split('\n').map(l => {
        const ci = l.indexOf('//');
        return ci >= 0 ? l.slice(0, ci) : l;
      }).join('\n');
      // Extract single-quoted strings
      const re1 = /'([^'\n]*)'/g;
      let m;
      while ((m = re1.exec(lines)) !== null) {
        const inner = m[1];
        if (viet.test(inner) && inner.length >= 2 && inner.length <= 80
            && !inner.includes('${') && !inner.startsWith('http')) {
          freq[inner] = (freq[inner]||0)+1;
        }
      }
      // Extract double-quoted strings
      const re2 = /"([^"\n]*)"/g;
      while ((m = re2.exec(lines)) !== null) {
        const inner = m[1];
        if (viet.test(inner) && inner.length >= 2 && inner.length <= 80
            && !inner.includes('${') && !inner.startsWith('http')) {
          freq[inner] = (freq[inner]||0)+1;
        }
      }
    }
  }
  return freq;
}

const freq = extractStrings('lib/views');
const sorted = Object.entries(freq).sort((a,b)=>b[1]-a[1]);
console.log('Total unique VI strings in views:', sorted.length);
// Write to file for analysis
fs.writeFileSync('scripts/vi_strings.json', JSON.stringify(sorted, null, 2));
console.log('Top 150:');
sorted.slice(0, 150).forEach(([s,n]) => console.log(n + '\t' + s));
