import * as THREE from './vendor/three.module.min.js';
import {dieById} from './data.js';
import {REST_HEIGHT,ease,restingLayout,simulateThrow,sampleThrow,seededRandom,clamp} from './table-motion.js';

const PIPS={1:[[0,0]],2:[[-1,-1],[1,1]],3:[[-1,-1],[0,0],[1,1]],4:[[-1,-1],[1,-1],[-1,1],[1,1]],5:[[-1,-1],[1,-1],[0,0],[-1,1],[1,1]],6:[[-1,-1],[1,-1],[-1,0],[1,0],[-1,1],[1,1]]};
const PALETTES={bone:['#c9b98d','#61503a'],amber:['#c4a14a','#684817'],dark:['#916b40','#39261c'],red:['#9b4533','#36221b'],blue:['#657f8d','#293640'],green:['#7a8054','#363b25']};
const OVERRIDES={ordinary:'dark',antioch:'amber',shrinking:'blue',unbalanced:'green',even:'amber',holy:'amber'};
const FACE_VALUES=[3,4,1,6,2,5]; // BoxGeometry: +X, -X, +Y, -Y, +Z, -Z.
const UP=new THREE.Vector3(0,1,0);
const FACE_NORMALS={1:UP,6:new THREE.Vector3(0,-1,0),3:new THREE.Vector3(1,0,0),4:new THREE.Vector3(-1,0,0),2:new THREE.Vector3(0,0,1),5:new THREE.Vector3(0,0,-1)};
const materialCache=new Map();
let sharedGeometry,sharedWood;

