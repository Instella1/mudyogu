const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(__dirname+'/../primal-journey.html','utf8');
const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const PROG='primalJourney.progress.v1',REC='primalJourney.records.v2';
function boot(storage={}){
 const gradient={addColorStop(){}},draws=[],els={};
 const ctx=new Proxy({createLinearGradient:()=>gradient,createRadialGradient:()=>gradient,fillText(text,x,y){draws.push({text:String(text),x,y})}},{get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 const el=id=>els[id]??={hidden:false,getContext:()=>ctx,setAttribute(k,v){this[k]=v},classList:{toggle(){}},addEventListener(){},focus(){}};
 const box={console,Math,localStorage:{getItem:k=>storage[k]||null,setItem(k,v){storage[k]=v}},document:{getElementById:el,querySelectorAll:()=>[],addEventListener(){}},window:{addEventListener(){}},requestAnimationFrame(){},matchMedia:()=>({matches:false})};
 const js=source.replace(/\}\)\(\);\s*$/,`globalThis.t={...window.primalJourney,reset,updateBoss,updatePlayer,updateSpear,throwSpear,victory,hud,pause,isSwimming,waterLine,spinoContacts,bossRect,get p(){return player},get b(){return boss},get spear(){return spear},get keys(){return keys},get press(){return press},get progress(){return progress},get records(){return stageRecords},get mode(){return mode},tick:dt=>update(dt)};})();`);
 vm.createContext(box);vm.runInContext(js,box);return{t:box.t,els,storage,draws};
}
let count=0;function check(label,f){f();console.log('PASS: '+label);count++}
const near=(a,b,eps=1e-6,msg='')=>assert(Math.abs(a-b)<eps,`${msg} ${a} != ${b}`);
const DT=1/120;
function arena(e=boot()){e.t.startStage(4);e.t.p.x=1661;e.t.updatePlayer(0);return e}
function phase(e,n){e.t.toggleDebug();e.t.debugPhase(n);e.t.closeDebug();return e}
function run(t,seconds,each){for(let i=0;i<Math.round(seconds/DT);i++){if(each&&each(i*DT)===false)break;t.updateBoss(DT);t.updatePlayer(DT)}}
function until(t,state,limit=12,each){for(let i=0;i<limit/DT&&t.b.state!==state;i++){if(each)each();t.updateBoss(DT);t.updatePlayer(DT)}assert.equal(t.b.state,state,'reached '+state)}
const guard=t=>{t.p.inv=1e9};

check('stage4 approach: 1300 HP swimming boss stays dormant, camp saves, arena heals',()=>{
 const e=boot(),t=e.t;t.startStage(4);assert.equal(t.getState().stage,4);assert.equal(t.b.hp,1300);assert.equal(t.b.max,1300);assert.equal(t.b.phase,1);assert.equal(t.b.state,'swim');
 t.updateBoss(20);assert.equal(t.b.elapsed,0);assert.equal(t.waterLine(),2140);t.p.x=1431;t.updatePlayer(0);assert.equal(t.progress.checkpoint,'camp');t.p.hp=1;t.p.x=1661;t.updatePlayer(0);assert.equal(t.p.hp,6);assert(t.getState().arena)});
check('phase thresholds 871/870 and 431/430, robot from phase2, roar, no regression',()=>{
 const {t}=arena();t.b.hp=871;t.updateBoss(.01);assert.equal(t.b.phase,1);t.b.hp=870;t.updateBoss(.01);assert.equal(t.b.phase,2);assert(t.b.robot);assert.equal(t.b.state,'roar');
 t.b.hp=431;t.updateBoss(.01);assert.equal(t.b.phase,2);t.b.hp=430;t.updateBoss(.01);assert.equal(t.b.phase,3);t.b.hp=900;t.updateBoss(.01);assert.equal(t.b.phase,3)});
