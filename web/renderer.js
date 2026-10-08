import {dieById} from './data.js';
const PIPS={1:[[0,0]],2:[[-.5,-.5],[.5,.5]],3:[[-.5,-.5],[0,0],[.5,.5]],4:[[-.5,-.5],[.5,-.5],[-.5,.5],[.5,.5]],5:[[-.5,-.5],[.5,-.5],[0,0],[-.5,.5],[.5,.5]],6:[[-.5,-.5],[.5,-.5],[-.5,0],[.5,0],[-.5,.5],[.5,.5]]};
const MATERIALS={bone:[237,214,166],amber:[193,142,70],dark:[86,69,50],red:[142,59,41],blue:[60,100,109],green:[86,104,59]};
const rgb=(c,f=1)=>`rgb(${c.map(v=>Math.min(255,Math.round(v*f))).join(',')})`;
const rot=([x,y,z],a,b,c)=>{let y1=y*Math.cos(a)-z*Math.sin(a),z1=y*Math.sin(a)+z*Math.cos(a);let x1=x*Math.cos(b)+z1*Math.sin(b),z2=-x*Math.sin(b)+z1*Math.cos(b);return [x1*Math.cos(c)-y1*Math.sin(c),x1*Math.sin(c)+y1*Math.cos(c),z2];};
const FACES=[
 {v:[[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]],n:[0,0,1],f:1},
 {v:[[1,-1,-1],[-1,-1,-1],[-1,1,-1],[1,1,-1]],n:[0,0,-1],f:6},
 {v:[[1,-1,1],[1,-1,-1],[1,1,-1],[1,1,1]],n:[1,0,0],f:3},
 {v:[[-1,-1,-1],[-1,-1,1],[-1,1,1],[-1,1,-1]],n:[-1,0,0],f:4},
 {v:[[-1,-1,-1],[1,-1,-1],[1,-1,1],[-1,-1,1]],n:[0,-1,0],f:2},
 {v:[[-1,1,1],[1,1,1],[1,1,-1],[-1,1,-1]],n:[0,1,0],f:5}
];
// Opposite faces always sum to 7. Swap front with the requested face.
function faceValue(face,value){const target=value===0||value===7?1:value;if(target===1)return face;if(face===1)return target;if(face===target)return 1;if(face===6)return 7-target;if(face===7-target)return 6;return face;}
export class DiceRenderer{
 constructor(canvas,onPick=()=>{}){
  this.canvas=canvas;this.ctx=canvas.getContext('2d');this.onPick=onPick;this.dice=[];this.held=[];this.selected=new Set();this.animation=null;this.frame=null;this.width=0;this.height=0;
  this.resizeObserver=new ResizeObserver(()=>this.resize());this.resizeObserver.observe(canvas);
  canvas.addEventListener('pointerup',e=>{if(this.animation)return;const r=canvas.getBoundingClientRect(),x=e.clientX-r.left,y=e.clientY-r.top;const d=this.positions?.find(p=>Math.hypot(x-p.x,y-p.y)<p.size*1.7);if(d)this.onPick(d.index);});
 }
 resize(){const r=this.canvas.getBoundingClientRect(),ratio=Math.min(devicePixelRatio||1,2);this.width=r.width;this.height=r.height;this.canvas.width=r.width*ratio;this.canvas.height=r.height*ratio;this.ctx.setTransform(ratio,0,0,ratio,0,0);this.draw();}
 set(dice,held=[],selected=new Set()){this.dice=dice;this.held=held;this.selected=selected;this.draw();}
 layout(){const w=this.width,h=this.height,n=this.dice.length,cols=n<=3?n:n<=6?3:4;const rows=Math.ceil(n/cols);const size=Math.min(w/(cols*3.3),h/(rows*3.5+(this.held.length?1.9:0)),38);const gapX=Math.min(size*3.3,w/(cols+.3));const gapY=size*3.5;const centerY=(h-(this.held.length?size*1.9:0))/2;return this.dice.map((d,i)=>({index:i,x:w/2+(i%cols-(Math.min(cols,n)-1)/2)*gapX+(i>=cols&&n%cols?(cols-n%cols)*gapX/2:0),y:centerY+(Math.floor(i/cols)-(rows-1)/2)*gapY,size}));}
 draw(time=0){
  if(!this.width)return;const c=this.ctx;c.clearRect(0,0,this.width,this.height);this.positions=this.layout();let p=1;if(this.animation)p=Math.min(1,(time-this.animation.start)/this.animation.duration);
  for(const pos of this.positions){const die=this.dice[pos.index];let {x,y,size}=pos,a=-.32,b=.32,z=(Math.sin(pos.index*14.3)*.19);
   if(this.animation&&this.animation.indices.has(pos.index)){
    const seed=this.animation.seeds[pos.index],u=1-p;
    x+=Math.sin(p*14+seed)*u*size*1.8;y-=Math.abs(Math.sin(p*Math.PI*3))*u*size*1.6;
    a+=u*(8+seed);b+=u*(12+seed);z+=u*(13-seed);size*=1+Math.sin(p*Math.PI)*.15;
   }
   this.cube(x,y,size,die.value??(pos.index%6+1),dieById(die.id).material,a,b,z,this.selected.has(pos.index),false,pos.index);
  }
  const n=this.held.length;if(n){const size=Math.min(15,this.width/(n*3.1)),gap=size*2.9;for(let i=0;i<n;i++)this.cube(this.width/2+(i-(n-1)/2)*gap,this.height-26,size,this.held[i].value,dieById(this.held[i].id).material,-.3,.3,i*.1,false,true,i);}
  if(this.animation){if(p<1)this.frame=requestAnimationFrame(t=>this.draw(t));else{const cb=this.animation.resolve;this.animation=null;this.draw();cb();}}
 }
 cube(x,y,size,value,material,a,b,z,selected,small,index){
  const c=this.ctx,base=MATERIALS[material]||MATERIALS.bone;
  c.save();c.translate(x,y);
  const shadow=c.createRadialGradient(3,size*.6,2,3,size*.6,size*2);shadow.addColorStop(0,'#0009');shadow.addColorStop(1,'#0000');c.fillStyle=shadow;c.beginPath();c.ellipse(3,size*.6,size*2,size*1.35,0,0,Math.PI*2);c.fill();
  if(selected){c.strokeStyle='#ffda87';c.lineWidth=2;c.shadowColor='#ffd36a';c.shadowBlur=12;c.beginPath();c.ellipse(0,size*.35,size*1.85,size*1.4,0,0,Math.PI*2);c.stroke();c.shadowBlur=0;}
  const project=v=>{const q=rot(v,a,b,z),f=5/(5-q[2]);return [q[0]*size*f,q[1]*size*f,q[2]];};
  const faces=FACES.map(f=>({...f,normal:rot(f.n,a,b,z),verts:f.v.map(project)})).filter(f=>f.normal[2]>.01).sort((u,v)=>u.normal[2]-v.normal[2]);
  for(const f of faces){
   const light=.48+.5*f.normal[2]-.12*f.normal[0]-.19*f.normal[1];const pts=f.verts;
   c.beginPath();pts.forEach((q,i)=>i?c.lineTo(q[0],q[1]):c.moveTo(q[0],q[1]));c.closePath();const gradient=c.createLinearGradient(pts[0][0],pts[0][1],pts[2][0],pts[2][1]);gradient.addColorStop(0,rgb(base,light+ .12));gradient.addColorStop(1,rgb(base,light-.09));c.fillStyle=gradient;c.strokeStyle=rgb(base,.5);c.lineWidth=1.1;c.lineJoin='round';c.fill();c.stroke();
   const val=faceValue(f.f,value);
   const at=(u,v)=>{const p0=f.v[0],p1=f.v[1],p3=f.v[3];return project(p0.map((x,i)=>x+(p1[i]-x)*(u+1)/2+(p3[i]-x)*(v+1)/2));};
   if((value===0||value===7)&&f.f===1){const q=at(0,0);c.save();c.translate(q[0],q[1]);c.rotate(z);c.fillStyle=material==='dark'?'#d0a45f':'#4d2717';c.font=`bold ${size*1.1}px Georgia`;c.textAlign='center';c.textBaseline='middle';c.fillText(value===0?'♆':'♧',0,1);c.restore();}
   else for(const [u,v] of PIPS[val]||[]){const p=at(u,v),pu=at(u+.1,v),pv=at(u,v+.1);const r=size*.15;const scale=Math.max(.22,f.normal[2]);c.save();c.translate(p[0],p[1]);c.rotate(Math.atan2(pu[1]-p[1],pu[0]-p[0]));c.scale(1,scale);c.beginPath();c.arc(0,0,r,0,Math.PI*2);c.fillStyle=material==='dark'?'#d4b581':'#382116';c.fill();c.beginPath();c.arc(-r*.2,-r*.2,r*.5,Math.PI,Math.PI*1.7);c.strokeStyle=material==='dark'?'#fae0a650':'#140c0680';c.lineWidth=Math.max(.6,size*.04);c.stroke();c.restore();}
  }
  if(!small){c.fillStyle=selected?'#ffda87':'#d4ba91';c.font=`${Math.max(9,size*.28)}px Trakt`;c.textAlign='center';c.fillText(value===0?'Дьявол':value===7?'Выбрать':String(value??''),0,size*2.08);}
  c.restore();
 }
 animate(indices,duration=900){
  if(this.animation){cancelAnimationFrame(this.frame);this.animation.resolve();}
  return new Promise(resolve=>{this.animation={start:performance.now(),duration,indices:new Set(indices),seeds:this.dice.map(()=>Math.random()*5),resolve};this.frame=requestAnimationFrame(t=>this.draw(t));});
 }
}
