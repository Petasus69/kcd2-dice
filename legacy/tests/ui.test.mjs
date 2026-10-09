import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {JSDOM} from 'jsdom';

test('Menu, catalog, full local match, save/resume and settings work through DOM handlers',async()=>{
 const html=fs.readFileSync(new URL('../web/index.html',import.meta.url),'utf8');
 const dom=new JSDOM(html,{url:'https://dice.local',pretendToBeVisual:true});
 const {window}=dom;
 Object.assign(globalThis,{window,document:window.document,localStorage:window.localStorage,devicePixelRatio:1,matchMedia:()=>({matches:true}),ResizeObserver:class{observe(){}},requestAnimationFrame:fn=>setTimeout(()=>fn(performance.now()+2000),0),cancelAnimationFrame:clearTimeout});
 Object.defineProperty(globalThis,'navigator',{value:{vibrate(){}},configurable:true});
 const ctx=new Proxy({}, {get:(obj,key)=>key.startsWith('create')?()=>({addColorStop(){}}):()=>{},set:()=>true});
 window.HTMLCanvasElement.prototype.getContext=()=>ctx;
 window.HTMLCanvasElement.prototype.getBoundingClientRect=()=>({width:350,height:300,left:0,top:0});
 await import('../web/ui.js');
 const el=id=>document.getElementById(id),click=id=>el(id).click();
 assert.equal(el('home').hidden,false);assert.equal(el('play').hidden,true);
 click('equipment');assert.ok(document.querySelectorAll('[data-die]').length>=40);
 document.querySelector('[data-die="weighted"]').click();assert.equal(window.trakt.profile.loadouts[0][0],'weighted');
 click('tab-badges');assert.ok(document.querySelectorAll('[data-badges]').length===0);assert.ok(document.querySelectorAll('[data-badge]').length>=30);
 click('close-modal');click('rules-home');assert.ok(el('modal-body').textContent.replace(/\s/g,'').includes('1500'));click('close-modal');
 click('settings-home');el('setting-fast').checked=true;el('setting-fast').dispatchEvent(new window.Event('change'));click('close-modal');
 click('new-game');click('mode-local');click('start-match');assert.equal(window.trakt.game.mode,'local');assert.equal(el('play').hidden,false);
 // Pin a reproducible throw so selection and bank handlers can be verified.
 window.trakt.game.rng=()=>0;
 click('roll');await new Promise(r=>setTimeout(r,30));assert.equal(window.trakt.game.phase,'select');assert.equal(window.trakt.busy,false);
 click('hint');assert.ok(!el('bank').disabled);assert.equal(el('selection-points').textContent.replace(/\s/g,''),'+8000');
 click('game-menu');click('save-exit');assert.equal(el('home').hidden,false);assert.ok(window.trakt.profile.saved);assert.equal(el('continue').hidden,false);
 click('continue');assert.equal(el('play').hidden,false);click('hint');click('bank');assert.equal(window.trakt.game.phase,'over');assert.equal(window.trakt.profile.wins,1);
 click('to-home');assert.equal(window.trakt.profile.saved,null);assert.equal(el('home').hidden,false);
 // Start an AI game, bank once and ensure the AI's actions finish back on player zero.
 click('new-game');click('mode-ai');click('start-match');window.trakt.game.rng=()=>.03;click('roll');await new Promise(r=>setTimeout(r,30));
 const first=document.querySelector('[data-access-die="0"]');first.click();click('bank');
 for(let i=0;i<60&&window.trakt.game.active===1;i++)await new Promise(r=>setTimeout(r,40));
 assert.equal(window.trakt.game.phase,'over');assert.equal(window.trakt.game.winner,1);assert.ok(window.trakt.game.players[1].score>0);assert.equal(window.trakt.busy,false);
 click('to-home');
 dom.window.close();
});
