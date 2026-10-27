const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(__dirname+'/../primal-journey.html','utf8');
const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const PROG='primalJourney.progress.v1',REC='primalJourney.records.v2';
function boot(storage={}){
 const gradient={addColorStop(){}},draws=[],els={};
 const ctx=new Proxy({createLinearGradient:()=>gradient,createRadialGradient:()=>gradient,fillText(text,x,y){draws.push({text:String(text),x,y})}},{get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 const el=id=>els[id]??={hidden:false,getContext:()=>ctx,setAttribute(k,v){this[k]=v},classList:{toggle(){}},addEventListener(){},focus(){}};
 const box={console,Math,localStorage:{getItem:k=>storage[k]||null,setItem(k,v){storage[k]=v}},document:{getElementById:el,querySelectorAll:()=>[],addEventListener(){}},window:{addEventListener(){}},requestAnimationFrame(){},matchMedia:()=>({matches:false})};
 const js=source.replace(/\}\)\(\);\s*$/,`globalThis.t={...window.primalJourney,reset,updateBoss,updatePlayer,updateSpear,throwSpear,victory,hud,pause,isSwimming,pools,poolAt,spinoContacts,spinoBodyRect,bossRect,get p(){return player},get b(){return boss},get spear(){return spear},get keys(){return keys},get press(){return press},get progress(){return progress},get records(){return stageRecords},get mode(){return mode},get cam(){return cam},tick:dt=>update(dt)};})();`);
 vm.createContext(box);vm.runInContext(js,box);return{t:box.t,els,storage,draws};
}
let count=0;function check(label,f){f();console.log('PASS: '+label);count++}
const near=(a,b,eps=1e-6,msg='')=>assert(Math.abs(a-b)<eps,`${msg} ${a} != ${b}`);
const DT=1/120;
// 지형: 땅 1535~2200 · 물 2200~2700 · 땅 2700~3300 · 물 3300~3800 · 땅 3800~4750
const LAND1=1950,POOL1=2450,LAND2=3000,POOL2=3550,LAND3=4300;
function arena(e=boot()){e.t.startStage(4);e.t.p.x=1661;e.t.updatePlayer(0);return e}
function phase(e,n){e.t.toggleDebug();e.t.debugPhase(n);e.t.closeDebug();return e}
function run(t,seconds,each){for(let i=0;i<Math.round(seconds/DT);i++){if(each&&each(i*DT)===false)break;t.updateBoss(DT);t.updatePlayer(DT)}}
function until(t,state,limit=12,each){for(let i=0;i<limit/DT&&t.b.state!==state;i++){if(each)each();t.updateBoss(DT);t.updatePlayer(DT)}assert.equal(t.b.state,state,'reached '+state)}
const guard=t=>{t.p.inv=1e9};

check('stage4 approach: 1300 HP boss waits in the first pool, camp saves, arena heals',()=>{
 const e=boot(),t=e.t;t.startStage(4);assert.equal(t.getState().stage,4);assert.equal(t.b.hp,1300);assert.equal(t.b.max,1300);assert.equal(t.b.phase,1);assert.equal(t.b.state,'swim');assert.equal(t.poolAt(t.b.x),0);
 t.updateBoss(20);assert.equal(t.b.elapsed,0);t.p.x=1431;t.updatePlayer(0);assert.equal(t.progress.checkpoint,'camp');t.p.hp=1;t.p.x=1661;t.updatePlayer(0);assert.equal(t.p.hp,6);assert(t.getState().arena)});
check('wide arena: land-water-land-water-land, camera follows the player to the far right',()=>{
 const {t}=arena();assert.deepEqual(JSON.parse(JSON.stringify(t.getState().pools)),[[2200,2700],[3300,3800]]);
 assert.deepEqual([LAND1,POOL1,LAND2,POOL2,LAND3].map(x=>{t.p.x=x;t.p.y=602;return t.isSwimming()}),[false,true,false,true,false]);
 guard(t);t.b.nextAt=999;t.p.x=4000;for(let i=0;i<240;i++)t.tick(DT);near(t.cam,3440,2,'camera');t.p.x=4740;t.keys.right=true;for(let i=0;i<60;i++)t.updatePlayer(DT);t.keys.right=false;near(t.p.x,4750,.01,'right wall');
 t.p.x=1600;for(let i=0;i<240;i++)t.tick(DT);near(t.cam,1500,2,'left camera clamp')});