function texture(canvas,srgb=false){const t=new THREE.CanvasTexture(canvas);if(srgb)t.colorSpace=THREE.SRGBColorSpace;t.anisotropy=4;return t;}
function roundedCube(){
 if(sharedGeometry)return sharedGeometry;
 const geometry=new THREE.BoxGeometry(.94,.94,.94,10,10,10),p=geometry.attributes.position,inner=.35,radius=.12;
 for(let i=0;i<p.count;i++){
  const v=new THREE.Vector3().fromBufferAttribute(p,i),core=new THREE.Vector3(clamp(v.x,-inner,inner),clamp(v.y,-inner,inner),clamp(v.z,-inner,inner));
  v.sub(core).normalize().multiplyScalar(radius).add(core);p.setXYZ(i,v.x,v.y,v.z);
 }
 geometry.computeVertexNormals();return sharedGeometry=geometry;
}
function faceMaterial(kind,value){
 const key=`${kind}:${value}`;if(materialCache.has(key))return materialCache.get(key);
 const [base,pip]=PALETTES[kind]||PALETTES.bone,size=256,canvas=document.createElement('canvas'),bump=document.createElement('canvas');
 canvas.width=canvas.height=bump.width=bump.height=size;
 const c=canvas.getContext('2d'),b=bump.getContext('2d'),random=seededRandom(value*53+kind.length*101);
 c.fillStyle=base;c.fillRect(0,0,size,size);b.fillStyle='#c0c0c0';b.fillRect(0,0,size,size);
 for(let i=0;i<3500;i++){
  const x=random()*size,y=random()*size,r=.2+random()*1.3;
  c.fillStyle=i%3?'#281b1210':'#fff1cd18';c.fillRect(x,y,r,r);b.fillStyle=i%2?'#b8b8b8':'#c8c8c8';b.fillRect(x,y,r,r);
 }
 // Aged edges and small tool marks, rather than clean solid-colour faces.
 const edge=c.createRadialGradient(128,128,60,128,128,170);edge.addColorStop(0,'#0000');edge.addColorStop(1,'#20140e50');c.fillStyle=edge;c.fillRect(0,0,size,size);
 if(value===0||value===7){
  c.strokeStyle=pip;c.lineWidth=7;c.lineCap='round';c.lineJoin='round';
  if(value===0){c.beginPath();c.moveTo(84,142);c.lineTo(70,73);c.lineTo(103,98);c.quadraticCurveTo(128,82,153,98);c.lineTo(185,73);c.lineTo(173,142);c.lineTo(128,184);c.closePath();c.stroke();c.fillStyle=pip;for(const x of [106,150]){c.beginPath();c.ellipse(x,126,9,5,x===106?.4:-.4,0,Math.PI*2);c.fill();}}
  else{c.beginPath();c.moveTo(71,147);c.lineTo(77,87);c.lineTo(110,114);c.lineTo(128,63);c.lineTo(148,114);c.lineTo(181,87);c.lineTo(185,147);c.closePath();c.stroke();c.strokeRect(91,159,74,9);}
  b.drawImage(canvas,0,0);
 }else for(const [u,v] of PIPS[value]){
  const x=128+u*58,y=128+v*58,r=17;
  c.fillStyle='#e9d2a755';c.beginPath();c.arc(x-1,y-1,r+2,0,Math.PI*2);c.fill();
  const g=c.createRadialGradient(x-5,y-6,2,x,y,r);g.addColorStop(0,'#201812');g.addColorStop(.7,pip);g.addColorStop(1,'#1b150e');c.fillStyle=g;c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill();
  const depth=b.createRadialGradient(x,y,r*.3,x,y,r+3);depth.addColorStop(0,'#111');depth.addColorStop(.72,'#383838');depth.addColorStop(1,'#c0c0c0');b.fillStyle=depth;b.beginPath();b.arc(x,y,r+3,0,Math.PI*2);b.fill();
 }
 const material=new THREE.MeshStandardMaterial({map:texture(canvas,true),bumpMap:texture(bump),bumpScale:.045,roughness:kind==='amber'?.48:.72,metalness:kind==='amber'?.08:0});
 materialCache.set(key,material);return material;
}
function wood(){
 if(sharedWood)return sharedWood;
 const canvas=document.createElement('canvas');canvas.width=1024;canvas.height=1024;const c=canvas.getContext('2d'),random=seededRandom(1403);
 c.fillStyle='#634a32';c.fillRect(0,0,1024,1024);
 for(let plank=0;plank<6;plank++){
  const y=plank*171,g=c.createLinearGradient(0,y,0,y+171);g.addColorStop(0,plank%2?'#65513b':'#71583c');g.addColorStop(.5,plank%2?'#59432f':'#654b32');g.addColorStop(1,'#382a1f');c.fillStyle=g;c.fillRect(0,y,1024,171);
  for(let i=0;i<700;i++){const yy=y+random()*171,x=random()*1024;c.strokeStyle=i%3?'#211a1330':'#c7a77325';c.lineWidth=.3+random()*1.3;c.beginPath();c.moveTo(x,yy);c.bezierCurveTo(x+40,yy-3,x+100,yy+4,x+160+random()*400,yy);c.stroke();}
  c.fillStyle='#19140e';c.fillRect(0,y,1024,2);c.fillStyle='#ac8a5845';c.fillRect(0,y+3,1024,1);
  for(const x of [55,970]){c.fillStyle='#261e17';c.beginPath();c.arc(x,y+22,4,0,Math.PI*2);c.fill();c.strokeStyle='#af8b5550';c.stroke();}
 }
 for(let k=0;k<8;k++){const x=random()*1024,y=random()*1024;c.save();c.translate(x,y);c.scale(2.7,1);for(let r=3;r<23;r+=3){c.strokeStyle='#241c1640';c.lineWidth=1;c.beginPath();c.ellipse(0,0,r,r*.7,0,0,Math.PI*2);c.stroke();}c.restore();}
 for(let i=0;i<12000;i++){c.fillStyle=i%2?'#110d090c':'#d5b88b0d';c.fillRect(random()*1024,random()*1024,1+random()*2,1);}
 const map=texture(canvas,true);
 const bump=map.clone();bump.colorSpace=THREE.NoColorSpace;bump.needsUpdate=true;
 const ready=new Promise(resolve=>{const photograph=new Image();photograph.onload=()=>{c.drawImage(photograph,photograph.width*.18,photograph.height*.4,photograph.width*.7,photograph.height*.5,0,0,1024,1024);map.needsUpdate=true;bump.needsUpdate=true;resolve();};photograph.onerror=resolve;photograph.src='assets/tavern.jpg';});
 return sharedWood={map,bump,url:canvas.toDataURL('image/jpeg',.85),ready};
}
function topQuaternion(value,yaw){const target=value===0||value===7?1:value,q=new THREE.Quaternion().setFromUnitVectors(FACE_NORMALS[target]||UP,UP);return new THREE.Quaternion().setFromAxisAngle(UP,yaw).multiply(q);}
function materials(id){const die=dieById(id),kind=OVERRIDES[id]||die.material;return FACE_VALUES.map(v=>faceMaterial(kind,v===1&&die.special==='wild'?0:v===1&&die.special==='choose'?7:v));}

