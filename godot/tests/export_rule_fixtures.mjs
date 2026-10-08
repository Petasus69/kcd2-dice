// Generate oracle data from the unchanged production JS engine, not a second
// handwritten copy of its scoring rules. Run before the native parity test.
import {writeFileSync} from 'node:fs';
import {scoreDice, Game, aiChoice} from '../../web/engine.js';
import {BADGES, badgeById} from '../../web/data.js';
const output = process.argv[2];
if (!output) throw new Error('Pass an output JSON path');
const scores = [];
function visit(values, first) {
  scores.push({values, points: scoreDice(values)?.points ?? null});
  if (values.length === 6) return;
  for (let face = first; face <= 7; face++) visit([...values, face], face);
}
visit([], 0);
const players = () => ['Игрок 1','Игрок 2'].map(name => ({name, dice:Array(6).fill('ordinary'), badge:'none'}));
const dieId = d => d.uid.startsWith('extra-')?5+Number(d.uid.split('-').at(-1)):Number(d.uid.split('-').at(-1));
function state(g) {
  return {scores:g.players.map(p=>p.score), active:g.active, turn:g.turn,
    phase:g.phase, pool:g.pool.map(d=>({die:dieId(d), value:d.value})),
    held:g.held.map(dieId), turn_points:g.turnPoints, winner:g.winner??-1,
    uses:g.players.map(p=>p.uses),disabled:g.players.map(p=>p.disabled),multiplier:g.multiplier,last_multiplier:g.lastMultiplier,extra:g.extra,
    choices: g.phase==='select'?[.7,1,1.1,1.25].map(risk=>({risk,...aiChoice(g,risk)})):[]};
}
function apply(g, action) {
  const positions = () => action.indices.map(id=>g.pool.findIndex(d=>dieId(d)===id));
  switch(action.type) {
    case 'roll': {
      let index=0; g.rng=()=>(action.values[index++]-0.5)/6; g.roll();
      if(index!==action.values.length) throw new Error('Fixture roll length mismatch'); break;
    }
    case 'keep':g.keep(positions());break;
    case 'bank':g.bank(positions());break;
    case 'bust':g.bust();break;
    case 'badge': {
      let index=0;g.rng=()=>(action.values[index++]-0.5)/6;
      g.useBadge(positions());
      if(index!==action.values.length)throw new Error('Badge fixture roll mismatch');
      break;
    }
    default:throw new Error('Unknown action');
  }
  return {...action, expected:state(g)};
}
const scenarios=[];
function scenario(name, actions, goal=1500) {
  const g=new Game({goal,players:players(),mode:'local'});
  scenarios.push({name,goal,steps:actions.map(a=>apply(g,a))});
}
scenario('kept singles do not merge, hot dice, victory on banking',[
  {type:'roll',values:[1,1,1,2,3,4]}, {type:'keep',indices:[0]},
  {type:'roll',values:[1,2,3,4,6]}, {type:'keep',indices:[1]}, {type:'bank',indices:[]},
  {type:'roll',values:[2,3,4,6,2,3]}, {type:'bust'},
  {type:'roll',values:[1,2,3,4,5,6]}, {type:'keep',indices:[0,1,2,3,4,5]},
  {type:'roll',values:[1,1,1,1,1,1]}, {type:'bank',indices:[0,1,2,3,4,5]},
]);
scenario('banked points survive a later bust',[
  {type:'roll',values:[1,1,2,3,4,6]}, {type:'bank',indices:[0,1]},
  {type:'roll',values:[2,3,4,6,2,3]}, {type:'bust'},
  {type:'roll',values:[1,2,3,4,4,6]}, {type:'keep',indices:[0]},
  {type:'roll',values:[2,3,4,6,2]}, {type:'bust'},
]);
let seed=493028;
const rand=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/2**32);
for(let run=0;run<30;run++) {
  const g=new Game({goal:1500,players:players(),mode:'local'}), steps=[];
  for(let count=0;g.phase!=='over' && count<1000;count++) {
    let action;
    if(g.phase==='ready') action={type:'roll',values:Array.from({length:g.pool.length||6},()=>1+Math.floor(rand()*6))};
    else if(g.phase==='bust') action={type:'bust'};
    else {
      const choice=aiChoice(g,1);
      action={type:choice.bank?'bank':'keep',indices:g.pool.filter((_,i)=>choice.mask&(1<<i)).map(dieId)};
    }
    steps.push(apply(g,action));
  }
  if(g.phase!=='over') throw new Error('Oracle game stalled');
  scenarios.push({name:`complete ordinary match ${run+1}`,goal:1500,steps});
}
const badgeScores=[];
for(const b of BADGES.filter(b=>b.type!=='jester')) {
  for(const item of scores.filter(s=>s.values.every(v=>v>=1&&v<=6)))
    badgeScores.push({...item,badge:b.id,points:scoreDice(item.values,b)?.points??null});
  const playersWithBadges=players();playersWithBadges[0].badge=b.id;
  if(b.type==='defence')playersWithBadges[1].badge=`headstart-${b.tier}`;
  const g=new Game({goal:5000,players:playersWithBadges,mode:'local'}),steps=[];
  steps.push(apply(g,{type:'roll',values:b.type==='resurrection'?[2,3,4,6,2,3]:[1,1,2,3,4,6]}));
  if(!['formation','emperor','tyche','headstart','defence','none'].includes(b.type)) {
    const indices=['fortune','transmutation','double'].includes(b.type)?[0]:b.type==='swap'?(b.tier===3?[0,1]:[0]):[];
    const values=b.type==='resurrection'?[1,5,2,3,4,6]:['fortune','swap','might'].includes(b.type)?Array(b.type==='swap'&&b.tier===3?2:1).fill(5):[];
    steps.push(apply(g,{type:'badge',indices,values}));
  }
  if(g.phase==='select') {
    const choice=aiChoice(g,1);
    steps.push(apply(g,{type:'bank',indices:g.pool.filter((_,i)=>choice.mask&(1<<i)).map(dieId)}));
  }
  scenarios.push({name:`badge ${b.id}`,goal:5000,badges:playersWithBadges.map(p=>p.badge),steps});
}
writeFileSync(output,JSON.stringify({scores,badgeScores,scenarios}));
console.log(`Generated ${scores.length} scoring cases and ${scenarios.length} match scenarios from web/engine.js`);