check('phase thresholds 871/870 and 431/430, robot from phase2, roar, no regression',()=>{
 const {t}=arena();t.b.hp=871;t.updateBoss(.01);assert.equal(t.b.phase,1);t.b.hp=870;t.updateBoss(.01);assert.equal(t.b.phase,2);assert(t.b.robot);assert.equal(t.b.state,'roar');
 t.b.hp=431;t.updateBoss(.01);assert.equal(t.b.phase,2);t.b.hp=430;t.updateBoss(.01);assert.equal(t.b.phase,3);t.b.hp=900;t.updateBoss(.01);assert.equal(t.b.phase,3)});
check('body 150x85 can be cleared by a double jump from land without touching it',()=>{
 const {t}=arena();const r={...t.b,state:'beached',timer:99,x:LAND2,sink:0};Object.assign(t.b,r);const body=t.spinoBodyRect();assert.equal(body.w,150);assert.equal(body.h,85);
 // 달려오다(290) 뛰고, 첫 점프 꼭대기에서 두 번째 점프.
 t.p.x=2800;t.p.y=602;t.p.vx=290;t.p.inv=0;t.p.hp=6;t.keys.right=true;t.press.jump=true;t.updatePlayer(DT);t.press.jump=false;let second=false;
 for(let i=0;i<150;i++){if(!second&&t.p.vy>=0){t.press.jump=true;second=true}t.updatePlayer(DT);t.press.jump=false}t.keys.right=false;
 assert(second);assert.equal(t.p.hp,6,'cleared the body');assert(t.p.x>body.x+body.w,'landed beyond '+t.p.x)});
check('swimming: speed 150 vs 290, one low jump and no double jump',()=>{
 const {t}=arena();t.b.nextAt=999;guard(t);t.p.x=LAND1;t.keys.right=true;for(let i=0;i<60;i++){t.updatePlayer(DT);t.p.x=LAND1}near(t.p.vx,290,1,'land speed');
 t.p.x=POOL1;t.p.vx=0;for(let i=0;i<60;i++){t.updatePlayer(DT);t.p.x=POOL1}near(t.p.vx,150,1,'swim speed');t.keys.right=false;
 t.p.vx=0;t.press.jump=true;t.updatePlayer(DT);t.press.jump=false;const v=t.p.vy;assert(v>-480&&v<-450,'weaker jump '+v);let top=602;for(let i=0;i<20;i++){t.updatePlayer(DT);top=Math.min(top,t.p.y)}
 const before=t.p.vy;t.press.jump=true;t.updatePlayer(DT);t.press.jump=false;assert(t.p.vy>before,'no double jump from water');for(let i=0;i<40;i++){t.updatePlayer(DT);top=Math.min(top,t.p.y)}assert(602-top>40,'can hop out')});
check('breath: 4 seconds free, then 1 damage every 2 seconds even through invulnerability; 2s on land refills',()=>{
 const {t}=arena();t.b.nextAt=999;t.b.x=4600;t.p.x=POOL1;t.p.hp=6;const hits=[];
 for(let i=1;i<=Math.round(8.5/DT);i++){t.p.inv=5;const hp=t.p.hp;t.updatePlayer(DT);t.p.x=POOL1;if(t.p.hp<hp)hits.push(i*DT)}
 assert.equal(hits.length,3,'ticks '+hits);near(hits[0],4,DT*1.5,'first');near(hits[1]-hits[0],2,DT*1.5,'gap');
 t.p.x=LAND2;for(let i=0;i<Math.round(2.05/DT);i++)t.updatePlayer(DT);assert.equal(t.p.breath,0,'refilled on land');t.p.x=POOL2;const hp=t.p.hp;for(let i=0;i<Math.round(3.9/DT);i++){t.updatePlayer(DT);t.p.x=POOL2}assert.equal(t.p.hp,hp)});
