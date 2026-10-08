// Generate oracle data from the unchanged production JS engine, not a second
// handwritten copy of its scoring rules. Run before the native parity test.
import {writeFileSync} from 'node:fs';
import {scoreDice, Game, aiChoice} from '../../web/engine.js';
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
const dieId = d => Number(d.uid.split('-').at(-1));
function state(g) {
  return {scores:g.players.map(p=>p.score), active:g.active, turn:g.turn,
    phase:g.phase, pool:g.pool.map(d=>({die:dieId(d), value:d.value})),
    held:g.held.map(dieId), turn_points:g.turnPoints, winner:g.winner??-1};
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
writeFileSync(output,JSON.stringify({scores,scenarios}));
console.log(`Generated ${scores.length} scoring cases and ${scenarios.length} match scenarios from web/engine.js`);
