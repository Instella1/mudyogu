const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(__dirname+'/../primal-journey.html','utf8');
const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const PROG='primalJourney.progress.v1';
function boot(storage={}){
 const gradient={addColorStop(){}},draws=[],els={};
 const ctx=new Proxy({createLinearGradient:()=>gradient,createRadialGradient:()=>gradient,fillText(text,x,y){draws.push({text:String(text),x,y})}},{get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 const el=id=>els[id]??={hidden:false,getContext:()=>ctx,setAttribute(k,v){this[k]=v},classList:{toggle(){}},addEventListener(){},focus(){}};
 const box={console,Math,localStorage:{getItem:k=>storage[k]||null,setItem(k,v){storage[k]=v}},document:{getElementById:el,querySelectorAll:()=>[],addEventListener(){}},window:{addEventListener(){}},requestAnimationFrame(){},matchMedia:()=>({matches:false})};
 const js=source.replace(/\}\)\(\);\s*$/,`globalThis.t={...window.primalJourney,reset,updatePlayer,updateCourse,updateSpear,throwSpear,enterCourse,courseLedges,maceBall,windPhase,dripDrop,blinkPhase,victory,goHome,validProgress,COURSES,COURSE_RULES,get p(){return player},get run(){return courseRun},get course(){return course},get keys(){return keys},get press(){return press},get spear(){return spear},get progress(){return progress},get mode(){return mode},set mode(v){mode=v},get cam(){return cam},get camY(){return camY},tick:dt=>update(dt)};})();`);
 vm.createContext(box);vm.runInContext(js,box);return{t:box.t,els,storage,draws};
}
let count=0;function check(label,f){f();console.log('PASS: '+label);count++}
const DT=1/120,near=(a,b,eps,msg='')=>assert(Math.abs(a-b)<eps,`${msg} ${a} != ${b}`);
function inCourse(n,e=boot()){e.t.startStage(n);assert(e.t.enterCourse(n,null));return e}
function frame(t,dt=DT){t.updateCourse(dt);t.updatePlayer(dt);t.press.jump=false;t.press.dash=false;t.press.drop=false}
function stand(t,x,y){Object.assign(t.p,{x,y,vx:0,vy:0,ground:true,jumps:0,coyote:.1,jumpBuffer:0,dash:0,dashCD:0,hurt:0,dropTime:0,safe:{x,y}})}

// ── 완주 봇: 실제 플레이어 물리로 경로의 다음 발판까지 갈 수 있는 입력을 찾는다(장애물 피해는 끔, 낭떠러지는 실패) ──
function targetOf(t,C,pt){
 if(pt[0]==='m')return{dyn:true,get:()=>{const q=t.run.movers[pt[1]];return{x:q.x,w:C.movers[pt[1]][2],y:q.y}},ok:()=>t.p.mover===pt[1]};
 if(pt[0]==='c')return{get:()=>{const c=C.crumbles[pt[1]];return{x:c[0],w:c[2],y:c[1]}},ok:()=>t.p.crumble===pt[1]};
 if(pt[0]==='b')return{dyn:true,get:()=>{const c=C.blinks[pt[1]];return{x:c[0],w:c[2],y:c[1]}},ok:()=>t.p.blink===pt[1]};
 const [x,y]=pt,all=[...C.blocks.map(b=>[b[0],b[1],b[2]]),...C.ledges,...C.water.map(w=>[w[0],w[1],w[2]])],s=all.find(([sx,sy,sw])=>Math.abs(sy-y)<1&&x>=sx&&x<=sx+sw);
 assert(s,'route point on a surface '+pt);const surf={x:s[0],y:s[1],w:s[2]};return{get:()=>surf,ok:()=>Math.abs(t.p.y-y)<1.5&&t.p.x>=surf.x-1&&t.p.x<=surf.x+surf.w+1,point:x};
}
function snapshot(t){return{p:{...t.p,safe:{...t.p.safe}},run:JSON.parse(JSON.stringify(t.run))}}
function restore(t,s){t.mode='playing';Object.assign(t.p,{...s.p,safe:{...s.p.safe}});const r=t.run;r.t=s.run.t;r.flag=s.run.flag;s.run.crumble.forEach((k,i)=>Object.assign(r.crumble[i],k));s.run.movers.forEach((m,i)=>Object.assign(r.movers[i],m))}
function attempt(t,from,tgt,o){
 restore(t,from);t.p.hp=6;t.p.inv=o.hazards?0:1e9;const keep=()=>{if(!o.hazards)t.p.inv=1e9};
 if(o.startX!==undefined){t.p.x=o.startX;t.p.safe={x:t.p.x,y:t.p.y}}
 for(let i=0;i<Math.round(o.wait/DT);i++){frame(t);keep();if(t.p.hp<6||!t.course)return false}
 let jumped2=false,dashed=false,elapsed=0;if(o.jump)t.press.jump=true;
 for(let i=0;i<Math.round(2.6/DT);i++){
  const g=tgt.get(),aim=tgt.point??g.x+g.w/2,dx=aim-t.p.x;t.keys.right=dx>14&&o.hold;t.keys.left=dx<-14&&o.hold;
  if(o.jump2!==null&&!jumped2&&!t.p.ground&&t.p.vy>=o.jump2){t.press.jump=true;jumped2=true}
  if(o.dash!==null&&!dashed&&elapsed>=o.dash){t.p.dir=dx>=0?1:-1;t.press.dash=true;dashed=true}
  frame(t);elapsed+=DT;keep();
  if(!t.course)return 'finished';if(t.p.hp<6)return false;
  if(elapsed>.05&&t.p.ground&&tgt.ok())return true;
 }
 t.keys.right=t.keys.left=false;return false}