check('no breath damage once the region is cleared',()=>{const {t}=arena();t.victory();t.p.x=POOL1;t.p.hp=6;for(let i=0;i<Math.round(10/DT);i++){t.updatePlayer(DT);t.p.x=POOL1}assert.equal(t.p.hp,6)});
check('boss follows the player across land and pools to the far shore',()=>{
 const {t}=arena();guard(t);t.p.x=LAND3;run(t,12,()=>{t.p.x=LAND3;guard(t)});assert(t.b.x>3700,'reached the far side '+t.b.x)});
check('shore ambush: .6 tell, lunge from the pool bites a player on land for 1',()=>{
 const {t}=arena();t.b.x=2620;t.p.x=2850;t.p.inv=0;t.p.hp=6;t.b.nextAt=0;t.updateBoss(DT);assert.equal(t.b.state,'lungeTell');near(t.b.timer,.6,1e-9);
 until(t,'lunge',1,()=>{t.p.x=2850});until(t,'swim',1,()=>{t.p.x=2850});assert.equal(t.p.hp,5,'bite')});
check('missed lunge leaves it beached on land for 2 seconds: targetable and damageable',()=>{
 const {t}=arena();t.b.x=2620;t.p.x=2850;t.b.nextAt=0;t.updateBoss(DT);until(t,'lunge',1,()=>{t.p.x=2850});
 for(let i=0;i<60&&t.b.state==='lunge';i++){t.p.dash=.2;t.updateBoss(DT);t.spinoContacts()}assert.equal(t.b.state,'beached');near(t.b.timer,2,.02);assert.equal(t.poolAt(t.b.x),-1,'on land');
 t.p.dash=0;guard(t);t.p.x=t.b.x-130;t.p.dir=1;t.p.atk=0;t.p.atkCD=0;t.keys.attack=true;t.updatePlayer(.001);t.keys.attack=false;assert.equal(t.b.hp,1290);
 run(t,2.05);assert.equal(t.b.state,'swim')});
check('on land up close: .45 tell, two swipes with a .35 gap, 1 damage each',()=>{
 const {t}=arena();t.b.x=4320;t.b.sink=0;t.p.x=4180;t.b.nextAt=0;t.updateBoss(DT);assert.equal(t.b.state,'clawTell');near(t.b.timer,.45,1e-9);
 t.p.inv=0;t.p.hp=6;until(t,'swipe',1,()=>{t.p.x=4180});until(t,'clawGap',1,()=>{t.p.x=4180});assert.equal(t.p.hp,5);near(t.b.timer,.35,.01);t.p.inv=0;t.p.hurt=0;
 until(t,'swipe2',1,()=>{t.p.x=4180;t.p.inv=0});until(t,'clawRecover',1,()=>{t.p.x=4180});assert.equal(t.p.hp,4)});
check('fin hunt in the same pool: untargetable while submerged, .7s ripples, breach hits 1',()=>{
 const {t}=arena();t.b.x=2620;t.p.x=POOL1;t.b.nextAt=0;guard(t);t.updateBoss(DT);assert.equal(t.b.state,'submerge');until(t,'fin',1,()=>{t.p.x=POOL1;guard(t)});
 assert.equal(t.bossRect().w,0,'untargetable');const hp=t.b.hp;t.p.x=t.b.x-80;t.p.dir=1;t.p.atk=0;t.p.atkCD=0;t.keys.attack=true;t.updatePlayer(.001);t.keys.attack=false;assert.equal(t.b.hp,hp);
 until(t,'breachTell',4,()=>{t.p.x=POOL1;guard(t);t.p.breath=0});near(t.b.lockX,POOL1,15);near(t.b.timer,.7,1e-9);t.p.inv=0;t.p.hp=6;
 until(t,'surfaced',2,()=>{t.p.x=POOL1;t.p.breath=0});assert.equal(t.p.hp,5);assert(t.bossRect().w>0,'surfaced is targetable')});
check('stepping out of the ripple ring avoids the breach',()=>{
 const {t}=arena();t.b.x=2620;t.p.x=POOL1;t.b.nextAt=0;until(t,'breachTell',5,()=>{t.p.x=POOL1;guard(t);t.p.breath=0});t.p.inv=0;t.p.hp=6;t.p.x=2150;until(t,'surfaced',2,()=>{t.p.x=2150;t.p.breath=0});assert.equal(t.p.hp,6)});
