const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, addDoc, collection } = require('firebase/firestore');
const fs = require('fs');
(async () => {
  const env = await initializeTestEnvironment({ projectId: 'huyaka-1809',
    firestore: { rules: fs.readFileSync('firestore.rules','utf8'), host: '127.0.0.1', port: 8089 } });
  const U='u1', S1='s_nofield', S2='s_deleted', S3='s_false';
  await env.withSecurityRulesDisabled(async (ctx) => { const db = ctx.firestore();
    await setDoc(doc(db,'shops',S1), { ownerUid: U });
    await setDoc(doc(db,'shops',S2), { ownerUid: U, deleted: true });
    await setDoc(doc(db,'shops',S3), { ownerUid: U, deleted: false });
    await setDoc(doc(db,'users',U), { role: 'owner', shopId: S1 }); });
  const db = env.authenticatedContext(U, { role: 'owner', shopId: S1 }).firestore();
  const p = { shopId: '', name: 'x' };
  for (const [s, expectOk] of [[S1,true],[S2,false],[S3,true]]) {
    const pr = addDoc(collection(db,'shops',s,'product_categories'), {...p, shopId: s});
    try { await (expectOk ? assertSucceeds(pr) : assertFails(pr)); console.log('PASS', s, expectOk?'allowed':'blocked'); }
    catch (e) { console.log('FAIL', s); }
  }
  await env.cleanup(); process.exit(0);
})();