// hazards=true: 철퇴·낙석·가시 피해를 켠 채, 기다리는 타이밍까지 찾아 한 대도 안 맞고 통과해야 한다.
function solveRoute(n,hazards=false){
 const e=inCourse(n),t=e.t,C=t.COURSES[n];t.p.inv=hazards?0:1e9;
 stand(t,C.spawn[0],C.spawn[1]);
 const steps=[...C.route.slice(1),'end'];let deepest=-1,where='';
 // 구간마다 통하는 입력을 쉬운 것부터 하나씩 내놓는다(다음 구간이 막히면 다른 타이밍으로 되돌아가 다시 시도).
 function* options(cur,pt){
  restore(t,cur);
  const tgt=pt==='end'?{get:()=>({x:C.end[0],w:C.end[2],y:C.end[1]+C.end[3]}),ok:()=>false}:targetOf(t,C,pt);
  const statics=t.p.mover<0&&t.p.crumble<0;
  const ledge=[...C.blocks.map(b=>[b[0],b[1],b[2]]),...C.ledges,...C.water.map(w=>[w[0],w[1],w[2]])].find(([sx,sy,sw])=>Math.abs(sy-t.p.y)<1&&t.p.x>=sx-1&&t.p.x<=sx+sw+1);
  const y=t.p.y,spikeFree=x=>!C.spikes.some(([sx,sy,sw])=>Math.abs(sy-y)<1&&x+13>sx&&x-13<sx+sw);
  const starts=statics&&ledge?[cur.p.x,ledge[0]+15,ledge[0]+ledge[2]*.25,ledge[0]+ledge[2]*.5,ledge[0]+ledge[2]*.75,ledge[0]+ledge[2]-15].filter(spikeFree):[undefined];
  const dyn=hazards||tgt.dyn||!statics||C.winds.length,waits=dyn?[0,.25,.5,.75,1,1.25,1.5,1.75,2,2.25,2.5,2.75,3]:[0];
  // 가장 쉬운 입력부터: 회피 없이 → 이단점프 없이 → 기다리지 않고.
  for(const dash of [null,.15,.3,.45])for(const wait of waits)for(const jump2 of [null,-350,-200,-50,100,250])for(const startX of starts)for(const jump of jump2===null?[true,false]:[true]){
   const r=attempt(t,cur,tgt,{wait,startX,jump,jump2,dash,hold:true,hazards});if(r)yield{r,snap:snapshot(t),opt:{pt,wait,startX,jump,jump2,dash}}}
 }
 function solve(k,cur){
  if(k>deepest){deepest=k;where=`(${Math.round(cur.p.x)},${Math.round(cur.p.y)}) -> ${JSON.stringify(steps[k])}`}
  let tries=0;for(const o of options(cur,steps[k])){if(o.r==='finished')return[o.opt];const rest=solve(k+1,o.snap);if(rest)return[o.opt,...rest];if(++tries>=4)break}
  return null}
 const found=solve(0,snapshot(t));assert(found,`stage ${n}${hazards?' (hazards on)':''}: stuck at ${where}`);
 assert.equal(t.course,null,'finished');return{e,found};
}
for(const n of [2,3,4])check(`stage ${n} course is completable with the real physics (route bot), and the end leads to the camp`,()=>{
 const {e,found}=solveRoute(n),t=e.t;assert.equal(t.course,null);t.updatePlayer(0);assert.equal(t.p.x,1430);assert.equal(t.progress.checkpoint,'camp');assert(!t.getState().arena);
 assert(found.some(f=>f.jump2!==null),'needs double jumps somewhere (hard)');
});
check('stage 2 is beatable without taking a single hit: maces, falling rocks and spikes all have a safe timing',()=>{
 const {e,found}=solveRoute(2,true),t=e.t;assert.equal(t.course,null);assert.equal(t.COURSES[2].flags.length,2,'only two save flags');assert(found.filter(f=>f.wait>0).length>=3,'several segments demand waiting for the right moment');
});
check('hard enough: wide gaps and high steps need the double jump, not just one jump',()=>{
 for(const n of [2,3,4]){const C=boot().t.COURSES[n];assert(C.route.length>=15,'long route');assert(C.spikes.length>=3);assert(C.flags.length>=2)}
 const C=boot().t.COURSES;assert(C[2].maces.length>=5&&C[2].vines.length>=3,'stage2 maces and vines');assert(C[3].winds.length>=3&&C[3].crumbles.length>=3,'stage3 wind and crumbling ledges');assert(C[4].drips.length>=5&&C[4].water.length>=3&&C[4].dark>0,'stage4 dark water');
 assert(C[3].end[1]<-5000,'stage3 climbs very high into the sky');assert(C[3].blinks.length>=4&&C[3].crumbles.length>=8&&C[3].winds.length>=6,'stage3 cloud platforms, crumbles, gusts');assert.equal(C[3].flags.length,2)});