check('phase2 inhale drags a land player toward the pool at 170 and walking against it holds ground',()=>{
 const e=phase(arena(),2),t=e.t;guard(t);t.b.x=2620;t.p.x=2950;t.b.count=1;t.b.nextAt=0;t.b.state='swim';t.updateBoss(DT);assert.equal(t.b.state,'inhaleTell');until(t,'inhale',1,()=>{t.p.x=2950});
 const x=t.p.x;t.updateBoss(.5);near(x-t.p.x,85,1,'pull');t.keys.right=true;const held=t.p.x;for(let i=0;i<60;i++){t.updateBoss(DT);t.updatePlayer(DT)}t.keys.right=false;assert(t.p.x>held,'walking against the current wins')});
check('darkness only from phase2: 1s flicker then 5s dark, every 12s, boss keeps attacking',()=>{
 const one=arena().t;run(one,12,()=>guard(one));assert.equal(one.b.dark,'off');
 const e=phase(arena(),2),t=e.t;const seen=[];let last='off',busy=0;
 run(t,30,(s)=>{guard(t);t.p.breath=0;if(t.b.dark!==last){seen.push([t.b.dark,+s.toFixed(2)]);last=t.b.dark}if(t.b.dark==='on'&&t.b.state!=='swim')busy++});
 assert.deepEqual(seen.slice(0,6).map(x=>x[0]),['tell','on','off','tell','on','off']);near(seen[0][1],4,.02,'first');near(seen[1][1]-seen[0][1],1,.02,'tell');near(seen[2][1]-seen[1][1],5,.02,'dark');near(seen[3][1]-seen[0][1],12,.02,'cycle');assert(busy>0,'attacks continue in the dark')});
check('darkness renders a small light circle and keeps hints above it without exceptions',()=>{
 const e=phase(arena(),3),t=e.t;guard(t);t.b.dark='on';t.b.darkT=1;for(const st of ['swim','lungeTell','fin','breachTell','shock','inhale','beached','swipe','roar']){t.b.state=st;t.b.timer=.3;t.render()}e.draws.length=0;t.b.state='lungeTell';t.render();assert(e.draws.some(d=>d.text.includes('고개가 들렸다')))});
check('phase3 shock hurts a swimming player in either pool, never on land, respects dash',()=>{
 const e=phase(arena(),3),t=e.t;t.b.state='shock';t.b.timer=5;t.p.inv=0;t.p.hp=6;t.p.x=LAND2;t.updateBoss(DT);assert.equal(t.p.hp,6,'land safe');t.p.x=POOL2;t.p.dash=.2;t.updateBoss(DT);assert.equal(t.p.hp,6,'dash');t.p.dash=0;t.updateBoss(DT);assert.equal(t.p.hp,5,'far pool shocked');t.p.inv=0;t.p.x=POOL1;t.updateBoss(DT);assert.equal(t.p.hp,4,'near pool shocked')});
check('phase3 tide: both pools widen by 150 over 2s, hold 4s, recede 2s, every 16s',()=>{
 const e=phase(arena(),3),t=e.t;const edge=[];run(t,24,(s)=>{guard(t);t.p.breath=0;edge.push([s,t.pools()[0][1],t.pools()[1][0]])});
 const at=s=>edge.find(x=>x[0]>=s-1e-9);near(at(4.9)[1],2700,1);near(at(6)[1],2775,3);near(at(7.5)[1],2850,1);near(at(7.5)[2],3150,1);near(at(10.5)[1],2850,1);near(at(12)[1],2775,3);near(at(13.5)[1],2700,1);near(at(21.5)[1],2737.5,3,'second tide rising');near(at(23.5)[1],2850,1);
 const two=phase(arena(),2).t;run(two,20,()=>guard(two));assert.deepEqual(JSON.parse(JSON.stringify(two.pools())),[[2200,2700],[3300,3800]])});
check('body contact always 1 while visible, never while submerged',()=>{
 const {t}=arena();t.b.state='swim';t.b.nextAt=999;t.b.x=POOL1;t.b.sink=35;t.p.x=POOL1-60;t.p.inv=0;t.p.hp=6;t.spinoContacts();assert.equal(t.p.hp,5);t.b.state='fin';t.b.sink=110;t.p.inv=0;t.spinoContacts();assert.equal(t.p.hp,5)});
