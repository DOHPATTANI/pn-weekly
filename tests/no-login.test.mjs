import{test}from'node:test';import assert from'node:assert/strict';
test('Supabase RPC works without Auth endpoints, user JWT, password or UID',async()=>{
 const m=new Map();globalThis.localStorage={getItem:k=>m.get(k)||null,setItem:(k,v)=>m.set(k,v),removeItem:k=>m.delete(k)};const calls=[];
 globalThis.fetch=async(url,opts)=>{calls.push({url,...opts});if(url.endsWith('pn2_load_workspace'))return new Response(JSON.stringify({version:1,revision:4}));const b=JSON.parse(opts.body);return new Response(JSON.stringify(b.expected_revision===4?{revision:5}:{message:'revision conflict'}),{status:b.expected_revision===4?200:409});};
 const c=await import('../cloud.js');c.setConfig('https://example.supabase.co','sb_publishable_test');assert.equal((await c.loadCloud()).revision,4);assert.equal((await c.saveCloud({version:1},4)).revision,5);assert.equal(calls.at(-1).headers.apikey,'sb_publishable_test');assert.equal(calls.at(-1).headers.Authorization,undefined);assert(calls.every(x=>!x.url.includes('/auth/')));assert(!('login'in c));await assert.rejects(()=>c.saveCloud({},1),/revision conflict/);c.disconnect();assert.equal(c.config(),null);
});
