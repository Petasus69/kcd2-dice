// Shared metadata only. Loaded dice and the jester badge intentionally excluded.
import {writeFileSync} from 'node:fs';
import {BADGES, CONTRACTS, OPPONENTS} from '../../legacy/web/data.js';
writeFileSync(new URL('../catalog.json', import.meta.url), JSON.stringify({
  badges: BADGES.filter(b=>b.type!=='jester').map(b=>({...b,uses:Number.isFinite(b.uses)?b.uses:-1})),
  contracts: CONTRACTS,
  opponents: OPPONENTS.map(({dice,...o})=>({...o,title:o.id==='sharper'?'Опытный игрок':o.title})),
},null,2)+'\n');