check('swimming: right half is water, speed 150 vs 290, one low jump and no double jump',()=>{
 const {t}=arena();t.b.nextAt=999;guard(t);t.p.x=2000;assert(!t.isSwimming());t.keys.right=true;for(let i=0;i<60;i++)t.updatePlayer(DT);near(t.p.vx,290,1,'land speed');
 t.p.x=2300;t.p.vx=0;for(let i=0;i<60;i++){t.updatePlayer(DT);t.p.x=Math.min(t.p.x,2400)}assert(t.isSwimming());near(t.p.vx,150,1,'swim speed');t.keys.right=false;
 t.p.x=2300;t.p.vx=0;t.press.jump=true;t.updatePlayer(DT);t.press.jump=false;assert(t.p.vy<0);const v=t.p.vy;assert(v>-480&&v<-450,'weaker jump '+v);let top=602;for(let i=0;i<20;i++){t.updatePlayer(DT);top=Math.min(top,t.p.y)}const before=t.p.vy;t.press.jump=true;t.updatePlayer(DT);t.press.jump=false;assert(t.p.vy>before,'no double jump from water');for(let i=0;i<40;i++){t.updatePlayer(DT);top=Math.min(top,t.p.y)}
 const height=602-top;assert(height>40,'can hop out '+height)});
check('breath: 4 seconds free, then 1 damage every 2 seconds even through invulnerability; air refills',()=>{
 const {t}=arena();t.b.nextAt=999;t.b.x=2650;t.p.x=2250;t.p.hp=6;let hits=[];
 for(let i=1;i<=Math.round(8.5/DT);i++){t.p.inv=5;const hp=t.p.hp;t.updatePlayer(DT);t.p.x=2250;if(t.p.hp<hp)hits.push(i*DT)}
 assert.equal(hits.length,3,'ticks '+hits);near(hits[0],4,DT*1.5,'first');near(hits[1]-hits[0],2,DT*1.5,'gap');
 t.p.x=1900;for(let i=0;i<Math.round(2.05/DT);i++)t.updatePlayer(DT);assert.equal(t.p.breath,0,'refilled on land');t.p.x=2250;const hp=t.p.hp;for(let i=0;i<Math.round(3.9/DT);i++){t.updatePlayer(DT);t.p.x=2250}assert.equal(t.p.hp,hp)});
check('no breath damage once the region is cleared',()=>{const {t}=arena();t.victory();t.p.x=2300;t.p.hp=6;for(let i=0;i<Math.round(10/DT);i++){t.updatePlayer(DT);t.p.x=2300}assert.equal(t.p.hp,6)});
check('shore ambush: .6 tell, lunge bites a player on land for 1, then crawls back to water',()=>{
 const {t}=arena();t.p.x=1950;t.p.inv=0;t.p.hp=6;t.b.nextAt=0;t.updateBoss(DT);assert.equal(t.b.state,'lungeTell');near(t.b.timer,.6,1e-9);
 until(t,'lunge',1,()=>{t.p.x=1950});const from=t.b.x;until(t,'crawl',1,()=>{t.p.x=1950});assert.equal(t.p.hp,5,'bite');assert(t.b.x<from);
 until(t,'swim',3,()=>{t.p.x=1950});assert(t.b.x>t.waterLine()+100,'back in water')});
check('missed lunge leaves it beached for 2 seconds: targetable and damageable',()=>{
 const {t}=arena();t.p.x=1900;t.b.nextAt=0;t.updateBoss(DT);until(t,'lunge',1,()=>{t.p.x=1900});t.p.dash=.2;t.p.inv=0;
 for(let i=0;i<60&&t.b.state==='lunge';i++){t.p.dash=.2;t.updateBoss(DT);t.spinoContacts()}assert.equal(t.b.state,'beached');near(t.b.timer,2,.02);
 assert(t.b.x<t.waterLine());t.p.dash=0;guard(t);t.p.x=t.b.x-170;t.p.dir=1;t.p.atk=0;t.p.atkCD=0;t.keys.attack=true;t.updatePlayer(.001);t.keys.attack=false;assert.equal(t.b.hp,1290);
 run(t,2.05);assert.equal(t.b.state,'crawl')});
check('far player on land: wades ashore, .45 tell, two swipes with a .35 gap, 1 damage each',()=>{
 const {t}=arena();t.p.x=1600;t.b.nextAt=0;t.updateBoss(DT);assert.equal(t.b.state,'wade');until(t,'clawTell',8,()=>{t.p.x=1600;t.p.inv=1e9});near(t.b.timer,.45,1e-9);
 t.p.inv=0;t.p.hp=6;until(t,'swipe',1,()=>{t.p.x=1600});until(t,'clawGap',1,()=>{t.p.x=1600});assert.equal(t.p.hp,5);near(t.b.timer,.35,.01);t.p.inv=0;t.p.hurt=0;
 until(t,'swipe2',1,()=>{t.p.x=1600;t.p.inv=0});until(t,'clawRecover',1,()=>{t.p.x=1600});assert.equal(t.p.hp,4)});
