/**
 * Add new keys from string_mapping.json to both ARB files
 */
const fs = require('fs');
const mapping = JSON.parse(fs.readFileSync('scripts/string_mapping.json','utf8'));
const viArb = JSON.parse(fs.readFileSync('lib/l10n/app_vi.arb','utf8'));
const enArb = JSON.parse(fs.readFileSync('lib/l10n/app_en.arb','utf8'));

let added = 0;
let skipped = 0;

for (const [viStr, info] of Object.entries(mapping)) {
  if (!info.isNew) { skipped++; continue; }
  const key = info.key;
  if (viArb[key] !== undefined) {
    // Key already exists, skip
    skipped++;
    continue;
  }
  viArb[key] = info.vi;
  enArb[key] = info.en;
  added++;
}

// Write back with proper formatting
fs.writeFileSync('lib/l10n/app_vi.arb', JSON.stringify(viArb, null, 2), 'utf8');
fs.writeFileSync('lib/l10n/app_en.arb', JSON.stringify(enArb, null, 2), 'utf8');
console.log(`Added ${added} new keys. Skipped ${skipped}.`);
