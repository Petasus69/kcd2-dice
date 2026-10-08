// Visual physics only. The game engine supplies all face values independently.
export const REST_HEIGHT=.48;
export const clamp=(v,lo,hi)=>Math.max(lo,Math.min(hi,v));
export const ease=t=>1-Math.pow(1-clamp(t,0,1),3);
export function seededRandom(seed){let state=seed>>>0;return()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};}

export function restingLayout(count,width=7,depth=7,seed=1){
 const random=seededRandom(seed),cols=count>6?4:count>3?3:Math.max(1,count),rows=Math.ceil(count/cols);
 const gap=Math.min(1.65,(width-1.4)/cols,(depth-1.5)/Math.max(1,rows));
 return Array.from({length:count},(_,i)=>{
  const inRow=Math.min(cols,count-Math.floor(i/cols)*cols);
  return {x:(i%cols-(inRow-1)/2)*gap+(random()-.5)*.16,y:REST_HEIGHT,z:(Math.floor(i/cols)-(rows-1)/2)*gap-.25,yaw:(random()-.5)*1.8};
 });
}

// Fixed steps avoid refresh-rate dependent collisions. Horizontal contacts use
// circular bounds; vertical contacts model gravity, restitution and table friction.
export function simulateThrow(positions,indices,{seed=1,width=7,depth=7}={}){
 const random=seededRandom(seed),moving=new Set(indices),hits=[],frames=[];
 const bodies=positions.map((p,i)=>({...p,moving:moving.has(i),vx:0,vy:0,vz:0,spin:[0,0,0],lastHit:-1}));
 let launch=0;
 for(const b of bodies){if(!b.moving)continue;
  b.x=-width/2+.6+(launch%2)*1.17;b.z=-depth*.25+Math.floor(launch/2)*1.17;
  b.y=2.3+random()*.9;b.vx=3.4-(launch%2)*1.4+random()*.8;b.vy=-1-random()*2;b.vz=.3+random()*.7;
  b.spin=[(random()-.5)*18,(random()-.5)*18,(random()-.5)*18];launch++;
 }
 const dt=1/90,seconds=2.4,radius=.57;
 for(let step=0;step<=seconds/dt;step++){
  const t=step*dt;
  frames.push(bodies.map(b=>({x:b.x,y:b.y,z:b.z,spin:[...b.spin],yaw:b.yaw})));
  for(let i=0;i<bodies.length;i++){
   const b=bodies[i];if(!b.moving)continue;
   b.vy-=19*dt;b.x+=b.vx*dt;b.y+=b.vy*dt;b.z+=b.vz*dt;
   if(b.y<=REST_HEIGHT){
    const impact=-b.vy;b.y=REST_HEIGHT;b.vy=impact>1.2?impact*.32:0;
    const friction=Math.exp(-7*dt);b.vx*=friction;b.vz*=friction;
    if(impact>1.2&&t-b.lastHit>.055){hits.push({time:t,index:i,strength:clamp(impact/10,.1,1)});b.lastHit=t;}
   }
   for(const axis of ['x','z']){const limit=(axis==='x'?width:depth)/2-radius,v=axis==='x'?'vx':'vz';if(Math.abs(b[axis])>limit){b[axis]=clamp(b[axis],-limit,limit);b[v]*=-.35;}}
  }
  for(let i=0;i<bodies.length;i++)for(let j=i+1;j<bodies.length;j++){
   const a=bodies[i],b=bodies[j];if(!a.moving&&!b.moving||Math.abs(a.y-b.y)>.8)continue;
   let dx=b.x-a.x,dz=b.z-a.z,d=Math.hypot(dx,dz);if(d>=radius*2)continue;
   if(d<.0001){dx=1;dz=0;d=1;}
   const nx=dx/d,nz=dz/d,overlap=radius*2-Math.min(d,radius*2),weight=a.moving&&b.moving?.5:1;
   if(a.moving){a.x-=nx*overlap*weight;a.z-=nz*overlap*weight;}
   if(b.moving){b.x+=nx*overlap*weight;b.z+=nz*overlap*weight;}
   const speed=(b.vx-a.vx)*nx+(b.vz-a.vz)*nz;
   if(speed<0){const impulse=-speed*.65;if(a.moving){a.vx-=impulse*nx;a.vz-=impulse*nz;}if(b.moving){b.vx+=impulse*nx;b.vz+=impulse*nz;}}
  }
 }
 const final=frames.at(-1);
 for(const b of final){b.y=REST_HEIGHT;b.x=clamp(b.x,-width/2+radius,width/2-radius);b.z=clamp(b.z,-depth/2+radius,depth/2-radius);}
 return {frames,hits,seconds,final};
}

export function sampleThrow(simulation,progress){
 const at=clamp(progress,0,1)*(simulation.frames.length-1),index=Math.floor(at),fraction=at-index;
 const a=simulation.frames[index],b=simulation.frames[Math.min(index+1,simulation.frames.length-1)];
 return a.map((p,i)=>({...p,x:p.x+(b[i].x-p.x)*fraction,y:p.y+(b[i].y-p.y)*fraction,z:p.z+(b[i].z-p.z)*fraction}));
}