check('fin hunt: submerged boss cannot be hit, ripples lock .7 seconds, breach column hits 1',()=>{
 const {t}=arena();t.p.x=2400;t.b.nextAt=0;guard(t);t.updateBoss(DT);assert.equal(t.b.state,'submerge');until(t,'fin',1,()=>{t.p.x=2400;guard(t)});
 assert.equal(t.bossRect().w,0,'untargetable');const hp=t.b.hp;t.p.x=t.b.x-100;t.p.dir=1;t.p.atk=0;t.p.atkCD=0;t.keys.attack=true;t.updatePlayer(.001);t.keys.attack=false;assert.equal(t.b.hp,hp);
 until(t,'breachTell',4,()=>{t.p.x=2400;guard(t);t.p.breath=0});near(t.b.lockX,2400,15);near(t.b.timer,.7,1e-9);t.p.inv=0;t.p.hp=6;
 until(t,'surfaced',2,()=>{t.p.x=2400;t.p.breath=0});assert.equal(t.p.hp,5);assert(t.bossRect().w>0,'surfaced is targetable')});
check('stepping out of the ripple ring avoids the breach',()=>{
 const {t}=arena();t.p.x=2400;t.b.nextAt=0;until(t,'breachTell',5,()=>{t.p.x=2400;guard(t);t.p.breath=0});t.p.inv=0;t.p.hp=6;t.p.x=2150;until(t,'surfaced',2,()=>{t.p.x=2150;t.p.breath=0});assert.equal(t.p.hp,6)});
check('phase2 inhale drags a land player toward the water at 170 and walking against it holds ground',()=>{
 const e=phase(arena(),2),t=e.t;guard(t);t.p.x=1800;t.b.x=2400;t.b.count=1;t.b.nextAt=0;t.b.state='swim';t.updateBoss(DT);assert.equal(t.b.state,'inhaleTell');until(t,'inhale',1,()=>{t.p.x=1800});
 const x=t.p.x;t.updateBoss(.5);near(t.p.x-x,85,1,'pull');t.keys.left=true;const held=t.p.x;for(let i=0;i<60;i++){t.updateBoss(DT);t.updatePlayer(DT)}t.keys.left=false;assert(t.p.x<held,'walking against the current wins')});
check('darkness only from phase2: 1s flicker then 5s dark, every 12s, boss keeps attacking',()=>{
 const one=arena().t;run(one,12,()=>guard(one));assert.equal(one.b.dark,'off');
 const e=phase(arena(),2),t=e.t;const seen=[];let last='off',busy=0;
 run(t,30,(s)=>{guard(t);t.p.breath=0;if(t.b.dark!==last){seen.push([t.b.dark,+s.toFixed(2)]);last=t.b.dark}if(t.b.dark==='on'&&t.b.state!=='swim')busy++});
 assert.deepEqual(seen.slice(0,6).map(x=>x[0]),['tell','on','off','tell','on','off']);near(seen[0][1],4,.02,'first');near(seen[1][1]-seen[0][1],1,.02,'tell');near(seen[2][1]-seen[1][1],5,.02,'dark');near(seen[3][1]-seen[0][1],12,.02,'cycle');assert(busy>0,'attacks continue in the dark')});
check('darkness renders a small light circle and keeps hints above it without exceptions',()=>{
 const e=phase(arena(),3),t=e.t;guard(t);t.b.dark='on';t.b.darkT=1;for(const st of ['swim','lungeTell','fin','breachTell','shock','inhale','beached','swipe','roar']){t.b.state=st;t.b.timer=.3;t.render()}e.draws.length=0;t.b.state='lungeTell';t.render();assert(e.draws.some(d=>d.text.includes('고개가 들렸다')))});
check('phase3 shock hurts only a swimming player and respects dash',()=>{
 const e=phase(arena(),3),t=e.t;t.b.state='shock';t.b.timer=2;t.p.inv=0;t.p.hp=6;t.p.x=1900;t.updateBoss(DT);assert.equal(t.p.hp,6,'land safe');t.p.x=2300;t.p.dash=.2;t.updateBoss(DT);assert.equal(t.p.hp,6,'dash');t.p.dash=0;t.updateBoss(DT);assert.equal(t.p.hp,5,'swimming shocked')});
