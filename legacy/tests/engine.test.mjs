import test from 'node:test';
import assert from 'node:assert/strict';
import {scoreDice,rollDie,Game,aiChoice,scoringOptions} from '../web/engine.js';
import {DICE,BADGES,badgeById} from '../web/data.js';
const ordinary=Array(6).fill('ordinary');
const players=(badge='none')=>[{name:'A',dice:ordinary,badge},{name:'B',dice:ordinary,badge:'none'}];
function fixture(values,badge='none'){const g=new Game({goal:1500,players:players(badge)});g.pool=values.map((value,i)=>({id:'ordinary',uid:String(i),value}));g.evaluate();return g;}
const score=v=>scoreDice(v)?.points??null;
test('Singles, triples, quadruples and doubling through six dice',()=>{
 assert.equal(score([1]),100);assert.equal(score([5]),50);for(const f of [2,3,4,6])assert.equal(score([f]),null);
 for(let f=1;f<=6;f++)for(let n=3;n<=6;n++)assert.equal(score(Array(n).fill(f)),(f===1?1000:100*f)*2**(n-3));
 assert.equal(score([1,1,5,5]),300);assert.equal(score([1,1,1,5,5,5]),1500);
});
test('Straights use exactly the current throw and can combine with a single',()=>{
 assert.equal(score([1,2,3,4,5]),500);assert.equal(score([2,3,4,5,6]),750);assert.equal(score([1,2,3,4,5,6]),1500);
 assert.equal(score([1,1,2,3,4,5]),600);assert.equal(score([1,2,3,4,5,5]),550);
});
test('No three pairs, full house or leftover non-scoring dice',()=>{
 assert.equal(score([2,2,3,3,4,4]),null);assert.equal(score([2,2,2,4,4]),null);assert.equal(score([1,2]),null);assert.equal(score([]),null);
 assert.equal(score([2,2,2,5,5]),300);
});
test('Devil wildcard forms triples and straights but cannot score alone',()=>{
 assert.equal(score([0]),null);assert.equal(score([0,2]),null);assert.equal(score([0,2,2]),200);assert.equal(score([0,1,1]),1000);
 assert.equal(score([0,1,2,3,4,5]),1500);assert.equal(score([0,0,1]),1000);assert.equal(score([0,1,1,1]),2000);
});
test('Loaded dice respect zero weight faces and exact boundaries',()=>{
 assert.equal(rollDie('favourable',()=>0),1);assert.equal(rollDie('favourable',()=>.3334),3);assert.equal(rollDie('weighted',()=>.665),1);assert.equal(rollDie('weighted',()=>.667),2);assert.equal(rollDie('devil',()=>0),0);assert.equal(rollDie('balatro',()=>0),7);
 for(const d of DICE){assert.equal(d.weights.length,6);assert.ok(d.weights.some(w=>w>0));for(let i=0;i<100;i++){const f=rollDie(d.id,()=>i/100);assert.ok(f>=0&&f<=7);if(f>=1&&f<=6)assert.ok(d.weights[f-1]>0);}}
});
test('Keep, reroll and bust never lose previously banked points',()=>{
 const g=fixture([1,2,3,4,4,6]);g.player.score=200;g.keep([0]);assert.equal(g.turnPoints,100);assert.equal(g.pool.length,5);
 g.rng=()=>.55;g.roll();assert.equal(g.phase,'select'); // five 4s score
 g.pool=g.pool.slice(0,2);g.evaluate();assert.equal(g.phase,'bust');g.bust();assert.equal(g.players[0].score,200);assert.equal(g.turnPoints,0);assert.equal(g.active,1);
});
test('Kept ones across throws never merge into a triple',()=>{
 const g=fixture([1,1,2,3,4,6]);g.keep([0]);assert.equal(g.turnPoints,100);g.pool[0].value=1;g.phase='select';g.keep([0]);assert.equal(g.turnPoints,200);
});
test('Hot dice reset the full pool and preserve the accumulated turn',()=>{
 const g=fixture([1,2,3,4,5,6]);g.keep([0,1,2,3,4,5]);assert.equal(g.turnPoints,1500);g.rng=()=>0;g.roll();assert.equal(g.pool.length,6);assert.equal(g.held.length,0);assert.equal(g.turnPoints,1500);
});
test('Victory only occurs when banking and does not grant a final opposing turn',()=>{
 const g=fixture([1,1,1,1,2,3]);g.keep([0,1,2,3]);assert.equal(g.winner,null);g.bank();assert.equal(g.winner,0);assert.equal(g.phase,'over');assert.equal(g.active,0);
});
test('Invalid selections cannot advance the turn or score',()=>{
 const g=fixture([1,2,3,4,4,6]);assert.throws(()=>g.keep([0,1]));assert.throws(()=>g.keep([0,0]));assert.throws(()=>g.keep([12]));assert.equal(g.turnPoints,0);assert.equal(g.phase,'select');
});
test('Resurrection preserves turn points; limit is per game',()=>{
 const g=fixture([2,3,4,6], 'resurrection-1');g.turnPoints=450;g.rng=()=>0;g.useBadge();assert.equal(g.turnPoints,450);assert.equal(g.phase,'select');assert.equal(g.player.uses,1);assert.equal(g.canBadge,false);
});
test('Fortune and transmutation validate selected dice and do not modify kept dice',()=>{
 const g=fixture([1,2,3,4,6],'fortune-1');assert.throws(()=>g.useBadge([1,2]));assert.equal(g.player.uses,0);g.rng=()=>0;g.useBadge([1]);assert.equal(g.pool[1].value,1);assert.equal(g.pool[2].value,3);
 for(const [tier,value] of [[1,3],[2,5],[3,1]]){const h=fixture([2,3,4,6],`transmutation-${tier}`);h.useBadge([0]);assert.equal(h.pool[0].value,value);}
});
test('Double and warlord apply the right layer of score',()=>{
 const g=fixture([1,1,1,2,3,4],'double-3');g.turnPoints=100;g.useBadge([0,1,2]);assert.throws(()=>g.useBadge([0,1,2]));g.keep([0,1,2]);assert.equal(g.turnPoints,2100);
 const h=fixture([1,5,2,3,4,6],'warlord-1');h.useBadge();h.bank([0,1]);assert.equal(h.players[0].score,187);
});
test('Passive formations, emperor, Tyche and defence',()=>{
 assert.equal(scoreDice([3,5],badgeById('cut')).points,200);assert.equal(scoreDice([4,5,6],badgeById('gallows')).points,300);assert.equal(scoreDice([1,3,5],badgeById('eye')).points,300);
 assert.equal(scoreDice([1,1,1],badgeById('emperor')).points,3000);assert.equal(scoreDice([6,6,6],badgeById('tyche')).points,1200);
 const g=new Game({players:[{name:'A',dice:ordinary,badge:'headstart-3'},{name:'B',dice:ordinary,badge:'defence-3'}]});assert.equal(g.players[0].disabled,true);assert.equal(g.players[0].score,0);
});
test('Might adds an ordinary die and disappears on a new turn',()=>{const g=fixture([1,5,2,3,4,6],'might-2');g.useBadge();assert.equal(g.pool.length,7);assert.equal(g.extra,1);g.bank([0]);assert.equal(g.extra,0);g.roll();assert.equal(g.pool.length,6);});
test('Gold swap requires two matching dice',()=>{const g=fixture([1,2,3,4,4,6],'swap-3');assert.throws(()=>g.useBadge([1]));assert.throws(()=>g.useBadge([1,2]));g.useBadge([3,4]);assert.equal(g.player.uses,1);});
test('Choose joker result then resume scoring; jester badge can change it once',()=>{const g=fixture([7,2,2,3,4,6],'jester');g.pool[0].id='balatro';assert.equal(g.phase,'choose');g.choose(0,2);assert.equal(g.phase,'select');assert.equal(g.selection([0,1,2]).points,200);g.useBadge([0],1);assert.equal(g.pool[0].value,1);});
test('Save and restore retains dice, badge uses, active player and score',()=>{const g=fixture([1,5,2,3,4,6],'warlord-3');g.useBadge();g.keep([0]);const h=Game.restore(g.snapshot());assert.deepEqual(h.snapshot(),g.snapshot());h.bank();assert.equal(h.players[0].score,200);});
test('300 deterministic AI games terminate with legal scores and no stalls',()=>{
 let seed=12345;const rng=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/2**32);
 for(let run=0;run<300;run++){
  const badge=BADGES[1+run%(BADGES.length-1)].id;
  const p=players(badge);p[0].dice=['weighted','devil','favourable','ordinary','odd','lucky'];
  const g=new Game({goal:1500,players:p,rng});let actions=0;
  while(g.phase!=='over'&&actions++<1000){
   if(g.phase==='ready')g.roll();else if(g.phase==='bust'){if(g.badge.type==='resurrection'&&g.canBadge)g.useBadge();else g.bust();}
   else if(g.phase==='choose'){const index=g.pool.findIndex(d=>d.value===7);g.choose(index,1);}
   else{const c=aiChoice(g,1);assert.ok(c);const ix=g.pool.map((_,i)=>i).filter(i=>c.mask&(1<<i));if(c.bank)g.bank(ix);else g.keep(ix);}
  }
  assert.equal(g.phase,'over');assert.ok(g.players[g.winner].score>=1500);assert.ok(g.players.every(p=>p.score>=0));
 }
});
