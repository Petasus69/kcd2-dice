// Integer relative weights avoid rounding published percentages.
export const DICE = [
 ['ordinary','Обычная',[1,1,1,1,1,1],'bone'],
 ['aranka','Кость Аранки',[6,1,6,1,6,1],'red'],
 ['cautious','Осторожного шулера',[5,3,2,3,5,3],'bone'],
 ['ci','Ci',[1,1,1,1,1,2],'dark'],
 ['devil','Голова дьявола',[1,1,1,1,1,1],'dark','wild'],
 ['misfortune','Несчастья',[1,5,5,5,5,1],'dark'],
 ['even','Чётная',[1,4,1,4,1,4],'bone'],
 ['favourable','Благоприятная',[6,0,1,1,6,4],'amber'],
 ['fer','Fer',[1,1,1,1,1,2],'dark'],
 ['greasy','Засаленная',[3,2,3,2,3,4],'amber'],
 ['grimy','Грязная',[1,5,1,1,7,1],'dark'],
 ['grozav','Счастливая Грозава',[1,10,1,1,1,1],'red'],
 ['heaven','Небесного царства',[7,2,2,2,2,4],'bone'],
 ['holy','Святой Троицы',[4,5,7,1,1,1],'amber'],
 ['hugo','Кость Гуго',[1,1,1,1,1,1],'red'],
 ['king','Королевская',[4,6,7,8,4,3],'red'],
 ['lousy','Плохого игрока',[2,3,2,3,7,3],'bone'],
 ['lu','Lu',[1,1,1,1,1,2],'dark'],
 ['lucky','Счастливая',[6,1,2,3,4,6],'amber'],
 ['math','Математика',[4,5,6,7,1,1],'bone'],
 ['molar','Коренной зуб',[1,1,1,1,1,1],'bone'],
 ['monk','Монаха',[8,8,1,1,1,1],'bone'],
 ['pearl','Перламутровая',[3,1,1,1,3,3],'blue'],
 ['odd','Нечётная',[4,1,4,1,4,1],'amber'],
 ['painted','Расписная',[3,1,1,1,6,3],'blue'],
 ['painter-b','Художника · синяя',[1,3,2,2,2,1],'blue'],
 ['painter-g','Художника · зелёная',[1,3,2,2,2,1],'green'],
 ['painter-r','Художника · красная',[1,3,2,2,2,1],'red'],
 ['pie','Пирожковая',[6,1,3,3,0,0],'amber'],
 ['premolar','Малый коренной зуб',[1,1,1,1,1,1],'bone'],
 ['sad','Грустного мазилы',[6,6,1,1,6,3],'blue'],
 ['antioch','Святого Антиоха',[3,1,6,1,1,3],'red'],
 ['shrinking','Усадочная',[2,1,1,1,1,3],'bone'],
 ['stephen','Святого Стефана',[1,1,1,1,1,1],'bone'],
 ['strip','Раздевальная',[4,2,2,2,3,3],'red'],
 ['tengri','Тенгри',[2,1,1,1,1,1],'blue'],
 ['trinity','Троичная',[2,1,4,1,2,1],'amber'],
 ['unbalanced','Несбалансированная',[3,4,1,1,2,1],'bone'],
 ['unlucky','Несчастливая',[1,3,2,2,2,1],'dark'],
 ['wagon','Возчика',[1,5,6,2,2,2],'amber'],
 ['weighted','Утяжелённая',[10,1,1,1,1,1],'dark'],
 ['wisdom','Зуб мудрости',[1,1,1,1,1,1],'bone'],
 ['balatro','Шута',[1,1,1,1,1,1],'red','choose']
].map(([id,name,weights,material,special])=>({id,name,weights,material,special}));
export const dieById = id => DICE.find(d=>d.id===id)||DICE[0];
export const TIER_NAMES=['Без бляхи','Олово','Серебро','Золото'];
const TYPES = [
 ['fortune','Удачи','↻',t=>`Перебросьте до ${t} выбранных костей. Один раз за партию.`],
 ['might','Силы','✚',t=>`Добавьте обычную кость к броску. ${t} применений за партию.`],
 ['defence','Защиты','♜',()=>`Отключает бляху соперника того же ранга на всю партию.`],
 ['headstart','Форы','⚑',t=>`Начните с ${[0,100,200,400][t]} очками.`],
 ['resurrection','Воскрешения','✝',t=>`Спасите пустой бросок: бросьте оставшиеся кости снова. ${t} применений.`],
 ['transmutation','Превращения','✧',t=>`Превратите выбранную кость в ${[0,3,5,1][t]}. Один раз за партию.`],
 ['double','Двойника','Ⅱ',t=>`Удвойте очки выбранной комбинации. ${t} применений за партию.`],
 ['warlord','Полководца','⚔',t=>`Увеличьте очки хода на ${[0,25,50,100][t]}%. Один раз за партию.`]
];
export const BADGES=[{id:'none',name:'Без бляхи',tier:0,type:'none',uses:0,icon:'—',desc:'Классическая партия. Только кости и удача.'}];
for(let tier=1;tier<=3;tier++) for(const [type,title,icon,desc] of TYPES) BADGES.push({id:`${type}-${tier}`,name:`${['','Оловянная','Серебряная','Золотая'][tier]} · ${title}`,tier,type,uses:['might','resurrection','double'].includes(type)?tier:1,icon,desc:desc(tier)});
BADGES.push(
 {id:'cut',name:'Плотника',tier:1,type:'formation',uses:Infinity,icon:'⌁',desc:'Комбинация «Рез»: 3 + 5. В этой версии — 200 очков.',formation:[3,5],points:200},
 {id:'gallows',name:'Палача',tier:2,type:'formation',uses:Infinity,icon:'┬',desc:'Комбинация «Виселица»: 4 + 5 + 6. В этой версии — 300 очков.',formation:[4,5,6],points:300},
 {id:'eye',name:'Священника',tier:3,type:'formation',uses:Infinity,icon:'◈',desc:'Комбинация «Око»: 1 + 3 + 5. В этой версии — 300 очков.',formation:[1,3,5],points:300},
 {id:'bird',name:'Птичьего короля',tier:2,type:'might',uses:2,icon:'♛',desc:'Дополнительная обычная кость. Два раза за партию.'},
 {id:'swap-2',name:'Серебряная · Замены',tier:2,type:'swap',uses:1,icon:'⇄',desc:'Перебросьте одну выбранную кость. Один раз за партию.'},
 {id:'swap-3',name:'Золотая · Замены',tier:3,type:'swap',uses:1,icon:'⇄',desc:'Перебросьте две кости с одинаковым значением. Один раз за партию.'},
 {id:'emperor',name:'Императора',tier:3,type:'emperor',uses:Infinity,icon:'♛',desc:'Комбинации из трёх и более единиц приносят втрое больше очков.'},
 {id:'wedding',name:'Свадебная',tier:3,type:'fortune',uses:1,icon:'❦',desc:'Перебросьте до трёх выбранных костей. Один раз за партию.'},
 {id:'tyche',name:'Тихе',tier:3,type:'tyche',uses:Infinity,icon:'✥',desc:'Тройки и группы шестёрок приносят вдвое больше очков.'},
 {id:'jester',name:'Шута',tier:1,type:'jester',uses:1,icon:'♧',desc:'Один раз измените значение своей кости Шута на любое число.'}
);
export const badgeById=id=>BADGES.find(b=>b.id===id)||BADGES[0];
export const CONTRACTS=[
 {id:'beggar',name:'Нищие',goal:1500,stake:10,tier:0},
 {id:'wagoner',name:'Возчики',goal:2000,stake:30,tier:0},
 {id:'craftsman',name:'Ремесленники',goal:3000,stake:70,tier:0},
 {id:'courtier',name:'Придворные',goal:4000,stake:130,tier:0},
 {id:'tin',name:'Оловянный стол',goal:2000,stake:50,tier:1},
 {id:'silver',name:'Серебряный стол',goal:3000,stake:110,tier:2},
 {id:'gold',name:'Золотой стол',goal:4000,stake:180,tier:3},
 {id:'emperor',name:'Императоры',goal:5000,stake:300,tier:3}
];
export const OPPONENTS=[
 {id:'miller',name:'Мельник Матей',title:'Осторожный игрок',risk:.7,dice:['ordinary','ordinary','ordinary','ordinary','ordinary','ordinary'],badge:'fortune'},
 {id:'soldier',name:'Стражник Вацлав',title:'Любит рискнуть',risk:1.25,dice:['ordinary','odd','ordinary','ordinary','cautious','ordinary'],badge:'warlord'},
 {id:'merchant',name:'Купец Бенеш',title:'Считает каждую кость',risk:1,dice:['lucky','cautious','ordinary','ordinary','greasy','ordinary'],badge:'double'},
 {id:'sharper',name:'Шулер Марек',title:'Мастер особых костей',risk:1.1,dice:['favourable','weighted','lucky','devil','heaven','favourable'],badge:'resurrection'}
];
