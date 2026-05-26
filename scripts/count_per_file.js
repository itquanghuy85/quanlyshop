const fs = require('fs');
const path = require('path');
const viet = /[àáạảãâầấậẩẫăắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]/i;

function countVI(file) {
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split('\n').map(l => {
    const ci = l.indexOf('//');
    return ci >= 0 ? l.slice(0, ci) : l;
  }).join('\n');
  const set = new Set();
  const re1 = /'([^'\n]*)'/g;
  let m;
  while ((m = re1.exec(lines)) !== null) {
    const s = m[1];
    if (viet.test(s) && s.length >= 2 && s.length <= 80 && !s.includes('${') && !s.startsWith('http')) set.add(s);
  }
  const re2 = /"([^"\n]*)"/g;
  while ((m = re2.exec(lines)) !== null) {
    const s = m[1];
    if (viet.test(s) && s.length >= 2 && s.length <= 80 && !s.includes('${') && !s.startsWith('http')) set.add(s);
  }
  return set.size;
}

const dir = 'lib/views';
const files = fs.readdirSync(dir).filter(f => f.endsWith('.dart'));
const results = files.map(f => ({ file: f, count: countVI(path.join(dir, f)) }));
results.sort((a, b) => b.count - a.count);
results.forEach(r => console.log(r.count + '\t' + r.file));