export class TableScene{
 constructor(canvas,context,onPick,{onImpact=()=>{},table=true}={}){
  this.canvas=canvas;this.onPick=onPick;this.onImpact=onImpact;this.table=table;this.backend='webgl';this.dice=[];this.held=[];this.selected=new Set();this.poolObjects=[];this.heldObjects=[];this.positions=[];this.animation=null;this.frame=null;this.seed=1403;this.contextLost=false;
  this.renderer=new THREE.WebGLRenderer({canvas,context,antialias:true,alpha:!table,powerPreference:'low-power'});
  this.renderer.setPixelRatio(Math.min(globalThis.devicePixelRatio||1,1.5));this.renderer.shadowMap.enabled=true;this.renderer.shadowMap.type=THREE.PCFSoftShadowMap;
  this.renderer.outputColorSpace=THREE.SRGBColorSpace;this.renderer.toneMapping=THREE.ACESFilmicToneMapping;this.renderer.toneMappingExposure=.95;
  this.scene=new THREE.Scene();this.camera=new THREE.OrthographicCamera(-4,4,4,-4,.1,80);this.camera.position.set(0,16,8);this.camera.lookAt(0,0,0);
  this.scene.add(new THREE.HemisphereLight('#ffe9c8','#3a3024',2.3));
  const lamp=new THREE.DirectionalLight('#ffe3b4',3.4);lamp.position.set(-4,10,-3);lamp.castShadow=true;lamp.shadow.mapSize.set(1024,1024);lamp.shadow.camera.left=-8;lamp.shadow.camera.right=8;lamp.shadow.camera.top=10;lamp.shadow.camera.bottom=-10;lamp.shadow.normalBias=.025;lamp.shadow.bias=-.0002;lamp.shadow.radius=3;this.scene.add(lamp);
  const fill=new THREE.DirectionalLight('#acc8d9',.65);fill.position.set(5,6,8);this.scene.add(fill);
  if(table){const w=wood();document.body.dataset.tableRenderer='webgl';const floor=new THREE.Mesh(new THREE.PlaneGeometry(60,60),new THREE.MeshStandardMaterial({color:'#95836d',map:w.map,bumpMap:w.bump,bumpScale:.02,roughness:.94}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;this.scene.add(floor);this.floor=floor;w.ready.then(()=>this.draw());}
  else{const floor=new THREE.Mesh(new THREE.PlaneGeometry(30,30),new THREE.ShadowMaterial({opacity:.25}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;this.scene.add(floor);}
  this.raycaster=new THREE.Raycaster();this.pointer=new THREE.Vector2();
  canvas.addEventListener('pointerup',e=>this.pick(e));
  canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();this.contextLost=true;this.finishAnimation();});
  canvas.addEventListener('webglcontextrestored',()=>{this.contextLost=false;this.draw();});
  this.observer=new ResizeObserver(()=>this.resize());this.observer.observe(canvas);this.resize();
 }
 makeDie(die){
  const group=new THREE.Group(),mesh=new THREE.Mesh(roundedCube(),materials(die.id));mesh.castShadow=true;mesh.receiveShadow=true;group.add(mesh);group.userData.mesh=mesh;
  const ring=new THREE.Group();for(const [start,length,color] of [[Math.PI*.03,Math.PI*.96,'#3bcaff'],[Math.PI*1.12,Math.PI*.53,'#e5c36a']]){const arc=new THREE.Mesh(new THREE.RingGeometry(.67,.705,48,1,start,length),new THREE.MeshBasicMaterial({color,side:THREE.DoubleSide,transparent:true,opacity:.95}));arc.rotation.x=-Math.PI/2;ring.add(arc);}ring.visible=false;group.userData.ring=ring;this.scene.add(group,ring);group.userData.id=die.id;return group;
 }
 syncObjects(objects,dice){while(objects.length>dice.length){const object=objects.pop();this.scene.remove(object,object.userData.ring);for(const arc of object.userData.ring.children){arc.geometry.dispose();arc.material.dispose();}}
  dice.forEach((d,i)=>{if(!objects[i])objects[i]=this.makeDie(d);if(objects[i].userData.id!==d.id){objects[i].userData.mesh.material=materials(d.id);objects[i].userData.id=d.id;}});
 }
 set(dice,held=[],selected=new Set()){
  const changed=dice.length!==this.dice.length||dice.some((d,i)=>d.id!==this.dice[i]?.id);
  if(changed&&this.animation)this.finishAnimation();
  const oldPool=this.poolObjects.map((o,i)=>({id:o.userData.id,position:o.position.clone(),quaternion:o.quaternion.clone(),yaw:this.poses?.[i]?.yaw||0}));
  const addedHeld=Math.max(0,held.length-this.held.length),previousHeld=this.held.length,previousSelected=new Set(this.selected);
  this.dice=dice.map(d=>({...d}));this.held=held.map(d=>({...d}));this.selected=new Set(selected);
  this.syncObjects(this.poolObjects,this.dice);this.syncObjects(this.heldObjects,this.held);
  if(changed&&!this.animation){const remaining=oldPool.filter((_,i)=>!previousSelected.has(i));this.poses=addedHeld&&remaining.length===dice.length?remaining.map(p=>({x:p.position.x-this.centerX,y:REST_HEIGHT,z:p.position.z-this.centerZ,yaw:p.yaw})):restingLayout(dice.length,this.worldWidth,this.worldDepth,++this.seed);}
  this.poses??=restingLayout(dice.length,this.worldWidth,this.worldDepth,this.seed);
  if(addedHeld&&oldPool.length&&!this.animation){
   const candidates=oldPool.filter((_,i)=>previousSelected.has(i)),used=new Set();
   const moves=[];for(let i=previousHeld;i<held.length;i++){const match=candidates.findIndex((p,j)=>!used.has(j)&&p.id===held[i].id);if(match>=0){used.add(match);moves.push({index:i,from:candidates[match].position,rotation:candidates[match].quaternion});}}
   if(moves.length){let resolve;this.collectionPromise=new Promise(r=>resolve=r);this.animation={kind:'collect',start:performance.now(),duration:globalThis.matchMedia?.('(prefers-reduced-motion: reduce)').matches?0:420,moves,resolve};}
  }
  this.draw(performance.now());
 }
 groundAt(x,y){this.camera.updateMatrixWorld();const raycaster=new THREE.Raycaster();raycaster.setFromCamera(new THREE.Vector2(x/this.width*2-1,-y/this.height*2+1),this.camera);return raycaster.ray.intersectPlane(new THREE.Plane(UP,0),new THREE.Vector3());}
 resize(){const rect=this.canvas.getBoundingClientRect();if(!rect.width||!rect.height)return;this.width=rect.width;this.height=rect.height;const aspect=this.width/this.height;this.viewWidth=aspect>1.7?13:7.2;const viewHeight=this.viewWidth/aspect;this.camera.left=-this.viewWidth/2;this.camera.right=this.viewWidth/2;this.camera.top=viewHeight/2;this.camera.bottom=-viewHeight/2;this.camera.updateProjectionMatrix();this.renderer.setSize(this.width,this.height,false);
  if(this.floor){this.floor.geometry.dispose();this.floor.geometry=new THREE.PlaneGeometry(this.viewWidth*1.16,viewHeight*1.35);}
  const area=this.table?this.canvas.parentElement.getBoundingClientRect():rect,topLeft=this.groundAt(area.left-rect.left,area.top-rect.top),bottomRight=this.groundAt(area.right-rect.left,area.bottom-rect.top);
  this.worldWidth=Math.max(3.5,(bottomRight.x-topLeft.x)*.91);this.worldDepth=Math.max(3,(bottomRight.z-topLeft.z)*.87);this.centerX=(topLeft.x+bottomRight.x)/2;this.centerZ=(topLeft.z+bottomRight.z)/2;
  if(!this.animation)this.poses=restingLayout(this.dice.length,this.worldWidth,this.worldDepth,this.seed);this.draw(performance.now());
 }
 heldPose(i){const gap=Math.min(.92,(this.worldWidth-1)/Math.max(1,this.held.length));return {x:(i-(this.held.length-1)/2)*gap,y:.31,z:this.worldDepth/2-.75,yaw:.1*(i-2)};}
 draw(time=performance.now()){
  if(!this.width||this.contextLost)return;
  const animation=this.animation,p=animation?clamp((time-animation.start)/Math.max(1,animation.duration),0,1):1;
  const poses=animation?.kind==='throw'?sampleThrow(animation.simulation,p):this.poses;
  this.poolObjects.forEach((object,i)=>{
   const pose=poses[i];if(!pose)return;object.position.set(pose.x+this.centerX,pose.y,pose.z+this.centerZ);object.scale.setScalar(1);
   const final=topQuaternion(this.dice[i].value??(i%6+1),pose.yaw);
   if(animation?.kind==='throw'&&animation.indices.has(i)){
    const spin=pose.spin,phase=p*animation.simulation.seconds;
    const tumble=new THREE.Quaternion().setFromEuler(new THREE.Euler(spin[0]*phase,spin[1]*phase,spin[2]*phase));
    object.quaternion.copy(tumble).slerp(final,ease((p-.55)/.45));
   }else object.quaternion.copy(final);
   const ring=object.userData.ring;ring.position.set(pose.x+this.centerX,.012,pose.z+this.centerZ);ring.visible=this.selected.has(i)&&!animation;
  });
  this.heldObjects.forEach((object,i)=>{
   const pose=this.heldPose(i),q=topQuaternion(this.held[i].value??1,pose.yaw),move=animation?.kind==='collect'?animation.moves.find(m=>m.index===i):null;
   object.position.set(pose.x+this.centerX,pose.y,pose.z+this.centerZ);object.quaternion.copy(q);object.scale.setScalar(.63);object.userData.ring.visible=false;
   if(move){const t=ease(p);object.position.lerpVectors(move.from,new THREE.Vector3(pose.x+this.centerX,pose.y,pose.z+this.centerZ),t);object.position.y+=Math.sin(p*Math.PI)*.3;object.quaternion.copy(move.rotation).slerp(q,t);object.scale.setScalar(1-.37*t);}
  });
  if(animation?.kind==='throw'){while(animation.nextHit<animation.simulation.hits.length&&animation.simulation.hits[animation.nextHit].time<=p*animation.simulation.seconds){const hit=animation.simulation.hits[animation.nextHit++];this.onImpact(hit.strength,hit.index);}}
  this.renderer.render(this.scene,this.camera);this.updatePositions();
  if(animation){if(p<1){cancelAnimationFrame(this.frame);this.frame=requestAnimationFrame(t=>this.draw(t));}else this.finishAnimation();}
 }
 updatePositions(){this.positions=this.poolObjects.map((object,index)=>{const p=object.position.clone().project(this.camera);const scale=object.scale.x;return {index,x:(p.x*.5+.5)*this.width,y:(-.5*p.y+.5)*this.height,size:this.width/this.viewWidth*.47*scale};});}
 pick(event){if(this.animation||this.contextLost)return;const rect=this.canvas.getBoundingClientRect();this.pointer.set((event.clientX-rect.left)/rect.width*2-1,-(event.clientY-rect.top)/rect.height*2+1);this.raycaster.setFromCamera(this.pointer,this.camera);const hits=this.raycaster.intersectObjects(this.poolObjects.map(o=>o.userData.mesh));if(hits.length){this.onPick(this.poolObjects.findIndex(o=>o.userData.mesh===hits[0].object));return;}
  // Touch targets are slightly larger than the visible cube on small screens.
  const x=event.clientX-rect.left,y=event.clientY-rect.top,near=this.positions.map(p=>({...p,distance:Math.hypot(x-p.x,y-p.y)})).sort((a,b)=>a.distance-b.distance)[0];if(near&&near.distance<Math.max(22,near.size*1.4))this.onPick(near.index);
 }
 finishAnimation(){const animation=this.animation;if(!animation)return;cancelAnimationFrame(this.frame);if(animation.kind==='throw')this.poses=animation.simulation.final.map(p=>({...p}));this.animation=null;animation.resolve();if(!this.contextLost)this.draw();}
 animate(indices,duration=1600){
  this.finishAnimation();if(this.contextLost||!this.width||!indices.length)return Promise.resolve();
  const simulation=simulateThrow(this.poses,indices,{seed:++this.seed,width:this.worldWidth,depth:this.worldDepth});
  if(duration<=100){this.poses=simulation.final;this.draw();return Promise.resolve();}
  return new Promise(resolve=>{this.animation={kind:'throw',start:performance.now(),duration,simulation,indices:new Set(indices),nextHit:0,resolve};this.draw();});
 }
 waitForIdle(){return this.collectionPromise||Promise.resolve();}
 get visibleFaces(){return this.poolObjects.map(o=>{let value=1,dot=-Infinity;for(const [face,normal] of Object.entries(FACE_NORMALS)){const y=normal.clone().applyQuaternion(o.quaternion).y;if(y>dot){dot=y;value=+face;}}return value;});}
 get ready(){return !this.contextLost;}
}