check('falling into a pit is instant death even at full HP; retry restarts at the last flag with full HP',()=>{
 const {t}=inCourse(2);stand(t,500,602);frame(t);t.p.hp=6;t.p.inv=5;t.keys.right=true;for(let i=0;i<300&&t.mode==='playing';i++)frame(t);t.keys.right=false;
 assert.equal(t.mode,'dead');assert.equal(t.p.hp,0);t.retry();assert(t.course);assert.deepEqual([t.p.x,t.p.y],t.COURSES[2].spawn);assert.equal(t.p.hp,6)});
check('campfire heals every time you reach it, also after save and quit with low HP',()=>{
 const e=boot(),t=e.t;t.startStage(2);t.p.x=1431;t.updatePlayer(0);assert.equal(t.getState().checkpoint,true);t.p.hp=2;t.p.x=1300;t.goHome();
 const r=boot(e.storage);assert(r.t.continueSaved());assert.equal(r.t.p.hp,2);r.t.keys.right=true;for(let i=0;i<40;i++)r.t.tick(1/60);r.t.keys.right=false;assert.equal(r.t.p.hp,6,'healed at the campfire');
 r.t.p.hp=3;r.t.p.x=1600;r.t.keys.left=true;for(let i=0;i<40;i++)r.t.tick(1/60);r.t.keys.left=false;assert.equal(r.t.p.hp,6,'healed again on the way back')});
check('mace: the swinging ball hits a standing player for 1 with knockback; dash and invulnerability pass',()=>{
 const {t}=inCourse(2),C=t.COURSES[2],m=C.maces[0];stand(t,m[0],602);t.run.t=0;assert(Math.abs(t.maceBall(m,0).x-m[0])<1,'ball at the bottom at t=0');
 t.p.inv=0;t.p.hp=6;t.updatePlayer(0);assert.equal(t.p.hp,5);assert(Math.abs(t.p.vx)>0);
 stand(t,m[0],602);t.p.inv=0;t.p.dash=.1;t.updatePlayer(0);assert.equal(t.p.hp,5);
 const high=t.maceBall(m,C.maces[0][4]/4);assert(high.y<480,'ball rises out of the way '+high.y)});
