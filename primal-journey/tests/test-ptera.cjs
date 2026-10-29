const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(__dirname+'/../primal-journey.html','utf8');
const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const PROG='primalJourney.progress.v1',KEYS='primalJourney.keys.v2',REC='primalJourney.records.v2';
function boot(storage={}){
 const gradient={addColorStop(){}},draws=[],events={},els={},writes=[],touch={},paths=[];let currentPath=[];
 const ctx=new Proxy({createLinearGradient:()=>gradient,createRadialGradient:()=>gradient,fillText(text,x,y){draws.push({text:String(text),x,y})},beginPath(){currentPath=[]},moveTo(x,y){currentPath.push([x,y])},lineTo(x,y){currentPath.push([x,y])},fill(){paths.push({color:this.fillStyle,points:currentPath.slice()})}},{get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 const el=id=>els[id]??={hidden:false,getContext:()=>ctx,setAttribute(k,v){this[k]=v},classList:{toggle(){}},addEventListener(){},focus(){}};
 const buttons=[...html.matchAll(/data-key="([^"]+)"/g)].map(m=>({dataset:{key:m[1]},addEventListener(k,f){(touch[m[1]]??={})[k]=f},setPointerCapture(){}}));
 const box={console,Math,localStorage:{getItem:k=>storage[k]||null,setItem(k,v){storage[k]=v;writes.push(k)}},document:{getElementById:el,querySelectorAll:()=>buttons,addEventListener(){}},window:{addEventListener:(k,f)=>events[k]=f},requestAnimationFrame(){},matchMedia:()=>({matches:false})};
 const js=source.replace(/\}\)\(\);\s*$/,`globalThis.t={...window.primalJourney,reset,updateBoss,updatePlayer,updateSpear,throwSpear,pteraContacts,beginMeteorEvent,updateMeteors,advanceMeteors,get meteors(){return meteors},get event(){return meteorEvent},pteraLaserHits,pteraLaserRect,pteraMouth,pteraMouthRect,pteraSpecial,beginPteraDive,bossRect,activePlatforms,assignKey,actionFor,validProgress,victory,damageRaptor,openSettings,closeSettings,pause,saveProgress,recordClear,hud,get p(){return player},get b(){return boss},get spear(){return spear},get keys(){return keys},get press(){return press},get bindings(){return bindings},get progress(){return progress},get records(){return stageRecords},tick:dt=>update(dt)};})();`);
 vm.createContext(box);vm.runInContext(js,box);return{t:box.t,els,events,storage,writes,draws,touch,paths};
}
let count=0;function check(label,f){f();console.log('PASS: '+label);count++}
const near=(a,b)=>assert(Math.abs(a-b)<1e-7,`${a} != ${b}`);
function fresh(){const e=boot();e.t.startStage3();e.t.p.x=1661;e.t.updatePlayer(0);return e}
function phase(e,n){e.t.toggleDebug();e.t.debugPhase(n);e.t.closeDebug()}
function ticks(t,seconds,dt=.01){for(let i=0;i<Math.round(seconds/dt);i++)t.updateBoss(dt)}
check('stage 3 approach dormant, 1100 HP, no raptors, two arena platforms',()=>{
 const e=boot(),t=e.t;t.startStage3();assert.equal(t.getState().stage,3);assert.equal(t.b.hp,1100);assert.equal(t.b.max,1100);assert.equal(t.b.phase,1);assert.equal(t.b.state,'fly');assert.equal(t.getState().raptors.length,0);t.updateBoss(20);assert.equal(t.b.elapsed,0);assert.equal(t.p.x,150);t.p.x=1431;t.updatePlayer(0);assert.equal(t.progress.checkpoint,'camp');t.p.hp=1;t.p.x=1661;t.updatePlayer(0);assert.equal(t.p.hp,6);assert.equal(t.activePlatforms().length,2);assert.deepEqual(Array.from(t.activePlatforms(),p=>[p.x,p.y]),[[1850,440],[2520,440]]);
});
check('exact thresholds 701 / 700 and 401 / 400, robot upgrade, no phase regression',()=>{
 for(const [hp,n]of [[701,1],[700,2],[401,2],[400,3]]){const {t}=fresh();t.b.hp=hp;t.updateBoss(0);assert.equal(t.b.phase,n);assert.equal(t.b.robot,n>=2)}
 const {t}=fresh();for(const [hp,n]of [[701,1],[700,2],[401,2],[400,3],[1100,3]]){t.b.hp=hp;t.updateBoss(0);assert.equal(t.b.phase,n);assert.equal(t.b.robot,n>=2)}
});
check('four-second flight, locked .6 tell, 2s stuck / 7.5s ground / 2s takeoff',()=>{
  const {t}=fresh();t.p.inv=999;t.p.x=1950;ticks(t,3.99);assert.equal(t.b.state,'fly');t.updateBoss(.01);assert.equal(t.b.state,'diveTell');near(t.b.timer,.6);const target=t.b.targetX,ty=t.b.targetY;t.p.x=2650;t.p.y=440;ticks(t,.59);assert.equal(t.b.state,'diveTell');assert.equal(t.b.targetX,target);assert.equal(t.b.targetY,ty);t.updateBoss(.01);assert.equal(t.b.state,'swoop');ticks(t,.5);assert.equal(t.b.state,'stuck');near(t.b.y,602);near(t.b.timer,2);ticks(t,1.99);assert.equal(t.b.state,'stuck');t.updateBoss(.01);assert.equal(t.b.state,'walk');near(t.b.timer,7.5);const x=t.b.x;t.updateBoss(.5);assert(t.b.x>x);ticks(t,6.99);assert.equal(t.b.state,'walk');t.updateBoss(.01);assert.equal(t.b.state,'takeoff');near(t.b.y,602);ticks(t,1);assert(t.b.y>245&&t.b.y<602);ticks(t,1);assert.equal(t.b.state,'fly');near(t.b.timer,4);
});
check('actual natural mouth trajectory swallows idle player at floor and platform height',()=>{
 for(const y of [602,440]){const {t}=fresh();t.p.x=2100;t.p.y=y;t.updateBoss(4);t.updateBoss(.6);for(let i=0;i<90&&t.getState().mode==='playing';i++)t.updateBoss(.008);assert.equal(t.getState().mode,'dead',`mouth must reach y ${y}`);assert.equal(t.p.hp,0)}
});
check('moving away from locked target makes dive miss and leaves vulnerable stuck state',()=>{
  const {t}=fresh();t.p.x=1950;t.updateBoss(4);t.p.x=2700;t.updateBoss(.6);ticks(t,.5);assert.equal(t.b.state,'stuck');assert.equal(t.p.hp,6);assert.equal(t.getState().mode,'playing');
});
for(const immune of ['inv','dash'])check('mouth hit respects '+immune,()=>{
 const {t}=fresh();t.b.state='swoop';t.b.y=500;const m=t.pteraMouth();t.p.x=m.x;t.p.y=m.y+23;t.p[immune]=.1;t.pteraContacts();assert.equal(t.p.hp,6);t.p[immune]=0;t.pteraContacts();assert.equal(t.p.hp,0);assert.equal(t.getState().mode,'dead');
});
check('nonmouth body is never instant kill, even robot phase; tell mouth is not lethal',()=>{
 for(const n of [1,2,3]){const e=fresh(),t=e.t;phase(e,n);t.b.state='swoop';t.b.y=500;t.p.x=t.b.x;t.p.y=450;t.pteraContacts();assert.equal(t.p.hp,5)}const {t}=fresh();t.b.state='diveTell';const m=t.pteraMouth();t.p.x=m.x+10;t.p.y=m.y+23;t.pteraContacts();assert(t.p.hp>0);
});
check('swept mouth does not tunnel at .034 or .1 second update steps',()=>{
 for(const dt of [.034,.1]){const {t}=fresh();t.p.x=2100;t.updateBoss(4);t.updateBoss(.6);for(let i=0;i<30&&t.getState().mode==='playing';i++)t.updateBoss(dt);assert.equal(t.p.hp,0)}
});
check('phase2 cadence uses .75 upward cry, no travel or teleport, then smooth normal flight',()=>{
 const e=fresh(),t=e.t;phase(e,2);t.p.inv=999;t.b.state='walk';t.b.timer=.01;const x=t.b.x,y=t.b.y;t.updateBoss(.01);assert.equal(t.b.state,'meteorRoar');near(t.b.timer,.75);near(t.b.x,x);near(t.b.y,y);assert(t.pteraMouth().y<t.b.y-170);ticks(t,.74);assert.equal(t.b.state,'meteorRoar');t.updateBoss(.01);assert.equal(t.b.state,'takeoff');near(t.b.x,x);near(t.b.y,y);ticks(t,2);assert.equal(t.b.state,'fly');assert(t.event.active);
});
check('meteors honor dash and invulnerability; each rock and impact do only one damage',()=>{
 for(const immunity of ['inv','dash',null]){const {t}=fresh();t.previewStage3(2,'meteor');t.meteors.length=0;t.p.x=2100;t.p.y=602;t.meteors.push({x:2100,y:300,impactY:602,age:.2,warning:.16,fall:.22,impactAt:.38,life:.15,hit:false});if(immunity)t.p[immunity]=1;t.advanceMeteors(.2);assert.equal(t.p.hp,immunity?6:5);if(immunity){t.p[immunity]=0;t.advanceMeteors(.01);assert.equal(t.p.hp,5)}t.p.inv=0;t.advanceMeteors(.01);assert.equal(t.p.hp,5)}
});
check('laser smooth 2s approach, 1s tell, symmetric six-second low-high-low firing',()=>{
  const e=fresh(),t=e.t;phase(e,3);const origins=[];for(let i=0;i<2;i++){t.b.cycle=2;const x=t.b.x,y=t.b.y;t.pteraSpecial();assert.equal(t.b.state,'laserTravel');near(t.b.x,x);near(t.b.y,y);ticks(t,2);assert.equal(t.b.state,'laserTell');near(t.b.timer,1);const m=t.pteraMouth();origins.push(m.x);assert([1897,2388].includes(m.x));assert.equal(t.b.x,i===0?2525:1760);near(t.b.y,602);near(m.y,567);const r=t.pteraLaserRect();assert.equal(r.x,i===0?1535:m.x);assert.equal(r.w,i===0?m.x-1535:2750-m.x);t.p.x=2100;t.p.y=602;assert(!t.pteraLaserHits());t.updateBoss(.99);assert.equal(t.b.state,'laserTell');t.updateBoss(.01);assert.equal(t.b.state,'laser');near(t.b.timer,6);assert(t.pteraLaserHits());t.updateBoss(1.5);const quarter=t.b.laserY;near(quarter,(567+85)/2);t.updateBoss(1.5);near(t.b.laserY,85);t.updateBoss(1.5);near(t.b.laserY,quarter);t.updateBoss(1.49);assert.equal(t.b.state,'laser');assert(t.b.laserY>566);t.updateBoss(.01);assert.equal(t.b.state,'takeoff');near(t.b.y,602);assert(!t.pteraLaserHits())}assert.deepEqual(origins,[2388,1897]);
});
check('laser rectangle clipping, one damage, jump/platform evasion, dash / inv immunity',()=>{
  const e=fresh(),t=e.t;phase(e,3);t.b.cycle=2;t.pteraSpecial();ticks(t,2);t.updateBoss(1);t.p.x=2100;t.p.y=602;t.pteraContacts();assert.equal(t.p.hp,5);t.pteraContacts();assert.equal(t.p.hp,5);t.p.hp=6;t.p.inv=0;for(const y of [440,520,530]){t.p.y=y;assert(!t.pteraLaserHits())}t.p.y=602;for(const immune of ['dash','inv']){t.p[immune]=.2;t.pteraContacts();assert.equal(t.p.hp,6);t.p[immune]=0}t.b.laserY=440;t.b.y=475;t.p.y=440;assert(t.pteraLaserHits(),'beam intersects feet edge of actual rectangle');t.p.y=433;assert(!t.pteraLaserHits());
});
check('laser preview shares live pose, full-size torso remains in arena throughout rise',()=>{
 const e=fresh(),t=e.t;for(const state of ['laserTell','laser']){t.previewStage3(3,state);assert.equal(t.b.x,1760);assert.equal(t.b.y,602);assert.equal(t.pteraMouth().x,1897);assert.equal(t.pteraMouth().y,567);assert.equal(t.bossRect().w,260);assert.equal(t.bossRect().h,145)}
 for(const side of [-1,1]){t.b.laserSide=-side;t.b.cycle=2;t.pteraSpecial();ticks(t,2);t.updateBoss(1);for(let i=0;i<60;i++){assert(t.b.x-194>1535);assert(t.b.x+194<2750);assert(t.b.y-100>=20,'tucked crest and wings stay below top boundary');assert(t.b.y<=602);near(t.pteraMouth().y,t.b.laserY);const m=t.pteraMouth(),r=t.pteraLaserRect();assert.equal(t.b.dir>0?r.x:r.x+r.w,m.x);assert.equal(t.b.dir>0?r.x+r.w:r.x,t.b.dir>0?2750:1535);t.render();t.updateBoss(.1)}}
});
check('phase3 naturally interleaves repeated dives, meteor cries and lasers without starvation',()=>{
 const e=fresh(),t=e.t;phase(e,3);t.p.inv=999;const states=new Set(),starts={diveTell:0,meteorRoar:0,laserTell:0};let previous=t.b.state;for(let i=0;i<16000;i++){t.updateBoss(.01);states.add(t.b.state);if(t.b.state!==previous&&t.b.state in starts)starts[t.b.state]++;previous=t.b.state}assert(starts.diveTell>=6);assert(starts.meteorRoar>=3);assert(starts.laserTell>=3);for(const s of ['fly','swoop','stuck','walk','takeoff','laserTravel','meteorRoar','laser'])assert(states.has(s));
});
check('WASD defaults, explicit custom retained, untouched Space default migrated and saved',()=>{
 const old={left:'KeyA',right:'KeyD',jump:'Space',attack:'KeyJ',dash:'ShiftLeft',retry:'KeyR',throw:'KeyF'};
 assert.equal(boot().t.bindings.jump,'KeyW');assert.equal(boot().t.bindings.drop,'KeyS');const a=boot({[KEYS]:JSON.stringify(old)});assert.equal(a.t.bindings.jump,'KeyW');assert.equal(JSON.parse(a.storage[KEYS]).jump,'KeyW');
 const custom={...old,left:'KeyS',attack:'KeyW'};const b=boot({[KEYS]:JSON.stringify(custom)});for(const k of Object.keys(custom))assert.equal(b.t.bindings[k],custom[k]);assert.equal(b.t.bindings.drop,'ArrowDown');assert.equal(new Set(Object.values(b.t.bindings)).size,8);
 const explicit=boot({[KEYS]:JSON.stringify({...old,drop:'KeyX'})});assert.equal(explicit.t.bindings.jump,'Space');assert.equal(explicit.t.bindings.drop,'KeyX');assert(explicit.t.assignKey('drop','KeyS'));assert.equal(explicit.t.actionFor('KeyS'),'drop');
});
check('keyboard W jump, A/D movement, S drop and touch-down event wiring',()=>{
 const e=fresh(),t=e.t;const key=code=>e.events.keydown({code,preventDefault(){}});t.p.x=2100;key('KeyD');t.updatePlayer(.1);assert(t.p.x>2100);e.events.keyup({code:'KeyD'});key('KeyA');t.updatePlayer(.1);assert(t.p.vx<0);e.events.keyup({code:'KeyA'});key('KeyW');t.updatePlayer(.01);assert.equal(t.p.jumps,1);assert(t.p.vy<0);t.p.x=1900;t.p.y=440;t.p.ground=true;t.p.vy=0;t.press.jump=false;key('KeyS');t.updatePlayer(.01);assert(t.p.y>440);assert(t.p.dropTime>0);t.press.drop=false;t.p.y=440;t.p.ground=true;e.touch.drop.pointerdown({preventDefault(){},pointerId:1});assert(t.press.drop&&t.keys.drop);e.touch.drop.pointerup();assert(!t.keys.drop);
});
check('crowded custom bindings never reset when all preferred drop candidates are occupied',()=>{
 const custom={left:'KeyS',right:'ArrowDown',jump:'KeyX',attack:'KeyC',dash:'KeyZ',retry:'KeyQ',throw:'KeyF'},e=boot({[KEYS]:JSON.stringify(custom)});for(const k of Object.keys(custom))assert.equal(e.t.bindings[k],custom[k]);assert.equal(e.t.bindings.drop,'KeyE');const noThrow={left:'KeyA',right:'KeyD',jump:'Space',attack:'KeyJ',dash:'ShiftLeft',retry:'KeyR'},a=boot({[KEYS]:JSON.stringify(noThrow)});assert.equal(a.t.bindings.jump,'KeyW');assert.equal(a.t.bindings.throw,'KeyL');assert.equal(a.t.bindings.drop,'KeyS');assert.equal(a.t.bindings.dash,'KeyK');
});
check('JKL defaults, prior WASD defaults migrate, reset uses JKL and custom retained',()=>{const base={left:'KeyA',right:'KeyD',jump:'KeyW',drop:'KeyS',attack:'KeyJ',dash:'ShiftLeft',retry:'KeyR',throw:'KeyF'},e=boot({[KEYS]:JSON.stringify(base)});assert.equal(e.t.bindings.attack,'KeyJ');assert.equal(e.t.bindings.dash,'KeyK');assert.equal(e.t.bindings.throw,'KeyL');assert.equal(JSON.parse(e.storage[KEYS]).dash,'KeyK');const c=boot({[KEYS]:JSON.stringify({...base,dash:'KeyV'})});assert.equal(c.t.bindings.dash,'KeyV');assert.equal(c.t.bindings.throw,'KeyF');const f=boot();assert.equal(f.t.actionFor('KeyJ'),'attack');assert.equal(f.t.actionFor('KeyK'),'dash');assert.equal(f.t.actionFor('KeyL'),'throw')});
check('natural dives reach idle players at both arena boundaries in every phase',()=>{
 for(const n of [1,2,3])for(const x of [1535,2750]){const e=fresh(),t=e.t;phase(e,n);t.p.x=x;t.updateBoss(4);t.updateBoss(.6);for(let i=0;i<100&&t.getState().mode==='playing';i++)t.updateBoss(.008);assert.equal(t.p.hp,0,`phase ${n} edge ${x}`)}
});
check('both 162-high arena platforms reachable by actual double jump, third jump denied',()=>{
 for(const x of [1945,2615]){const {t}=fresh();t.p.x=x;t.p.inv=999;t.press.jump=true;t.updatePlayer(.001);t.press.jump=false;for(let i=0;i<33;i++)t.updatePlayer(.01);t.press.jump=true;t.updatePlayer(.001);assert.equal(t.p.jumps,2);t.press.jump=false;t.updatePlayer(.01);t.press.jump=true;t.updatePlayer(.001);assert.equal(t.p.jumps,2);t.press.jump=false;let landed=false;for(let i=0;i<130;i++){t.updatePlayer(.01);if(t.p.ground&&t.p.y===440){landed=true;break}}assert(landed,`double jump landing x ${x}`);assert.equal(t.p.jumps,0)}
});
check('drop through platform keeps floor solid; stage1/2 arena platforms remain absent',()=>{
 const {t}=fresh();t.p.x=1945;t.p.y=440;t.p.ground=true;t.press.drop=true;t.updatePlayer(.01);t.press.drop=false;for(let i=0;i<200;i++)t.updatePlayer(.01);assert.equal(t.p.y,602);assert(t.p.ground);t.press.drop=true;t.updatePlayer(.01);assert.equal(t.p.y,602);for(const stage of [1,2]){t.startStage(stage);t.reset(true);assert.equal(t.activePlatforms().length,0)}
});
check('melee 10 once per swing against stuck ptera and spear 60 airborne once',()=>{
 const {t}=fresh();t.b.state='stuck';t.b.y=602;t.b.x=2200;t.p.x=2000;t.p.dir=1;t.keys.attack=true;t.updatePlayer(.01);assert.equal(t.b.hp,1090);t.keys.attack=false;t.updatePlayer(.01);assert.equal(t.b.hp,1090);t.reset(true);assert.equal(t.b.hp,1100);assert.equal(t.b.max,1100);t.b.x=2200;t.b.y=400;t.p.x=2000;t.p.y=440;t.p.dir=1;assert(t.throwSpear());for(let i=0;i<40;i++)t.updateSpear(.01);assert.equal(t.b.hp,1040);t.updateSpear(.1);assert.equal(t.b.hp,1040);t.keys.attack=true;t.p.atkCD=0;t.updatePlayer(.01);assert.equal(t.p.atk,0);
});
check('spear lands on either arena platform and can be recovered from that platform',()=>{
 for(const x of [1945,2615]){const {t}=fresh();t.p.x=x;t.p.y=350;t.throwSpear();Object.assign(t.spear,{x,y:410,vx:0,vy:100});t.p.x=2100;for(let i=0;i<100&&t.spear.state!=='ground';i++)t.updateSpear(.01);assert.equal(t.spear.state,'ground');assert.equal(t.spear.y,433);t.updateSpear(.35);t.p.x=x;t.p.y=440;t.updateSpear(.01);assert.equal(t.spear,null)}
});
check('no third records before clear; stars, isolation, single clear and reload',()=>{
 const e=fresh(),t=e.t;assert.equal(t.records[3].clears,0);assert(e.els.skyRecords.innerHTML.includes('???'));assert(!e.els.skyRecords.innerHTML.includes('절벽'));t.p.hp=4;t.b.hp=0;t.victory();assert.equal(t.records[3].clears,1);assert.equal(t.records[3].bestStars,3);assert.equal(t.records[1].clears,0);assert.equal(t.records[2].clears,0);t.victory();assert.equal(t.records[3].clears,1);assert(e.els.skyRecords.innerHTML.includes('바람의 하늘 절벽'));t.updateBoss(2.4);assert.equal(t.getState().mode,'won');assert.equal(e.els.winName.textContent,'날개 너머의 고요');const re=boot(e.storage);assert.equal(re.t.records[3].clears,1);assert.equal(re.t.records[3].bestStars,3);re.t.continueSaved();assert(re.t.b.dead);assert.equal(re.t.b.hp,0);assert.equal(re.t.getState().stage,3);
});
check('legacy records v1/v2 preserved independently and stage3 persists into v2',()=>{
 const record={clears:2,bestStars:4,bestTime:42,recent:[{at:Date.now(),hp:5,stars:4,seconds:42}]},legacy=JSON.stringify(record),e=boot({'primalJourney.records.v1':legacy,[REC]:JSON.stringify({stages:{2:record}})}),t=e.t;assert.equal(t.records[1].clears,2);assert.equal(t.records[2].clears,2);assert.equal(t.records[3].clears,0);t.startStage3();t.reset(true);t.victory();assert.equal(e.storage['primalJourney.records.v1'],legacy);const saved=JSON.parse(e.storage[REC]);assert.equal(saved.stages[2].clears,2);assert.equal(saved.stages[3].clears,1);
});
check('legacy stage2 ending migrates to passage, traverses into3, camp save restores fresh fight',()=>{
 const save={version:1,stage:2,checkpoint:'ending',cleared:{1:true,2:true}},e=boot({[PROG]:JSON.stringify(save)}),t=e.t;t.continueSaved();assert.equal(t.progress.checkpoint,'passage');assert.equal(t.progress.cleared[3],false);assert.equal(t.p.x,2920);t.p.x=3610;t.updatePlayer(0);assert.equal(t.getState().stage,3);assert.equal(t.getState().course.stage,3,'cliff climb first');assert.equal(t.p.x,150);assert(!t.getState().arena);t.p.x=550;t.p.y=-5490;t.updatePlayer(0);assert.equal(t.getState().course,null,'summit reached');t.updatePlayer(0);assert.equal(t.progress.checkpoint,'camp');const re=boot({...e.storage});re.t.continueSaved();assert.equal(re.t.p.x,1430);assert.equal(re.t.b.hp,1100);assert.equal(re.t.b.max,1100);assert(!re.t.getState().arena);assert.equal(re.t.b.elapsed,0);
});
check('invalid stage3 unlock chains, checkpoints and malformed cleared3 rejected',()=>{
 for(const p of [{stage:3,checkpoint:'entry',cleared:{1:true,2:false,3:false}},{stage:3,checkpoint:'ending',cleared:{1:true,2:true,3:false}},{stage:2,checkpoint:'entry',cleared:{1:true,2:false,3:true}},{stage:4,checkpoint:'passage',cleared:{1:true,2:true,3:true,4:true}},{stage:4,checkpoint:'entry',cleared:{1:true,2:true,3:false,4:false}},{stage:3,checkpoint:'entry',cleared:{1:true,2:true,3:false,4:true}},{stage:3,checkpoint:'entry',cleared:{1:true,2:true,3:'false'}}]){const e=boot({[PROG]:JSON.stringify({version:1,...p})});assert.equal(e.t.progress,null);assert.equal(e.t.continueSaved(),false)}
});
check('stage3 clear now opens the passage to stage4; old stage3 ending saves migrate to that passage',()=>{
 const e=fresh(),t=e.t;t.victory();t.updateBoss(2.4);t.continueJourney();t.p.x=2900;t.updatePlayer(0);assert.equal(t.progress.checkpoint,'passage');assert.equal(t.getState().stage,3);t.p.x=3610;t.updatePlayer(0);assert.equal(t.getState().stage,4);assert.equal(t.getState().course.stage,4,'dark water course first');assert.equal(t.p.x,100);assert.equal(t.progress.stage,4);assert.equal(t.progress.checkpoint,'entry');assert.equal(t.records[3].clears,1);
 const old={version:1,stage:3,checkpoint:'ending',cleared:{1:true,2:true,3:true}},o=boot({[PROG]:JSON.stringify(old)});assert(o.t.continueSaved());assert.equal(o.t.progress.checkpoint,'passage');assert.equal(o.t.progress.cleared[4],false);assert.equal(o.t.p.x,2920);
});
check('third-boss debug phases 1100/700/400 and retry reset all new pattern state',()=>{
 const e=fresh(),t=e.t;for(const n of [3,1,2,3]){t.b.targetX=999;t.b.laserY=99;t.p.dropTime=.2;t.throwSpear();phase(e,n);assert.equal(t.b.hp,[0,1100,700,400][n]);assert.equal(t.b.max,1100);assert.equal(t.b.phase,n);assert.equal(t.b.robot,n>=2);assert.equal(t.b.state,'fly');assert.equal(t.b.timer,4);assert.equal(t.b.targetX,0);assert.equal(t.b.cycle,0);assert.equal(t.p.dropTime,0);assert.equal(t.spear,null);t.updateBoss(.01);assert.equal(t.b.phase,n)}t.retry();assert.equal(t.b.hp,1100);assert.equal(t.b.max,1100);assert.equal(t.b.phase,1);assert.equal(t.b.timer,4);assert(!t.b.robot);assert(t.getState().debugJourney);
});
check('natural full multi-cycle trajectories obey per-step velocity bounds in every phase at 120Hz',()=>{
 const dt=1/120;
 for(const n of [1,2,3]){const e=fresh(),t=e.t;phase(e,n);t.p.inv=999;let previous=t.b.state,ground=0,walks=0;const transitions=new Set();
  for(let i=0;i<240*120;i++){t.p.x=i%(32*120)<16*120?1535:2750;t.p.y=i%(24*120)<12*120?602:440;
   const x=t.b.x,y=t.b.y,state=t.b.state,dir=t.b.dir,m=t.pteraMouth();t.updateBoss(dt);t.pteraContacts();
     // Piecewise linear dive speed is distance / phase time; a lunge tops out at 150/.20.
     const diveSpeed=Math.max(Math.hypot(t.b.endX-t.b.startX,t.b.targetY-(t.b.startY-67))/(.5*.72),Math.hypot(90,535-t.b.targetY)/(.5*.28));
     const distance=Math.hypot(t.b.x-x,t.b.y-y),speed=state==='swoop'?diveSpeed:['perchTravel','laserTravel','takeoff'].includes(state)?1100:state==='walk'?750:state==='fly'?350:state==='laser'?260:0;
   assert(distance<=speed*dt+1e-6,`phase ${n} ${state}->${t.b.state} distance ${distance}, bound ${speed*dt}`);
   if(state==='walk')ground+=dt;
   if(t.b.state!==previous){transitions.add(previous+'>'+t.b.state);if(previous==='walk'){assert(ground>=7.5-dt-1e-6,`ground lasted ${ground}`);ground=0;walks++}previous=t.b.state}
   if(state==='laser'){const r=t.pteraLaserRect(),mouth=t.pteraMouth();near(r.y+6,mouth.y);near(t.b.laserY,mouth.y);assert(Math.hypot(mouth.x-m.x,mouth.y-m.y)<=260*dt+1e-6);assert.equal(t.b.dir,dir)}
  }
  assert(walks>=8);for(const edge of ['fly>diveTell','diveTell>swoop','swoop>stuck','stuck>walk','takeoff>fly'])assert(transitions.has(edge),edge);
  if(n===1)assert(transitions.has('walk>takeoff'));
   if(n>=2)for(const edge of ['walk>meteorRoar','meteorRoar>takeoff'])assert(transitions.has(edge),edge);
  if(n===3)for(const edge of ['walk>laserTravel','laserTravel>laserTell','laserTell>laser','laser>takeoff'])assert(transitions.has(edge),edge);
  assert.equal(t.p.hp,6);
 }
});
check('ground beak locks .45 tell, .20 normal-damage lunge, .7 recovery and 2s cadence',()=>{
 const {t}=fresh();t.previewStage3(1,'walk');t.b.x=2100;t.p.x=2300;t.p.y=602;
 ticks(t,.44);near(t.b.x,2100);near(t.b.lungeTarget,2300);assert.equal(t.p.hp,6);
  t.p.x=1900;t.updateBoss(.01);near(t.b.lungeTarget,2300);assert.equal(t.b.dir,1);ticks(t,.20);assert.equal(t.p.hp,6,'locked aim can be dodged');assert(t.b.x>2100);
  const x=t.b.x;t.updateBoss(.1);near(x-t.b.x,22);ticks(t,1.25);near(t.b.lungeClock,0);t.p.x=1800;t.updateBoss(.01);near(t.b.lungeTarget,1800);assert.equal(t.b.dir,-1);
  const a=fresh().t;a.previewStage3(1,'walk');a.b.x=2100;a.p.x=2300;a.p.y=602;ticks(a,.55);assert.equal(a.p.hp,5);a.p.inv=0;ticks(a,.09);assert.equal(a.p.hp,5,'one hit per lunge even if invulnerability cleared');assert.equal(a.getState().mode,'playing');
});
check('measured walking is 220 and locked lunges reach 150 in exactly .20 seconds both ways',()=>{
 for(const dir of [-1,1]){const {t}=fresh();t.previewStage3(1,'walk');t.p.inv=999;t.b.x=2100;t.p.x=2100+dir*500;ticks(t,.45);near(t.b.x,2100);near(t.b.lungeEnd,2100+dir*150);t.p.x=2100-dir*500;
  ticks(t,.1);near(t.b.x,2100+dir*75);assert.equal(t.b.dir,dir);ticks(t,.09);near(t.b.x,2100+dir*142.5);t.updateBoss(.01);near(t.b.x,2100+dir*150);near(t.b.lungeClock,.65);
  const x=t.b.x;ticks(t,.5);near((x-t.b.x)*dir/.5,220);near(t.b.lungeClock,1.15);ticks(t,.2);near(t.b.lungeClock,1.35);ticks(t,.65);near(t.b.lungeClock,0);
 }
});
check('natural and preview swoops last .50 seconds and preserve the .72 trajectory breakpoint',()=>{
 for(const preview of [false,true]){const {t}=fresh();t.p.inv=999;t.p.x=2100;t.p.y=440;if(preview)t.previewStage3(1,'swoop');else{t.updateBoss(4);t.updateBoss(.6)}t.p.inv=999;near(t.b.timer,.5);
  ticks(t,.36);assert.equal(t.b.state,'swoop');near(t.b.diveProgress,.72);near(t.b.x,t.b.endX);near(t.pteraMouth().y,t.b.targetY);
  ticks(t,.13);assert.equal(t.b.state,'swoop');near(t.b.timer,.01);t.updateBoss(.01);assert.equal(t.b.state,'stuck');near(t.b.x,t.b.endX+t.b.dir*90);near(t.b.y,602);near(t.b.timer,2);
 }
});
check('meteor roar renders upward rings without any forward cone',()=>{
 for(const dir of [-1,1]){const e=fresh(),t=e.t;t.previewStage3(2,'meteor');t.b.dir=dir;e.paths.length=0;t.render();assert(t.pteraMouth().y<t.b.y-170);assert(!e.paths.some(p=>p.color==='#a5edff'))}
});
check('travel preserves coordinates, remains spear-vulnerable, and never inflicts incidental body damage',()=>{
 for(const state of ['takeoff','laserTravel']){const {t}=fresh();t.previewStage3(3,state);const x=t.b.x,y=t.b.y;t.p.x=x;t.p.y=y-30;t.pteraContacts();assert.equal(t.p.hp,6);t.p.x=x-200;t.p.y=y;t.p.dir=1;assert(t.throwSpear());for(let i=0;i<40;i++)t.updateSpear(.01);assert.equal(t.b.hp,340);near(t.b.x,x);near(t.b.y,y)}
});
check('all transition preview states initialize and reset travel, lunge and beam clocks',()=>{
 const {t}=fresh();for(const s of ['takeoff','meteorRoar','laserTravel','walk','laser']){assert(t.previewStage3(3,s));assert.equal(t.b.state,s);near(t.b.stateTime,0);near(t.b.groundTime,0);near(t.b.lungeClock,0);near(t.b.laserTime,0);assert(!t.b.lungeHit);t.p.inv=999;ticks(t,.3);t.render()}
 t.retry();for(const key of ['stateTime','groundTime','lungeClock','laserTime','travelDuration','targetX','targetY'])near(t.b[key],0);near(t.b.jawOffset,67);assert.equal(t.b.state,'fly');
});
check('preview hooks callable from parent, taint snapshot preserved, no records or saves',()=>{
 const e=boot(),t=e.t;t.start();t.finishIntro();const before=JSON.stringify(t.progress),storage=JSON.stringify(e.storage),writes=e.writes.length;assert.equal(t.previewStage3(0),false);for(const [n,s]of [[1,'fly'],[1,'diveTell'],[1,'swoop'],[1,'stuck'],[2,'meteor'],[2,'ultraTell'],[2,'ultra'],[3,'laserTell'],[3,'laser']]){assert(t.previewStage3(n,s));assert.equal(t.b.phase,n);assert.equal(t.b.state,['meteor','ultraTell','ultra'].includes(s)?'meteorRoar':s);assert.equal(t.getState().mode,'playing');assert(t.getState().debugJourney)}t.victory();t.recordClear();t.saveProgress();assert.equal(t.records[3].clears,0);assert.equal(e.writes.length,writes);assert.equal(JSON.stringify(e.storage),storage);t.goHome();assert.equal(JSON.stringify(t.progress),before);assert(!t.getState().debugJourney);
});
check('pause/settings/debug freeze new clocks and all stage3 render states execute without exceptions',()=>{
 const e=fresh(),t=e.t;for(const open of [()=>t.pause(),()=>t.openSettings(),()=>t.toggleDebug()]){open();const b=JSON.stringify(t.b);t.tick(5);assert.equal(JSON.stringify(t.b),b);if(t.getState().mode==='paused')t.pause();else if(t.getState().mode==='settings')t.closeSettings();else t.closeDebug()}for(const n of [1,2,3])for(const s of ['fly','diveTell','swoop','stuck','walk','takeoff','laserTravel','laserTell','laser',...(n>=2?['meteor','ultra']:[])])assert(t.previewStage3(n,s));e.draws.length=0;t.hud();assert(!e.draws.filter(d=>d.y<100).some(d=>/900|580|250|1100|700|400/.test(d.text)));
});
check('airborne hunt reverses after the player changes sides, with bounded acceleration and bank',()=>{
 const {t}=fresh(),dt=1/120;t.p.inv=999;t.p.x=1650;t.p.vx=-290;
 let path=0,flips=0,lastFlip=-999,negative=false,positive=false,slow=0;
 for(let i=0;i<479;i++){
  if(i===180){t.p.x=2730;t.p.vx=290}
  const x=t.b.x,y=t.b.y,vx=t.b.vx,vy=t.b.vy,dir=t.b.dir;t.updateBoss(dt);
  assert.equal(t.b.state,'fly');assert(Math.abs(t.b.vx-vx)<=520*dt+1e-6);assert(Math.abs(t.b.vy-vy)<=240*dt+1e-6);
  assert(Math.abs(t.b.vx)<=330);assert(Math.abs(t.b.bank)<=.13);assert(t.b.y>=215&&t.b.y<=330);assert(t.b.x>=1745&&t.b.x<=2540);
  path+=Math.hypot(t.b.x-x,t.b.y-y);if(Math.abs(t.b.vx)<35)slow+=dt;
  if(i<180&&t.b.vx<-180)negative=true;if(i>300&&t.b.vx>180)positive=true;
  if(dir!==t.b.dir){assert(i-lastFlip>60);lastFlip=i;flips++}t.render();
 }
 assert(negative&&positive,'must actually pursue both sides during the same airborne cycle');assert(path>620);assert(slow<.9);assert(flips<=3);
});
check('live 290-speed moving prey changes hunt aim during flight without restarting the clock',()=>{
 const {t}=fresh();t.p.inv=999;t.p.x=1850;t.p.y=602;let left=false,right=false,firstAim,lastAim;
 for(let i=0;i<479;i++){const dt=1/120;t.p.vx=i<215?290:-290;t.p.x+=t.p.vx*dt;t.updateBoss(dt);assert.equal(t.b.state,'fly');if(i===100)firstAim=t.b.aimX;if(i===210)lastAim=t.b.aimX;if(t.b.vx>160)right=true;if(right&&i>350&&t.b.vx<-160)left=true;assert(Math.abs(t.b.timer-(4-(i+1)*dt))<1e-7)}
 assert(lastAim>firstAim+100);assert(left&&right,'actual player movement must induce both chase directions');
});
check('idle prey is swept overhead rather than parked on for the entire four seconds',()=>{
 const {t}=fresh();t.p.x=2100;t.p.vx=0;let path=0,segment=0,min=t.b.x,max=t.b.x;const bins=[];
 for(let i=0;i<480;i++){const x=t.b.x;t.updateBoss(1/120);const distance=Math.abs(t.b.x-x);path+=distance;segment+=distance;min=Math.min(min,t.b.x);max=Math.max(max,t.b.x);if(i%120===119){bins.push(segment);segment=0}}
 assert(path>650);assert(max-min>350);assert(bins.every(d=>d>25));assert.equal(t.b.state,'diveTell');
});
check('platform-aware hunt height changes smoothly and takeoff aims at the current player',()=>{
 const {t}=fresh();t.p.inv=999;t.p.x=1900;t.p.y=602;t.p.vx=0;ticks(t,1);const floorY=t.b.y;t.p.y=440;ticks(t,1.8);assert(t.b.y<floorY-40);assert(t.b.y>=215);
 const endpoints=[];for(const x of [1600,2700]){t.previewStage3(1,'walk');t.b.x=2150;t.p.x=x;t.p.y=440;t.p.inv=999;t.b.timer=.01;const before={x:t.b.x,y:t.b.y};t.updateBoss(.01);assert.equal(t.b.state,'takeoff');near(t.b.x,before.x);near(t.b.y,before.y);endpoints.push(t.b.endX);assert(t.b.endY<260);ticks(t,2);assert.equal(t.b.state,'fly');near(t.b.x,t.b.endX);near(t.b.y,t.b.endY);const oldX=t.b.x,oldY=t.b.y;t.updateBoss(1/120);assert(Math.hypot(t.b.x-oldX,t.b.y-oldY)<1)}
 assert(endpoints[1]-endpoints[0]>600);
});
check('flight art uses articulated curves, altitude shadow and exact transformed mouth anchor; title stays hidden',()=>{
 assert(html.includes('Math.sin(time*7.6-.6)'));assert(html.includes('FLOOR+3,110+altitude*100'));assert(html.includes('g.scale(1.18,1.18)'));
 const {t}=fresh();t.p.inv=999;ticks(t,.7);const b=t.b,m=t.pteraMouth(),a=b.bank,x=b.face*137,y=68-b.jawOffset;near(m.x,b.x+x*Math.cos(a)-y*Math.sin(a));near(m.y,b.y-68+x*Math.sin(a)+y*Math.cos(a));
 assert(html.includes("if(mode==='title'||mode==='records'||mode==='settings'&&settingsReturn==='title'){drawTitle();return}"));
});
check('exactly30 in10s, 18 predictive / 12 coverage, deterministic lanes on both platforms',()=>{
 const results=[];
 for(const dt of [.01,.034,.1]){const {t}=fresh();t.previewStage3(2,'meteor');t.p.inv=999;t.p.x=2100;t.p.vx=290;const lanes=new Map();const capture=()=>t.meteors.forEach(m=>lanes.set(m.id,{x:m.x,y:m.impactY,targeted:m.targeted}));capture();let elapsed=0;while(elapsed<10-1e-9){const h=Math.min(dt,10-elapsed);t.updateMeteors(h);capture();elapsed+=h}assert.equal(t.event.spawned,30);assert.equal(t.event.targeted,18);assert.equal(t.event.coverage,12);near(t.event.elapsed,10);assert(!t.event.active);assert(!t.beginMeteorEvent(),'last rock still resolves, never erase it');t.updateMeteors(.3);assert.equal(t.meteors.length,0);assert.equal(lanes.size,30);const coverage=[...lanes.values()].filter(m=>!m.targeted);assert(coverage.some(m=>m.x>=1850&&m.x<=2040&&m.y===440));assert(coverage.some(m=>m.x>=2520&&m.x<=2710&&m.y===440));assert(new Set([...lanes.values()].map(m=>m.x)).size>=18);assert(Math.max(...coverage.map(m=>m.x))-Math.min(...coverage.map(m=>m.x))>1000);results.push(JSON.stringify([...lanes]))}assert.equal(results[0],results[1]);assert.equal(results[1],results[2]);
});
check('scheduler boundaries spawn at0 then1/3, never31 and never reset or extend while active',()=>{
 const {t}=fresh();t.previewStage3(2,'meteor');t.p.inv=999;assert.equal(t.event.spawned,1);t.updateMeteors(.332);assert.equal(t.event.spawned,1);t.updateMeteors(.002);assert.equal(t.event.spawned,2);const e=t.event,m=t.meteors[0],elapsed=e.elapsed;t.b.cycle=1;t.pteraSpecial();assert.equal(t.event,e);assert.equal(t.event.elapsed,elapsed);assert.equal(t.meteors[0],m);assert.equal(t.b.state,'takeoff');t.updateMeteors(9.666);assert.equal(e.spawned,30);assert(!e.active);t.updateMeteors(3);assert.equal(e.spawned,30);assert(t.beginMeteorEvent());assert.notEqual(t.event,e);assert.equal(t.event.spawned,0);
});
check('meteor swept falling collision hits airborne player and platform top before floor',()=>{
 for(const [x,y]of [[1945,440],[2615,440],[2200,300]]){const {t}=fresh();t.previewStage3(2,'meteor');t.meteors.length=0;t.p.x=x;t.p.y=y;t.meteors.push({x,y:-40,impactY:x===2200?602:440,age:0,warning:.16,fall:.22,impactAt:.38,life:.15,hit:false});t.advanceMeteors(.5);assert.equal(t.p.hp,5,`sweep hits ${x},${y}`)}
 const {t}=fresh();t.previewStage3(2,'meteor');t.meteors.length=0;t.p.x=1945;t.p.y=602;t.meteors.push({x:1945,y:-40,impactY:440,age:0,warning:.16,fall:.22,impactAt:.38,life:.15,hit:false});t.advanceMeteors(.5);assert.equal(t.p.hp,6,'solid platform catches rock');
});
check('40-radius impact AoE lasts .15s, one damage, not full-height floor damage',()=>{
 for(const [dx,hit]of [[52,true],[54,false]]){const {t}=fresh();t.previewStage3(2,'meteor');t.meteors.length=0;t.p.x=2100+dx;t.p.y=440;t.meteors.push({x:2100,y:440,impactY:440,age:.4,warning:.16,fall:.22,impactAt:.38,life:.15,hit:false});t.advanceMeteors(.01);assert.equal(t.p.hp,hit?5:6);t.p.inv=0;t.advanceMeteors(.01);assert.equal(t.p.hp,hit?5:6);t.advanceMeteors(.12);assert.equal(t.meteors.length,0)}
});
check('boss immunity and normal takeoff pursuit dive stuck ground continue during full meteor event',()=>{
 const {t}=fresh();t.previewStage3(3,'meteor');t.p.inv=999;let path=0;const states=new Set();for(let i=0;i<1000;i++){const x=t.b.x,y=t.b.y;t.updateBoss(.01);states.add(t.b.state);path+=Math.hypot(t.b.x-x,t.b.y-y)}for(const s of ['meteorRoar','takeoff','fly','diveTell','swoop','stuck','walk'])assert(states.has(s),s);assert(path>600);assert.equal(t.b.hp,400);assert.equal(t.event.spawned,30);
 // Independent scheduling also runs throughout a live laser, without stealing its clock.
 t.previewStage3(3,'laser');assert(t.beginMeteorEvent());t.p.inv=999;ticks(t,5);assert.equal(t.b.state,'laser');near(t.b.laserTime,5);assert.equal(t.event.spawned,16);assert.equal(t.b.hp,400);assert(t.meteors.length>0);
});
check('natural phase3 cadence starts meteors only in old special slot, not phase1',()=>{
 for(const n of [1,2,3]){const e=fresh(),t=e.t;phase(e,n);t.p.inv=999;ticks(t,14.59);assert.equal(t.event,null);t.updateBoss(.01);assert.equal(t.b.state,n===1?'takeoff':'meteorRoar');assert.equal(!!t.event,n>=2)}
});
check('reset retry debug every phase region home and victory clear all pending meteors',()=>{
 for(const clear of [t=>t.reset(true),t=>t.retry(),t=>{t.toggleDebug();t.debugPhase(1);t.closeDebug()},t=>{t.toggleDebug();t.debugPhase(2);t.closeDebug()},t=>{t.toggleDebug();t.debugPhase(3);t.closeDebug()},t=>{t.toggleDebug();t.debugStage(1);t.closeDebug()},t=>t.startStage(2),t=>t.goHome(),t=>t.victory()]){const {t}=fresh();t.previewStage3(2,'meteor');t.p.inv=999;t.updateMeteors(.34);assert(t.meteors.length);clear(t);assert.equal(t.getState().meteorEvent,null);assert.equal(t.getState().meteors.length,0);const hp=t.p.hp;t.tick(.3);assert.equal(t.p.hp,hp)}
});
check('pause settings debug home confirmation and player death freeze event and projectile clocks',()=>{
 for(const open of [e=>e.t.pause(),e=>e.t.openSettings(),e=>e.t.toggleDebug(),e=>e.els.homeBtn.onclick(),e=>{e.t.p.hp=1;e.t.p.inv=0;e.t.p.x=e.t.meteors[0].x;e.t.p.y=e.t.meteors[0].impactY;e.t.advanceMeteors(.4)}]){const e=fresh(),t=e.t;t.previewStage3(2,'meteor');open(e);const before=JSON.stringify(t.getState());t.tick(5);assert.equal(JSON.stringify(t.getState()),before)}
});
check('preview alias activation eligibility, warning durations and snapshot copies are documented',()=>{
 const {t}=fresh();assert(!t.previewStage3(1,'meteor'));for(const alias of ['meteor','meteorRoar','ultra','ultraTell','perchTravel']){assert(t.previewStage3(2,alias));assert.equal(t.b.state,'meteorRoar');assert(t.event.active);assert.equal(t.event.spawned,1);const s=t.getState();s.meteorEvent.spawned=99;s.meteors[0].x=0;assert.equal(t.event.spawned,1);assert(t.meteors[0].x>1500);t.p.inv=999;for(let i=0;i<1000;i++){t.updateMeteors(.01);for(const m of t.meteors)assert(m.impactAt>=.35&&m.impactAt<=.5)}}
});
console.log(`All ${count} ptera checks passed`);
