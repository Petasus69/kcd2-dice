import test from 'node:test';
import assert from 'node:assert/strict';
import {REST_HEIGHT,restingLayout,simulateThrow,sampleThrow} from '../web/table-motion.js';

test('Visual throw has airborne frames, table contacts and a stable final pose',()=>{
 const initial=restingLayout(6),simulation=simulateThrow(initial,[0,1,2,3,4,5],{seed:43});
 assert.ok(simulation.frames[0].every(p=>p.y>2));
 assert.ok(new Set(simulation.hits.map(hit=>hit.index)).size===6);
 assert.ok(simulation.hits.every(hit=>hit.strength>0&&hit.strength<=1));
 for(const p of simulation.final){assert.equal(p.y,REST_HEIGHT);assert.ok(Math.abs(p.x)<=3.5-.57);assert.ok(Math.abs(p.z)<=3.5-.57);}
 assert.deepEqual(sampleThrow(simulation,1),simulation.final);
 assert.deepEqual(simulateThrow(initial,[0,1,2,3,4,5],{seed:43}).final,simulation.final);
});
test('A badge reroll leaves unselected dice stationary and does not mutate engine data',()=>{
 const initial=restingLayout(6),snapshot=structuredClone(initial),simulation=simulateThrow(initial,[1,4],{seed:31});
 assert.deepEqual(initial,snapshot);
 for(const index of [0,2,3,5])for(const frame of simulation.frames){assert.equal(frame[index].x,initial[index].x);assert.equal(frame[index].z,initial[index].z);}
 assert.deepEqual([...new Set(simulation.hits.map(h=>h.index))].sort(),[1,4]);
});
test('Bodies avoid overlapping at rest across several throws including a seventh die',()=>{
 for(const count of [1,3,6,7])for(let seed=1;seed<=12;seed++){
  const simulation=simulateThrow(restingLayout(count),Array.from({length:count},(_,i)=>i),{seed});
  for(let i=0;i<count;i++)for(let j=i+1;j<count;j++)assert.ok(Math.hypot(simulation.final[i].x-simulation.final[j].x,simulation.final[i].z-simulation.final[j].z)>1.05,`overlap: count=${count} seed=${seed}`);
 }
});
