import {DICE,BADGES,CONTRACTS,OPPONENTS,TIER_NAMES,dieById,badgeById} from './data.js';
import {Game,aiChoice,scoringOptions} from './engine.js';
import {DiceRenderer,diePortrait} from './renderer.js';
const $=id=>document.getElementById(id);
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fmt=n=>Math.floor(n).toLocaleString('ru-RU');
const STORE='trakt-dice-v1';
const defaults=()=>({gold:500,wins:0,games:0,sound:true,haptic:true,fast:false,loadouts:[Array(6).fill('ordinary'),Array(6).fill('ordinary')],badges:['none','none'],owned:Object.fromEntries(BADGES.map(b=>[b.id,1])),saved:null});
let profile;try{profile={...defaults(),...JSON.parse(localStorage.getItem(STORE)||'null')};}catch{profile=defaults();}
let game=null,selected=new Set(),busy=false,screen='home',audio=null,aiTimer=null,modalClosable=true,modalCallback=null,setupMode='ai',setupTraining=false,inventoryOwner=0,inventorySlot=0,inventoryTab='dice',settled=false;
function save(){try{localStorage.setItem(STORE,JSON.stringify(profile));}catch{toast('Не удалось сохранить прогресс: память браузера недоступна.');}}
function checkpoint(){if(game)profile.saved={state:game.snapshot(),settled};save();}
function toast(text){$('toast').textContent=text;$('toast').hidden=false;clearTimeout(toast.timer);toast.timer=setTimeout(()=>$('toast').hidden=true,3200);}
function sound(kind){
 if(!profile.sound)return;
 try{audio??=new (window.AudioContext||window.webkitAudioContext)();audio.resume();const t=audio.currentTime;
  if(kind==='roll'){for(let i=0;i<8;i++){const o=audio.createOscillator(),g=audio.createGain();o.type='triangle';o.frequency.setValueAtTime(120+Math.random()*280,t+i*.055);g.gain.setValueAtTime(.035,t+i*.055);g.gain.exponentialRampToValueAtTime(.001,t+i*.055+.07);o.connect(g);g.connect(audio.destination);o.start(t+i*.055);o.stop(t+i*.055+.08);}}
  else{const notes=kind==='win'?[392,494,587,784]:kind==='bust'?[180,130]:kind==='bank'?[440,660]:[340];notes.forEach((f,i)=>{const o=audio.createOscillator(),g=audio.createGain();o.type='triangle';o.frequency.value=f;g.gain.setValueAtTime(.035,t+i*.11);g.gain.exponentialRampToValueAtTime(.001,t+i*.11+.22);o.connect(g);g.connect(audio.destination);o.start(t+i*.11);o.stop(t+i*.11+.23);});}
 }catch{}
}
function vibrate(kind='tap'){if(!profile.haptic)return;try{if(window.Android?.haptic)window.Android.haptic(kind);else navigator.vibrate?.(kind==='bust'?[40,30,40]:kind==='win'?[30,40,60]:15);}catch{}}
const renderer=new DiceRenderer($('dice-canvas'),i=>{
 if(busy||!game||isAI()||!['select','bust'].includes(game.phase))return;
 selected.has(i)?selected.delete(i):selected.add(i);sound('tap');vibrate();update();
});
const homeRenderer=new DiceRenderer($('home-dice'));
homeRenderer.set([{id:'ordinary',value:5},{id:'weighted',value:1},{id:'lucky',value:3}]);
function isAI(){return game?.mode==='ai'&&game.active===1;}
function showHome(){screen='home';document.body.dataset.screen='home';$('home').hidden=false;$('play').hidden=true;$('continue').hidden=!profile.saved||profile.saved.state.phase==='over';$('purse').textContent=`◉ ${fmt(profile.gold)} грошей`;$('stats').textContent=`${profile.wins} побед · ${profile.games} партий`;homeRenderer.resize();}
function showGame(){screen='game';document.body.dataset.screen='game';$('home').hidden=true;$('play').hidden=false;renderer.resize();update();}
function openModal(title,html,{closable=true,kicker='У ТРАКТА',onClose=null}={}){
 $('modal-title').textContent=title;$('modal-kicker').textContent=kicker;$('modal-body').innerHTML=html;$('modal').hidden=false;$('close-modal').hidden=!closable;modalClosable=closable;modalCallback=onClose;
 setTimeout(()=>$('modal-body').querySelector('button,select,input')?.focus({preventScroll:true}),30);
}
function closeModal(force=false){if(!modalClosable&&!force)return;$('modal').hidden=true;const cb=modalCallback;modalCallback=null;cb?.();if(screen==='game'&&isAI()&&!busy)scheduleAI();}
$('close-modal').onclick=()=>closeModal();document.querySelector('.modal-shade').onclick=()=>closeModal();
document.addEventListener('keydown',e=>{if(e.key==='Escape'){if(!$('modal').hidden)closeModal();else if(screen==='game')pauseMenu();}if(e.key===' '&&screen==='game'&&$('modal').hidden){e.preventDefault();$('roll').click();}});
window.addEventListener('pagehide',checkpoint);document.addEventListener('visibilitychange',()=>{if(document.hidden){checkpoint();audio?.suspend();}else if(screen==='game'&&isAI())scheduleAI();});
window.onNativeBack=()=>{if(!$('modal').hidden){closeModal();return;}if(screen==='game'){pauseMenu();return;}settings();};
function setup(){
 const choice=setup.contract||CONTRACTS[0].id;
 openModal('Новая партия',`<div class="segmented"><button id="mode-ai" class="${setupMode==='ai'?'active':''}">С соперником</button><button id="mode-local" class="${setupMode==='local'?'active':''}">Вдвоём</button></div><div class="form-row"><label><span>Партия</span><select id="contract">${CONTRACTS.map(c=>`<option value="${c.id}" ${choice===c.id?'selected':''}>${c.name}</option>`).join('')}</select></label><label><span>${setupMode==='ai'?'Соперник':'Второй игрок'}</span>${setupMode==='ai'?`<select id="opponent">${OPPONENTS.map(o=>`<option value="${o.id}" ${setup.opponent===o.id?'selected':''}>${o.name}</option>`).join('')}</select>`:'<input id="second-name" type="text" maxlength="22" value="Игрок 2" aria-label="Имя второго игрока">'}</label></div><label><span>Ваша бляха</span><select id="match-badge"></select></label><div class="contract-preview" id="contract-preview"></div><label class="selection-help" style="display:block"><input id="training" type="checkbox" ${setupTraining?'checked':''}> Свободная игра · без ставок и потери блях</label><p class="muted">Набор из шести костей выбирается в разделе «Мои кости». ${setupMode==='local'?'Для второго игрока можно собрать отдельный набор.':'Все виды костей доступны сразу.'}</p><button class="button gold" id="start-match">Начать партию</button>`,{kicker:'ВЫБЕРИТЕ СВОЙ СТОЛ'});
 $('mode-ai').onclick=()=>{setupMode='ai';rememberSetup();setup();};$('mode-local').onclick=()=>{setupMode='local';rememberSetup();setup();};
 function preview(){const c=CONTRACTS.find(c=>$('contract').value===c.id);setup.contract=c.id;const eligible=BADGES.filter(b=>b.tier===c.tier&&b.id!=='none'&&(setupTraining||profile.owned[b.id]>0));$('match-badge').innerHTML=c.tier===0?'<option value="none">Без бляхи</option>':eligible.map(b=>`<option value="${b.id}" ${profile.badges[0]===b.id?'selected':''}>${b.name}</option>`).join('');$('match-badge').disabled=c.tier===0;$('contract-preview').innerHTML=`Первым набрать <b>${fmt(c.goal)}</b> очков<br>${setupTraining?'Без ставки':`Ставка: <b>${c.stake}</b> грошей · В кошеле: <b>${fmt(profile.gold)}</b>`}<br><span class="muted">${TIER_NAMES[c.tier]}${setupMode==='local'?' · Один телефон, два игрока':''}</span>`;$('start-match').disabled=!setupTraining&&setupMode==='ai'&&profile.gold<c.stake||c.tier>0&&!eligible.length;}
 $('contract').onchange=preview;$('training').onchange=()=>{setupTraining=$('training').checked;preview();};preview();
 $('start-match').onclick=()=>{
  const c=CONTRACTS.find(c=>c.id===$('contract').value),o=OPPONENTS.find(o=>o.id===$('opponent')?.value)||OPPONENTS[0];
  const pBadge=$('match-badge').value||'none';const other=setupMode==='local'?(badgeById(profile.badges[1]).tier===c.tier?profile.badges[1]:c.tier?`fortune-${c.tier}`:'none'):c.tier?`${o.badge}-${c.tier}`:'none';
  if(!setupTraining&&setupMode==='ai'&&profile.gold<c.stake){toast('В кошеле не хватает грошей.');return;}
  game=new Game({goal:c.goal,stake:setupTraining||setupMode==='local'?0:c.stake,mode:setupMode,opponent:o.id,contract:c.id,players:[{name:setupMode==='local'?'Игрок 1':'Вы',dice:profile.loadouts[0],badge:pBadge},{name:setupMode==='local'?($('second-name').value.trim()||'Игрок 2'):o.name,dice:setupMode==='local'?profile.loadouts[1]:o.dice,badge:other}]});
  if(game.stake)profile.gold-=game.stake;selected.clear();settled=false;busy=false;clearTimeout(aiTimer);closeModal(true);checkpoint();showGame();
 };
}
function rememberSetup(){if($('contract'))setup.contract=$('contract').value;if($('opponent'))setup.opponent=$('opponent').value;}
$('new-game').onclick=()=>{setup();};$('continue').onclick=()=>{try{game=Game.restore(profile.saved.state);settled=profile.saved.settled;busy=false;selected.clear();showGame();resolveChoice();if(isAI())scheduleAI();}catch{profile.saved=null;save();showHome();toast('Сохранение не удалось открыть. Можно начать новую партию.');}};
function inventory(){
 openModal('Кости и бляхи',`<div class="segmented"><button id="owner-0" class="${inventoryOwner===0?'active':''}">Ваш набор</button><button id="owner-1" class="${inventoryOwner===1?'active':''}">Набор игрока 2</button></div><div class="tabs"><button id="tab-dice" class="${inventoryTab==='dice'?'active':''}">Кости · ${DICE.length}</button><button id="tab-badges" class="${inventoryTab==='badges'?'active':''}">Бляхи · ${BADGES.length-1}</button></div><div id="inventory-content"></div>`,{kicker:'СОБЕРИТЕ СВОЮ УДАЧУ'});
 $('owner-0').onclick=()=>{inventoryOwner=0;inventory();};$('owner-1').onclick=()=>{inventoryOwner=1;inventory();};$('tab-dice').onclick=()=>{inventoryTab='dice';inventory();};$('tab-badges').onclick=()=>{inventoryTab='badges';inventory();};
 if(inventoryTab==='dice'){
  $('inventory-content').innerHTML=`<p class="muted">Выберите место в наборе, затем кость. Можно брать несколько одинаковых.</p><div class="equipment-slots">${profile.loadouts[inventoryOwner].map((id,i)=>`<button class="slot ${i===inventorySlot?'active':''}" data-slot="${i}" title="${esc(dieById(id).name)}">⚄<small>${i+1}</small></button>`).join('')}</div><p class="selection-help">Место ${inventorySlot+1}: <b>${esc(dieById(profile.loadouts[inventoryOwner][inventorySlot]).name)}</b></p><div class="catalog">${DICE.map(d=>{const sum=d.weights.reduce((a,b)=>a+b);return `<button class="item-card ${profile.loadouts[inventoryOwner][inventorySlot]===d.id?'active':''}" data-die="${d.id}"><span class="item-icon ${d.material}">${d.special==='wild'?'♆':d.special==='choose'?'♧':'⚄'}</span><span class="item-copy"><strong>${d.name}</strong><span class="odds">${d.weights.map((w,i)=>`<span><b>${i+1}</b> ${(100*w/sum).toFixed(1)}%</span>`).join('')}</span>${d.special?`<small>${d.special==='wild'?'Вместо 1 — джокер для комбинаций.':'При выпадении шута выберите число.'}</small>`:''}</span></button>`;}).join('')}</div>`;
  document.querySelectorAll('[data-slot]').forEach(b=>{const id=profile.loadouts[inventoryOwner][+b.dataset.slot];b.innerHTML=`<img src="${diePortrait(id)}" alt=""><small>${+b.dataset.slot+1}</small>`;b.setAttribute('aria-label',`Место ${+b.dataset.slot+1}: ${dieById(id).name}`);b.onclick=()=>{inventorySlot=+b.dataset.slot;inventory();};});document.querySelectorAll('[data-die]').forEach(b=>{b.querySelector('.item-icon').innerHTML=`<img src="${diePortrait(b.dataset.die)}" alt="">`;b.onclick=()=>{profile.loadouts[inventoryOwner][inventorySlot]=b.dataset.die;save();inventory();};});
 }else{
  $('inventory-content').innerHTML=`<p class="muted">Ранги: олово, серебро, золото. В партии обе бляхи должны быть одного ранга. Некоторые численные эффекты пока требуют сверки с оригиналом.</p><div class="catalog">${BADGES.map(b=>`<button class="item-card ${profile.badges[inventoryOwner]===b.id?'active':''}" data-badge="${b.id}"><span class="item-icon badge">${b.icon}</span><span class="item-copy"><strong>${b.name}</strong><small>${TIER_NAMES[b.tier]} · ${b.id==='none'?'':`В коллекции: ${profile.owned[b.id]||0} · `}${b.desc}</small></span></button>`).join('')}</div>`;
  document.querySelectorAll('[data-badge]').forEach(b=>b.onclick=()=>{profile.badges[inventoryOwner]=b.dataset.badge;save();inventory();});
 }
}
$('equipment').onclick=inventory;
const rows=[['Одна единица',100],['Одна пятёрка',50],['1 · 1 · 1',1000],['2 · 2 · 2',200],['3 · 3 · 3',300],['4 · 4 · 4',400],['5 · 5 · 5',500],['6 · 6 · 6',600],['1 · 2 · 3 · 4 · 5',500],['2 · 3 · 4 · 5 · 6',750],['1 · 2 · 3 · 4 · 5 · 6',1500]];
function rules(){openModal('Правила игры',`<div class="rule-step"><b>1</b><p>Бросьте шесть костей. Выберите одну или несколько костей, которые дают очки.</p></div><div class="rule-step"><b>2</b><p>Заберите очки и передайте ход. Или зачтите выбранные кости и бросьте остальные.</p></div><div class="rule-step"><b>3</b><p>Пустой бросок сжигает все очки этого хода. Ранее забранные очки сохраняются.</p></div><div class="rule-step"><b>4</b><p>Зачли все кости? Можно снова бросить весь набор. Первый, кто заберёт очки до цели партии, побеждает.</p></div><h3>Цена удачи</h3><table class="rules-table">${rows.map(([v,p])=>`<tr><td>${v}</td><td>${fmt(p)}</td></tr>`).join('')}</table><p>Каждая одинаковая кость сверх тройки удваивает её цену: четыре четвёрки — 800, пять — 1600, шесть — 3200.</p><p>Тройку можно собрать только в одном броске. Три пары, два триплета и полный дом не имеют отдельного бонуса. Разрешено одновременно зачесть несколько очковых комбинаций.</p><h3>Особые кости и бляхи</h3><p>Вероятности особых костей показаны в коллекции. Голова дьявола заменяет недостающее число в комбинации; сама по себе очков не даёт. Для кости Шута выберите число, когда выпадет символ.</p><p>Бляха может менять бросок или очки. Для переброса и превращения сначала коснитесь нужных костей, затем бляхи. Для воскрешения используйте бляху до передачи пустого хода.</p><p class="muted">Числа для форы и особых формаций блях — предварительные. Это самостоятельная реализация, а не оригинальная игра Warhorse.</p>`,{kicker:'СЛУШАЙ, ЧТО ГОВОРИТ ТРАКТИРЩИК'});}
$('rules-home').onclick=rules; $('rules-game').onclick=rules;
function settings(){
 openModal('Настройки',`<label class="selection-help" style="display:block">Версия 0.1.0 · Игра работает без интернета</label>${[['sound','Звуки костей'],['haptic','Вибрация'],['fast','Быстрые броски']].map(([id,name])=>`<label class="form-row"><span>${name}</span><input type="checkbox" id="setting-${id}" ${profile[id]?'checked':''}></label>`).join('')}<h3>Ваш путь</h3><p>${profile.games} партий · ${profile.wins} побед · ${fmt(profile.gold)} грошей.</p><button class="button" id="refill">Пополнить кошель до 500</button><p class="muted">Гроши игровые. Покупок и рекламы нет.</p>`,{kicker:'КАК ВАМ УДОБНО'});
 for(const id of ['sound','haptic','fast'])$(`setting-${id}`).onchange=e=>{profile[id]=e.target.checked;save();};
 $('refill').onclick=()=>{profile.gold=Math.max(500,profile.gold);save();toast('В кошеле не меньше 500 грошей.');};
}
$('settings-home').onclick=settings;
function update(){
 if(!game)return;const p=game.player,b=game.badge,s=selected.size?game.selection([...selected]):null,ai=isAI();
 $('goal').textContent=fmt(game.goal);$('turn-label').textContent=`ХОД ${game.turn} · ${p.name.toUpperCase()}`;
 $('stake-label').textContent=game.stake?`Ставка ${game.stake} гр.`:'Свободная игра';

 // Contract title stays independent of the setup dialog.
 
 document.querySelector('#play .game-top .smallcaps').textContent=CONTRACTS.find(c=>c.id===game.contract)?.name.toUpperCase()||'ИГРА В КОСТИ';
 game.players.forEach((p,i)=>{const el=$(`score-${i}`);el.classList.toggle('active',game.active===i);el.querySelector('.player-name').textContent=p.name;el.querySelector('.score-number').textContent=fmt(p.score);el.querySelector('.score-track i').style.width=`${Math.min(100,100*p.score/game.goal)}%`;el.querySelector('.player-badge').textContent=p.disabled?'Бляха подавлена':badgeById(p.badge).tier?`${TIER_NAMES[badgeById(p.badge).tier]} · ${badgeById(p.badge).name.replace(/^(Оловянная|Серебряная|Золотая) · /,'')}`:'Без бляхи';});
 const titles={ready:game.turnPoints?'Продолжить или забрать?':'Ваша очередь',select:'Выберите очковые кости',choose:'Улыбка шута',bust:'Пустой бросок',over:'Партия окончена'};
 $('status').textContent=busy?'Кости брошены…':ai?`${p.name} играет`:titles[game.phase];
 $('instruction').textContent=busy?'Да улыбнётся вам удача.':ai?'Соперник выбирает кости и решает, рисковать ли.':game.phase==='bust'?`Сгорает ${fmt(game.total)} очков хода.${b.type==='resurrection'&&game.canBadge?' Можно спастись бляхой.':''}`:game.phase==='ready'?(game.turnPoints?'Очки хода ещё можно потерять.':'Бросьте кости, чтобы начать ход.'):game.phase==='choose'?'Выберите значение выпавшей кости Шута.':'Коснитесь костей на столе. Затем заберите очки или бросьте остальные.';
 $('turn-points').textContent=fmt(game.total);$('selection-points').textContent=s?`+${fmt(s.points*game.lastMultiplier*game.multiplier)}`:selected.size?'×':'—';
 $('combo-line').textContent=selected.size?(s?`${s.parts.join(' · ')}${game.lastMultiplier>1?' · ×2':''}`:'Не все выбранные кости дают очки'):game.multiplier>1?`Бляха воеводы: ×${game.multiplier}`:game.phase==='ready'&&!game.pool.length&&game.turnPoints?'Все кости зачтены — снова бросьте весь набор':'';
 $('roll').textContent=game.phase==='bust'?'Передать ход':game.phase==='select'?`Зачесть и бросить`:'Бросить кости';
 $('roll').disabled=busy||ai||game.phase==='over'||game.phase==='choose'||game.phase==='select'&&!s;
 $('bank').disabled=busy||ai||!(game.phase==='ready'&&game.turnPoints||game.phase==='select'&&s);
 $('hint').disabled=busy||ai||game.phase!=='select';
 const automatic=['none','headstart','defence','formation','emperor','tyche'].includes(b.type);
 $('use-badge').disabled=busy||ai||!game.canBadge||automatic||!['select','bust'].includes(game.phase);$('use-badge').title=`${b.name}: ${b.desc}`;$('badge-symbol').textContent=b.icon||'—';$('badge-remaining').textContent=automatic?(b.tier?'∞':'—'):Math.max(0,b.uses-p.uses);
 $('held-label').textContent=game.held.length?`ЗАЧТЕНО КОСТЕЙ: ${game.held.length}`:'';
 renderer.set(game.pool,game.held,selected);
 $('dice-accessibility').innerHTML=game.pool.map((d,i)=>`<button data-access-die="${i}" aria-pressed="${selected.has(i)}">Кость ${i+1}: ${d.value===0?'дьявол':d.value}, ${dieById(d.id).name}</button>`).join('');
 $('dice-accessibility').querySelectorAll('button').forEach(el=>el.onclick=()=>{if(busy||ai||game.phase!=='select')return;const i=+el.dataset.accessDie;selected.has(i)?selected.delete(i):selected.add(i);update();});
}
function indices(mask){return game.pool.map((_,i)=>i).filter(i=>mask&(1<<i));}
async function animateRoll(which){busy=true;update();sound('roll');await renderer.animate(which,profile.fast||matchMedia('(prefers-reduced-motion: reduce)').matches?250:850);busy=false;selected.clear();checkpoint();update();resolveChoice();}
async function humanRoll(){
 if(busy||isAI())return;
 try{if(game.phase==='bust'){const lost=game.total;game.bust();selected.clear();sound('bust');vibrate('bust');toast(`Очки хода сгорели: ${fmt(lost)}`);afterTurn();return;}
  if(game.phase==='select')game.keep([...selected]);selected.clear();game.roll();await animateRoll(game.pool.map((_,i)=>i));
 }catch(e){busy=false;toast(e.message);update();}
}
function humanBank(){if(busy||isAI())return;try{game.bank(game.phase==='select'?[...selected]:[]);selected.clear();sound('bank');vibrate();afterTurn();}catch(e){toast(e.message);}}
$('roll').onclick=humanRoll;$('bank').onclick=humanBank;
$('hint').onclick=()=>{const opts=scoringOptions(game.pool,game.badge);if(opts.length){selected=new Set(indices(opts[0].mask));update();toast('Выбрана самая дорогая комбинация этого броска.');}};
function resolveChoice(){
 if(game?.phase!=='choose')return;
 const i=game.pool.findIndex(d=>d.value===7);
 if(isAI()){let best={score:-1,value:1};for(let v=1;v<=6;v++){const ds=game.pool.map((d,j)=>({...d,value:j===i?v:d.value===7?1:d.value}));const p=scoringOptions(ds,game.badge)[0]?.points||0;if(p>best.score)best={score:p,value:v};}game.choose(i,best.value);resolveChoice();return;}
 openModal('Какое число выбрать?',`<p>Кость Шута может стать любым числом. Выберите значение для кости ${i+1}.</p><div class="equipment-slots">${[1,2,3,4,5,6].map(v=>`<button class="slot" data-value="${v}">${v}</button>`).join('')}</div>`,{closable:false,kicker:'КОСТЬ ШУТА'});
 document.querySelectorAll('[data-value]').forEach(b=>b.onclick=()=>{game.choose(i,+b.dataset.value);closeModal(true);checkpoint();update();resolveChoice();});
}
$('use-badge').onclick=()=>{
 if(busy||isAI())return;
 const b=game.badge;
 openModal(b.name,`<p>${b.desc}</p><p class="muted">${selected.size?`Выбрано костей: ${selected.size}`:'Для переброса или превращения выберите кости на столе до применения бляхи.'}</p>${b.type==='jester'?'<label><span>Новое значение</span><select id="badge-value">'+[1,2,3,4,5,6].map(v=>`<option>${v}</option>`).join('')+'</select></label>':''}<button id="confirm-badge" class="button gold">Применить бляху</button>`,{kicker:`ОСТАЛОСЬ ПРИМЕНЕНИЙ: ${b.uses-game.player.uses}`});
 $('confirm-badge').onclick=async()=>{try{const chosen=+($('badge-value')?.value||1);game.useBadge([...selected],chosen);closeModal(true);vibrate();if(['fortune','swap','might','resurrection'].includes(b.type))await animateRoll(game.pool.map((_,i)=>i));else{checkpoint();update();}}catch(e){toast(e.message);}};
};
function afterTurn(){checkpoint();update();if(game.phase==='over'){result();return;}if(isAI())scheduleAI();else if(game.mode==='local')openModal('Передайте телефон',`<div class="result"><p>Следующий ход: <b>${esc(game.player.name)}</b></p><button class="button gold" id="handoff">Я готов</button></div>`,{closable:false,kicker:'ЗА СТОЛОМ ДВОЕ'}),$('handoff').onclick=()=>closeModal(true);}
function scheduleAI(){clearTimeout(aiTimer);if(!isAI()||screen!=='game'||!$('modal').hidden||busy||game.phase==='over')return;aiTimer=setTimeout(aiStep,profile.fast?180:700);}
async function aiStep(){
 if(!isAI()||screen!=='game'||!$('modal').hidden||busy)return;
 try{
  if(game.phase==='ready'){game.roll();await animateRoll(game.pool.map((_,i)=>i));scheduleAI();return;}
  if(game.phase==='choose'){resolveChoice();update();scheduleAI();return;}
  if(game.phase==='bust'){
   if(game.badge.type==='resurrection'&&game.canBadge){game.useBadge();await animateRoll(game.pool.map((_,i)=>i));scheduleAI();return;}
   game.bust();sound('bust');afterTurn();return;
  }
  const o=OPPONENTS.find(o=>o.id===game.opponent)||OPPONENTS[0];let choice=aiChoice(game,o.risk);if(!choice){game.evaluate();scheduleAI();return;}
  if(game.canBadge){const b=game.badge;if(b.type==='double'&&choice.points>=300&&game.lastMultiplier===1)game.useBadge(indices(choice.mask));else if(b.type==='warlord'&&choice.bank&&game.turnPoints+choice.points>=300&&game.multiplier===1)game.useBadge();else if(b.type==='fortune'&&game.pool.length>=3&&choice.points<=150){const candidates=game.pool.map((_,i)=>i).filter(i=>!(choice.mask&(1<<i))).slice(0,b.tier);if(candidates.length){game.useBadge(candidates);await animateRoll(candidates);scheduleAI();return;}}}
  choice=aiChoice(game,o.risk);selected=new Set(indices(choice.mask));update();busy=true;await new Promise(r=>setTimeout(r,profile.fast?120:550));busy=false;
  if(choice.bank){game.bank([...selected]);selected.clear();sound('bank');afterTurn();}else{game.keep([...selected]);selected.clear();checkpoint();update();scheduleAI();}
 }catch(e){busy=false;toast(e.message);update();}
}
function result(){
 if(!settled){settled=true;profile.games++;if(game.winner===0){profile.wins++;if(game.stake){profile.gold+=game.stake*2;const won=game.players[1].badge;if(won!=='none')profile.owned[won]=(profile.owned[won]||0)+1;}}else if(game.stake){const lost=game.players[0].badge;if(lost!=='none')profile.owned[lost]=Math.max(0,(profile.owned[lost]||0)-1);}checkpoint();sound(game.winner===0?'win':'bust');vibrate(game.winner===0?'win':'bust');}
 const winner=game.players[game.winner];openModal(game.mode==='ai'?(game.winner===0?'Победа!':'Поражение'):`Победил ${winner.name}`,`<div class="result"><div class="laurel">${game.winner===0?'❦':'⚄'}</div><p>${game.mode==='ai'?(game.winner===0?'Удача сегодня на вашей стороне.':'Трактирщик уже готовит следующую партию.'):'Хорошая партия. Сыграем ещё?'}</p><div class="result-scores">${fmt(game.players[0].score)} : ${fmt(game.players[1].score)}</div><p>${game.stake?(game.winner===0?`Вы выиграли ${game.stake} грошей${game.players[1].badge!=='none'?' и бляху соперника':''}.`:`Вы потеряли ${game.stake} грошей${game.players[0].badge!=='none'?' и свою бляху':''}.`):'Свободная игра завершена.'}</p><button id="again" class="button gold">Ещё партия</button><button id="to-home" class="button">В таверну</button></div>`,{closable:false,kicker:'ДА УЛЫБНЁТСЯ ВАМ УДАЧА'});
 $('again').onclick=()=>{profile.saved=null;game=null;save();closeModal(true);showHome();setup();};$('to-home').onclick=()=>{profile.saved=null;game=null;save();closeModal(true);showHome();};
}
function pauseMenu(){if(busy)return;clearTimeout(aiTimer);openModal('За игровым столом',`<button class="button gold" id="resume">Продолжить</button><button class="button" id="pause-settings">Настройки</button><button class="button" id="save-exit">Сохранить и выйти</button><button class="subtle-button" id="abandon">Сдаться и закончить партию</button>`,{kicker:'ПАУЗА'});$('resume').onclick=()=>closeModal();$('pause-settings').onclick=settings;$('save-exit').onclick=()=>{checkpoint();closeModal(true);showHome();};$('abandon').onclick=()=>{game.winner=1;game.phase='over';closeModal(true);result();};}
$('settings-home').onclick=settings;$('journal').onclick=()=>openModal('Ход партии',game.history.length?game.history.map(t=>`<div class="journal-entry">${esc(t)}</div>`).join(''):'<p>Здесь появятся забранные очки и применения блях.</p>',{kicker:'ЛЕТОПИСЬ ВЕЧЕРА'});

// Keep a small read-only hook for browser smoke tests.
window.trakt={get game(){return game;},get profile(){return profile;},get busy(){return busy;},get positions(){return renderer.positions;}};

showHome();

$('game-menu').onclick=pauseMenu;