check('spikes hurt and bounce; landing on spikes never becomes the respawn point',()=>{
 const {t}=inCourse(2),[sx,sy,sw]=t.COURSES[2].spikes[0];stand(t,sx-60,sy);frame(t);const safe=t.p.safe.x;t.p.x=sx+sw/2;t.p.inv=0;t.p.hp=6;t.updatePlayer(0);assert.equal(t.p.hp,5);assert(t.p.vy<0);assert.equal(t.p.safe.x,safe)});
check('dry vines cover a hidden spike strip: vision blocked, spike tips peek out below',()=>{
 const {t,draws}=inCourse(2),C=t.COURSES[2];const v=C.vines.find(([x,y,w])=>C.spikes.some(([sx])=>sx>x&&sx<x+w));assert(v,'a spike under vines');assert(v[1]+v[3]<602-8,'tips visible below the curtain');stand(t,v[0]+v[2]/2,602);t.render()});
check('moving platform carries the player; crumbling ledge falls after .45s and returns after 3s',()=>{
 const {t}=inCourse(2),C=t.COURSES[2];frame(t);const q=t.run.movers[0];stand(t,q.x+45,q.y);t.p.mover=0;frame(t);assert.equal(t.p.mover,0);const x0=t.p.x,m0=q.x;for(let i=0;i<30;i++)frame(t);near(t.p.x-x0,q.x-m0,1,'carried');
 const c=C.crumbles[0];stand(t,c[0]+40,c[1]);t.p.crumble=0;frame(t);for(let i=0;i<Math.round(.42/DT);i++)frame(t);assert.equal(t.run.crumble[0].down,0);for(let i=0;i<6;i++)frame(t);assert(t.run.crumble[0].down>0,'fell');
 for(let i=0;i<20;i++)frame(t);assert(t.p.y>c[1]+5,'player dropped');for(let i=0;i<Math.round(3.1/DT);i++)t.updateCourse(DT);assert.equal(t.run.crumble[0].down,0,'returned')});
check('stage3 wind gusts push only while blowing, after a .6s tell; dash ignores them',()=>{
 const {t}=inCourse(3),C=t.COURSES[3],w=C.winds[0];const on=-w[6]+.1,tell=-w[6]+w[5]-.3,off=-w[6]+w[5]*.75;
 assert.equal(t.windPhase(w,on),'on');assert.equal(t.windPhase(w,tell),'tell');assert.equal(t.windPhase(w,off),'off');
 const l=C.ledges.find(([x,y,ww])=>y-45<w[1]+w[3]&&y>w[1]);assert(l,'a ledge inside the first gust');for(const [time,moved] of [[on,true],[tell,false],[off,false]]){stand(t,l[0]+l[2]/2,l[1]);t.run.t=time;t.p.inv=1e9;const x=t.p.x;t.updatePlayer(.1);moved?near(t.p.x-x,w[4]*.1,.5,'pushed'):near(t.p.x,x,.01,'calm')}
 stand(t,l[0]+l[2]/2,l[1]);t.run.t=on;t.p.dash=.1;const x=t.p.x;t.updatePlayer(.01);assert(Math.abs(t.p.x-x-t.p.dir*8.5)<.01,'dash only')});
check('stage3 camera climbs with the player',()=>{const {t}=inCourse(3);const [hx,hy,hw]=t.COURSES[3].ledges.find(l=>l[1]<-3000);stand(t,hx+hw/2,hy);for(let i=0;i<240;i++){t.p.inv=1e9;t.p.x=hx+hw/2;t.p.y=hy;t.p.vy=0;t.tick(DT)}assert(t.camY<hy+300,'camera up '+t.camY);assert.equal(t.cam,0)});
check('stage4 drips: a forming drop warns at the ceiling, then a falling drop hits for 1',()=>{
 const {t}=inCourse(4),C=t.COURSES[4],d=C.drips[1];const tell=t.dripDrop(d,-d[2]+.3);assert(tell&&!tell.falling);const fall=-d[2]+C.drips[1][1]*0+.6+(560-C.ceil)/800;const q=t.dripDrop(d,fall);assert(q&&q.falling);
 stand(t,d[0],602);t.run.t=fall;t.p.inv=0;t.p.hp=6;t.updatePlayer(0);assert.equal(t.p.hp,5)});