check('spear: 60 to a visible boss, ignored while submerged, recoverable from a pool',()=>{
 const {t}=arena();guard(t);t.b.nextAt=999;t.b.state='beached';t.b.timer=99;t.b.x=2950;t.b.sink=0;t.p.x=2250;t.p.dir=1;assert(t.throwSpear());for(let i=0;i<150&&t.spear&&t.spear.state==='flying';i++)t.updateSpear(.01);assert.equal(t.b.hp,1240);
 const e2=arena(),q=e2.t;guard(q);q.b.nextAt=999;q.b.state='fin';q.b.sink=110;q.b.x=2950;q.p.x=2250;q.p.dir=1;assert(q.throwSpear());for(let i=0;i<150&&q.spear.state==='flying';i++)q.updateSpear(.01);assert.equal(q.b.hp,1300,'submerged ignores spear');
 const e3=arena(),r=e3.t;guard(r);r.b.nextAt=999;r.b.x=POOL2;r.p.x=3250;r.p.dir=-1;assert(r.throwSpear());for(let i=0;i<400&&r.spear.state!=='ground';i++)r.updateSpear(.01);assert.equal(r.spear.state,'ground');assert.equal(r.poolAt(r.spear.x),0,'landed in the first pool');r.p.x=r.spear.x;r.p.y=602;r.updateSpear(.01);assert.equal(r.spear,null)});
check('debug: stage4 phases 1300/870/430 with darkness and tide clocks, no saves',()=>{
 const e=boot(),t=e.t;t.start();t.finishIntro();const saved=e.storage[PROG];t.toggleDebug();assert(t.debugStage(4));assert.equal(t.getState().stage,4);
 for(const [n,hp] of [[1,1300],[2,870],[3,430]]){assert(t.debugPhase(n));assert.equal(t.b.hp,hp);assert.equal(t.b.max,1300);assert.equal(t.b.phase,n);assert.equal(t.b.robot,n>=2);assert.equal(t.b.darkAt,n>=2?4:Infinity);assert.equal(t.b.tideAt,n>=3?5:Infinity)}
 t.closeDebug();t.victory();assert.equal(e.storage[PROG],saved);assert.equal(t.records[4].clears,0)});
check('pause freezes darkness and tide clocks',()=>{const e=phase(arena(),3),t=e.t;guard(t);run(t,6);const d=t.b.darkT,w=JSON.stringify(t.pools());t.pause();t.tick(3);assert.equal(t.b.darkT,d);assert.equal(JSON.stringify(t.pools()),w);t.pause()});
check('stage4 records hidden until clear, then saved; the ending path lies beyond the wide arena',()=>{
 const e=arena(),t=e.t;t.render();const before=e.els.moonRecords.innerHTML;assert(before.includes('???'));assert(!before.includes('잠긴 달'));
 t.p.hp=5;t.victory();assert.equal(t.records[4].clears,1);assert.equal(JSON.parse(e.storage[REC]).stages[4].clears,1);assert(e.els.moonRecords.innerHTML.includes('잠긴 달의 물가'));assert.equal(t.progress.cleared[4],true);
 t.updateBoss(2.4);assert.equal(t.mode,'won');t.continueJourney();t.p.x=3200;t.updatePlayer(0);assert.notEqual(t.progress.checkpoint,'ending','old ending spot is now inside the arena');t.p.x=5200;t.updatePlayer(0);assert.equal(t.progress.checkpoint,'ending');assert.equal(t.getState().stage,4);
 const re=boot(e.storage);assert(re.t.continueSaved());assert.equal(re.t.p.x,5200);re.t.render();assert(re.draws.some(d=>d.text==='물결이 잦아들고, 달빛만이 남았다.'))});
check('retry and reset restore a fresh 1300 HP spinosaurus with calm water',()=>{const e=phase(arena(),3),t=e.t;guard(t);run(t,8);t.p.hp=1;t.retry();assert.equal(t.b.hp,1300);assert.equal(t.b.phase,1);assert.equal(t.b.dark,'off');assert.deepEqual(JSON.parse(JSON.stringify(t.pools())),[[2200,2700],[3300,3800]]);assert.equal(t.p.hp,6)});
console.log(`All ${count} spino checks passed`);
