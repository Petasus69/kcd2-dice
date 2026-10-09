import {dieById,badgeById} from './data.js';
export function randomUnit(){
 if(globalThis.crypto?.getRandomValues){const a=new Uint32Array(1);crypto.getRandomValues(a);return a[0]/4294967296;}
 return Math.random();
}
export function rollDie(id,rng=randomUnit){
 const d=dieById(id),total=d.weights.reduce((a,b)=>a+b,0);let v=rng()*total;
 for(let i=0;i<6;i++){v-=d.weights[i];if(v<0)return d.special==='wild'&&i===0?0:d.special==='choose'&&i===0?7:i+1;}
 return 6;
}
const bits=m=>{let n=0;while(m){n+=m&1;m>>>=1;}return n;};
// Find a complete partition. Every selected die must belong to a scoring group.
// A devil (0) is a joker in a formation, never a standalone scoring die.
export function scoreDice(values,badge=badgeById('none')){
 if(!values.length||values.includes(7))return null;
 const n=values.length,full=(1<<n)-1,groups=[];
 for(let mask=1;mask<=full;mask++){
  const vs=values.filter((_,i)=>mask&(1<<i)),size=vs.length,real=vs.filter(x=>x!==0),wild=size-real.length;
  if(size===1&&(vs[0]===1||vs[0]===5))groups.push({mask,points:vs[0]===1?100:50,label:vs[0]===1?'Единица':'Пятёрка'});
  if(size>=3){
   for(let f=1;f<=6;f++) if(real.every(x=>x===f)){
    let points=(f===1?1000:f*100)*2**(size-3);
    if(badge.type==='emperor'&&f===1)points*=3;
    if(badge.type==='tyche'&&f===6)points*=2;
    groups.push({mask,points,label:`${size} × ${f}`});
   }
  }
  const patterns=[{p:[1,2,3,4,5],v:500,l:'Ряд 1–5'},{p:[2,3,4,5,6],v:750,l:'Ряд 2–6'},{p:[1,2,3,4,5,6],v:1500,l:'Ряд 1–6'}];
  if(badge.formation)patterns.push({p:badge.formation,v:badge.points,l:{cut:'Рез',gallows:'Виселица',eye:'Око'}[badge.id]});
  for(const {p,v,l} of patterns)if(size===p.length&&new Set(real).size===real.length&&real.every(x=>p.includes(x))&&p.filter(x=>!real.includes(x)).length===wild)groups.push({mask,points:v,label:l});
 }
 const memo=new Map([[0,{points:0,parts:[]}]]);
 function solve(mask){
  if(memo.has(mask))return memo.get(mask);
  let best=null;const first=mask&-mask;
  for(const g of groups)if((g.mask&first)&&(g.mask&mask)===g.mask){const tail=solve(mask^g.mask);if(tail&&(!best||tail.points+g.points>best.points))best={points:tail.points+g.points,parts:[g.label,...tail.parts]};}
  memo.set(mask,best);return best;
 }
 return solve(full);
}
export function scoringOptions(dice,badge=badgeById('none')){
 const out=[];for(let mask=1;mask<(1<<dice.length);mask++){
  const score=scoreDice(dice.filter((_,i)=>mask&(1<<i)).map(d=>typeof d==='number'?d:d.value),badge);
  if(score)out.push({mask,count:bits(mask),...score});
 }return out.sort((a,b)=>b.points-a.points||a.count-b.count);
}
export class Game{
 constructor({goal=2000,players,rng=randomUnit,stake=0,mode='ai',opponent='miller',contract='beggar'}){
  this.goal=goal;this.stake=stake;this.mode=mode;this.opponent=opponent;this.contract=contract;this.rng=rng;
  this.players=players.map(p=>({...p,dice:[...p.dice],score:0,uses:0,disabled:false}));
  this.players.forEach((p,i)=>{const b=badgeById(p.badge),enemy=badgeById(this.players[1-i].badge);p.disabled=enemy.type==='defence'&&enemy.tier===b.tier;if(b.type==='headstart'&&!p.disabled)p.score=[0,100,200,400][b.tier];});
  this.active=0;this.turn=1;this.phase='ready';this.pool=[];this.held=[];this.turnPoints=0;this.multiplier=1;this.lastMultiplier=1;this.extra=0;this.winner=null;this.history=[];
 }
 get player(){return this.players[this.active];}
 get badge(){return this.player.disabled?badgeById('none'):badgeById(this.player.badge);}
 get canBadge(){return !this.player.disabled&&this.player.uses<this.badge.uses;}
 get total(){return Math.floor(this.turnPoints*this.multiplier);}
 freshPool(){return [...this.player.dice,...Array(this.extra).fill('ordinary')].map((id,i)=>({id,uid:`${this.turn}-${this.extra}-${i}`,value:null}));}
 roll(){
  if(this.phase!=='ready')throw Error('Сначала выберите очковые кости.');
  if(!this.pool.length){this.pool=this.freshPool();this.held=[];}
  this.pool.forEach(d=>d.value=rollDie(d.id,this.rng));this.lastMultiplier=1;return this.evaluate();
 }
 evaluate(){
  this.phase=this.pool.some(d=>d.value===7)?'choose':scoringOptions(this.pool,this.badge).length?'select':'bust';return this.phase;
 }
 choose(index,value){if(this.phase!=='choose'||this.pool[index]?.value!==7||value<1||value>6)throw Error('Выберите значение кости Шута.');this.pool[index].value=value;return this.evaluate();}
 selection(indices){if(new Set(indices).size!==indices.length||indices.some(i=>!this.pool[i]))return null;return scoreDice(indices.map(i=>this.pool[i].value),this.badge);}
 keep(indices){
  if(this.phase!=='select')throw Error('Сейчас нельзя откладывать кости.');const s=this.selection(indices);if(!s)throw Error('Выбранные кости не дают очков.');
  this.turnPoints+=s.points*this.lastMultiplier;this.held.push(...this.pool.filter((_,i)=>indices.includes(i)));this.pool=this.pool.filter((_,i)=>!indices.includes(i));this.phase='ready';this.lastMultiplier=1;return s;
 }
 bank(indices=[]){
  if(indices.length)this.keep(indices);
  if(this.phase!=='ready'||!this.turnPoints)throw Error('Зачтите очковые кости перед завершением хода.');
  const points=this.total;this.player.score+=points;this.log(`${this.player.name}: +${points}`);
  if(this.player.score>=this.goal){this.winner=this.active;this.phase='over';return 'over';}
  this.next();return points;
 }
 bust(){if(this.phase!=='bust')throw Error('Бросок не пустой.');this.log(`${this.player.name}: сгорело ${this.total}`);this.next();}
 next(){this.active=1-this.active;this.turn++;this.pool=[];this.held=[];this.turnPoints=0;this.multiplier=1;this.lastMultiplier=1;this.extra=0;this.phase='ready';}
 log(text){this.history.unshift(text);this.history=this.history.slice(0,30);}
 useBadge(indices=[],chosenValue=1){
  if(!this.canBadge)throw Error('Бляха недоступна.');const b=this.badge;
  if(['formation','emperor','tyche','headstart','defence','none'].includes(b.type))throw Error('Эта бляха действует автоматически.');
  if(b.type==='resurrection'){
   if(this.phase!=='bust')throw Error('Воскрешение доступно после пустого броска.');
   this.player.uses++;this.phase='ready';return this.roll();
  }
  if(!['select','bust'].includes(this.phase))throw Error('Примените бляху после броска.');
  if(new Set(indices).size!==indices.length||indices.some(i=>!this.pool[i]))throw Error('Некорректные кости.');
  switch(b.type){
   case 'fortune':case 'swap':{
    const max=b.type==='fortune'?b.tier:b.tier===2?1:2;
    if(!indices.length||indices.length>max)throw Error(`Выберите от 1 до ${max} костей.`);
    if(b.type==='swap'&&b.tier===3&&(indices.length!==2||this.pool[indices[0]].value!==this.pool[indices[1]].value))throw Error('Нужны две кости одного значения.');
    indices.forEach(i=>this.pool[i].value=rollDie(this.pool[i].id,this.rng));break;
   }
   case 'might':this.extra++;this.pool.push({id:'ordinary',uid:`extra-${this.turn}-${this.extra}`,value:rollDie('ordinary',this.rng)});break;
   case 'transmutation':if(indices.length!==1)throw Error('Выберите одну кость.');this.pool[indices[0]].value=[0,3,5,1][b.tier];break;
   case 'jester':if(indices.length!==1||dieById(this.pool[indices[0]].id).special!=='choose')throw Error('Выберите кость Шута.');if(chosenValue<1||chosenValue>6)throw Error('Некорректное значение.');this.pool[indices[0]].value=chosenValue;break;
   case 'double':if(this.lastMultiplier!==1)throw Error('Этот бросок уже удвоен.');if(!this.selection(indices))throw Error('Выберите очковую комбинацию.');this.lastMultiplier=2;break;
   case 'warlord':if(this.multiplier!==1)throw Error('Ход уже усилен.');this.multiplier=[1,1.25,1.5,2][b.tier];break;
   default:throw Error('Бляха не поддерживается.');
  }
  this.player.uses++;this.log(`${this.player.name}: бляха «${b.name}»`);return this.evaluate();
 }
 snapshot(){const {rng,...s}=this;return JSON.parse(JSON.stringify(s));}
 static restore(s,rng=randomUnit){
  if(!s||s.players?.length!==2||!['ready','choose','select','bust','over'].includes(s.phase))throw Error('Повреждённое сохранение.');
  const g=Object.create(Game.prototype);Object.assign(g,s,{rng});return g;
 }
}
export function aiChoice(game,risk=1){
 const opts=scoringOptions(game.pool,game.badge);if(!opts.length)return null;
 let best=null;for(const o of opts){const left=game.pool.length-o.count||6;const utility=o.points+left*45*risk;if(!best||utility>best.utility)best={...o,utility};}
 const after=Math.floor((game.turnPoints+best.points*game.lastMultiplier)*game.multiplier);
 const left=game.pool.length-best.count;
 const behind=game.players[1-game.active].score-game.player.score;
 const threshold=(left===0?1400:left>=4?850:left===3?500:left===2?300:150)*risk+(behind>800?250:0);
 return {...best,bank:game.player.score+after>=game.goal||after>=threshold};
}