check('stage4 water: slow swim, breath ticks, current in the long channel pushes left; darkness renders',()=>{
 const {t}=inCourse(4),C=t.COURSES[4];stand(t,1650,622);frame(t);assert(t.p.wet);assert(t.getState().course);t.p.inv=1e9;const x=t.p.x;for(let i=0;i<60;i++)frame(t);assert(t.p.x<x-30,'current');
 stand(t,800,622);t.p.hp=6;for(let i=0;i<Math.round(4.2/DT);i++){frame(t);t.p.x=800;t.p.inv=5}assert.equal(t.p.hp,5,'breath tick');t.render()});
check('flags: reaching one saves the course spot (HP is not refilled); death and R respawn there with full HP',()=>{
 const e=boot(),t=e.t;t.startStage(2);t.enterCourse(2,null);const [fx,fy]=t.COURSES[2].flags[0];stand(t,fx,fy);t.p.hp=3;t.updatePlayer(0);
 assert.equal(t.run.flag,0);assert.equal(t.p.hp,3);const saved=JSON.parse(e.storage[PROG]);assert.equal(saved.checkpoint,'course');assert.deepEqual(saved.pos,{x:fx,y:fy});assert.equal(saved.flag,0);assert.equal(saved.hp,3);
 t.p.hp=1;t.p.x=2000;t.p.y=990;t.p.vy=500;t.p.ground=false;for(let i=0;i<30&&t.mode==='playing';i++)frame(t);assert.equal(t.mode,'dead');t.retry();assert(t.course);assert.equal(t.p.x,fx);assert.equal(t.p.hp,6);assert.equal(t.run.flag,0);
 stand(t,3000,602);t.retry();assert.equal(t.p.x,fx)});
check('save and quit inside a course resumes at the same solid spot with the same HP',()=>{
 const e=boot(),t=e.t;t.startStage(2);t.enterCourse(2,null);
 stand(t,1100,602);frame(t);t.p.hp=4;t.p.x=1160;t.p.y=560;t.p.ground=false;t.goHome();assert.equal(t.mode,'title');
 const re=boot(e.storage);assert(re.t.continueSaved());assert(re.t.course);assert.equal(re.t.getState().stage,2);near(re.t.p.x,1100,15,'last solid ground');assert.equal(re.t.p.y,602);assert.equal(re.t.p.hp,4);assert.equal(re.t.run.flag,-1)});
check('save and quit from the course death screen keeps a valid save at the last flag with full HP',()=>{
 const e=boot(),t=e.t;t.startStage(4);t.enterCourse(4,null);t.p.hp=1;t.p.x=2500;t.p.y=990;t.p.vy=600;t.p.ground=false;for(let i=0;i<30&&t.mode==='playing';i++)frame(t);assert.equal(t.mode,'dead');t.goHome();
 const re=boot(e.storage);assert(re.t.continueSaved());assert(re.t.course);assert.equal(re.t.p.hp,6);assert.equal(re.t.p.x,100)});
check('save and quit in the open field keeps the exact spot and HP; during a boss fight it returns to the camp',()=>{
 const e=boot(),t=e.t;t.start();t.finishIntro();stand(t,900,602);t.p.hp=5;t.goHome();const re=boot(e.storage);assert(re.t.continueSaved());assert.equal(re.t.p.x,900);assert.equal(re.t.p.hp,5);assert(!re.t.course);
 re.t.keys.right=true;for(let i=0;i<600&&!re.t.getState().arena;i++)re.t.tick(1/60);re.t.keys.right=false;assert(re.t.getState().arena);re.t.p.hp=2;re.t.goHome();
 const boss=boot(re.storage);boss.t.continueSaved();assert.equal(boss.t.p.x,1430);assert.equal(boss.t.p.hp,6);assert(!boss.t.getState().arena);assert.equal(JSON.parse(re.storage[PROG]).pos,undefined)});