check('phase3 tide: water edge 2140 -> 1840 over 2s, holds 4s, recedes 2s, every 16s',()=>{
 const e=phase(arena(),3),t=e.t;const edge=[];run(t,24,(s)=>{guard(t);t.p.breath=0;edge.push([s,t.waterLine()])});
 const at=s=>edge.find(x=>x[0]>=s-1e-9)[1];near(at(4.9),2140,1);near(at(6),1990,4);near(at(7.5),1840,1);near(at(10.5),1840,1);near(at(12),1990,4);near(at(13.5),2140,1);near(at(21.5),2065,4,'second tide rising');near(at(23.5),1840,1);
 const two=phase(arena(),2).t;run(two,20,()=>guard(two));assert.equal(two.waterLine(),2140)});
check('body contact always 1 while visible, never while submerged',()=>{
 const {t}=arena();t.b.state='swim';t.b.nextAt=999;t.b.x=2300;t.b.sink=55;t.p.x=2250;t.p.inv=0;t.p.hp=6;t.spinoContacts();assert.equal(t.p.hp,5);t.b.state='fin';t.b.sink=175;t.p.inv=0;t.spinoContacts();assert.equal(t.p.hp,5)});
check('spear: 60 to a visible boss, ignored while submerged, recoverable from the water',()=>{
 const {t}=arena();guard(t);t.b.nextAt=999;t.b.x=2300;t.p.x=2000;t.p.dir=1;assert(t.throwSpear());for(let i=0;i<60;i++)t.updateSpear(.01);assert.equal(t.b.hp,1240);
 for(let i=0;i<400&&t.spear.state!=='ground';i++)t.updateSpear(.01);assert.equal(t.spear.state,'ground');assert(t.spear.x>t.waterLine(),'landed in water');t.p.x=t.spear.x;t.p.y=602;t.updateSpear(.01);assert.equal(t.spear,null);
 t.b.state='fin';t.b.sink=175;t.p.x=2000;assert(t.throwSpear());for(let i=0;i<60;i++)t.updateSpear(.01);assert.equal(t.b.hp,1240)});
check('debug: stage4 phases 1300/870/430 with darkness and tide clocks, no saves',()=>{
 const e=boot(),t=e.t;t.start();t.finishIntro();const saved=e.storage[PROG];t.toggleDebug();assert(t.debugStage(4));assert.equal(t.getState().stage,4);
 for(const [n,hp] of [[1,1300],[2,870],[3,430]]){assert(t.debugPhase(n));assert.equal(t.b.hp,hp);assert.equal(t.b.max,1300);assert.equal(t.b.phase,n);assert.equal(t.b.robot,n>=2);assert.equal(t.b.darkAt,n>=2?4:Infinity);assert.equal(t.b.tideAt,n>=3?5:Infinity)}
 t.closeDebug();t.victory();assert.equal(e.storage[PROG],saved);assert.equal(t.records[4].clears,0)});
check('pause freezes darkness and tide clocks',()=>{const e=phase(arena(),3),t=e.t;guard(t);run(t,6);const d=t.b.darkT,w=t.waterLine();t.pause();t.tick(3);assert.equal(t.b.darkT,d);assert.equal(t.waterLine(),w);t.pause()});
check('stage4 records hidden until clear, then saved separately; ending after the region is persisted',()=>{
 const e=arena(),t=e.t;t.render();const before=e.els.moonRecords.innerHTML;assert(before.includes('???'));assert(!before.includes('잠긴 달'));
 t.p.hp=5;t.victory();assert.equal(t.records[4].clears,1);assert.equal(JSON.parse(e.storage[REC]).stages[4].clears,1);assert(e.els.moonRecords.innerHTML.includes('잠긴 달의 물가'));assert.equal(t.progress.cleared[4],true);
 t.updateBoss(2.4);assert.equal(t.mode,'won');t.continueJourney();t.p.x=3200;t.updatePlayer(0);assert.equal(t.progress.checkpoint,'ending');assert.equal(t.getState().stage,4);
 const re=boot(e.storage);assert(re.t.continueSaved());assert.equal(re.t.p.x,3200);re.t.render();assert(re.draws.some(d=>d.text==='물결이 잦아들고, 달빛만이 남았다.'))});
check('retry and reset restore a fresh 1300 HP spinosaurus with calm water',()=>{const e=phase(arena(),3),t=e.t;guard(t);run(t,8);t.p.hp=1;t.retry();assert.equal(t.b.hp,1300);assert.equal(t.b.phase,1);assert.equal(t.b.dark,'off');assert.equal(t.waterLine(),2140);assert.equal(t.p.hp,6)});
console.log(`All ${count} spino checks passed`);