check('save validation: course saves need stage 2-4, a position and sane HP; old saves still load',()=>{
 const {t}=inCourse(2),ok=p=>t.validProgress({version:1,cleared:{1:true,2:false,3:false,4:false},...p});
 assert(ok({stage:2,checkpoint:'course',pos:{x:10,y:602},hp:3,flag:-1}));assert(!ok({stage:1,checkpoint:'course',pos:{x:10,y:602}}));assert(!ok({stage:2,checkpoint:'course'}));assert(!ok({stage:2,checkpoint:'course',pos:{x:10,y:602},hp:0}));assert(!ok({stage:2,checkpoint:'course',pos:{x:10,y:602},hp:7}));assert(!ok({stage:2,checkpoint:'course',pos:{x:'a',y:602}}));
 assert(!t.validProgress({version:1,stage:2,checkpoint:'course',pos:{x:1,y:1},cleared:{1:true,2:true,3:false,4:false}}),'cleared region has no course');
 const old=boot({[PROG]:JSON.stringify({version:1,stage:2,checkpoint:'entry',cleared:{1:true,2:false,3:false}})});assert(old.t.continueSaved());assert(old.t.course,'old entry save starts the new course')});
check('spear: lands on course blocks, and a spear lost in a pit returns to hand',()=>{
 const {t}=inCourse(2);stand(t,200,602);t.p.dir=1;t.p.inv=1e9;assert(t.throwSpear());for(let i=0;i<300&&t.spear&&t.spear.state==='flying';i++)t.updateSpear(.01);assert.equal(t.spear.state,'ground');assert(t.spear.y<602,'rests on the block top');
 stand(t,t.spear.x,602);t.updateSpear(.4);assert.equal(t.spear,null,'picked up');
 stand(t,600,602);assert(t.throwSpear());Object.assign(t.spear,{x:790,y:640,vx:0,vy:0});for(let i=0;i<400&&t.spear;i++)t.updateSpear(.01);assert.equal(t.spear,null,'pit spear returned')});
check('stage3 cloud platforms vanish on a cycle (you fall through), and a long fall is fatal',()=>{
 const {t}=inCourse(3),C=t.COURSES[3],b=C.blinks[0];const tOn=-b[4]+.1,tOff=-b[4]+b[3]*.8;assert.equal(t.blinkPhase(b,tOn),'on');assert.equal(t.blinkPhase(b,-b[4]+b[3]*.6-.2),'warn');assert.equal(t.blinkPhase(b,tOff),'off');
 stand(t,b[0]+b[2]/2,b[1]);t.run.t=tOn;frame(t,0);assert.equal(t.p.blink,0);t.run.t=tOff;t.p.inv=1e9;for(let i=0;i<5;i++)frame(t,.01);assert(t.p.y>b[1]+1,'fell through the vanished cloud');
 const e2=inCourse(3),q=e2.t;stand(q,1262,-200);q.p.ground=false;q.p.peakY=-200;q.p.vy=0;for(let i=0;i<400&&q.mode==='playing';i++)frame(q);assert.equal(q.mode,'dead','fell 800 and died');
 const e3=inCourse(3),r=e3.t;const [lx,ly,lw]=C.ledges[0];stand(r,lx+lw/2,ly);r.p.peakY=ly-200;r.p.ground=false;r.p.vy=10;for(let i=0;i<60&&!r.p.ground;i++)frame(r);assert.equal(r.mode,'playing','a normal jump drop is fine')});
check('debug: course button restarts the current region course without saving',()=>{
 const e=boot(),t=e.t;t.start();t.finishIntro();const saved=e.storage[PROG];t.toggleDebug();t.debugStage(3);assert(!t.course);e.els.debugCourse.onclick();assert(t.course);assert.equal(t.getState().stage,3);t.closeDebug();const [fx,fy]=t.COURSES[3].flags[0];stand(t,fx,fy);t.updatePlayer(0);assert.equal(e.storage[PROG],saved)});
check('courses never show the boss arena or its HUD, and every course renders without exceptions',()=>{
 for(const n of [2,3,4]){const {t,draws}=inCourse(n);for(let i=0;i<30;i++)t.tick(1/30);draws.length=0;t.render();assert(!draws.some(d=>/트리케라톱스|랩터 무리|프테라노돈 ·|스피노사우루스 ·/.test(d.text)));assert(draws.some(d=>d.text.includes(t.COURSES[n].name)))}});
console.log(`All ${count} course checks passed`);
