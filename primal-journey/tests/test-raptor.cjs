const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync(__dirname+'/../primal-journey.html','utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
function boot(storage={}){
 const gradient={addColorStop(){}};
 const draws=[],stack=[],state={globalAlpha:1};
 const ctx=new Proxy({createLinearGradient:()=>gradient,createRadialGradient:()=>gradient,save(){stack.push({...state})},restore(){Object.assign(state,stack.pop()||{})},fillText(text,x,y){draws.push({kind:'text',text:String(text),x,y,alpha:state.globalAlpha})},fillRect(x,y,w,h){draws.push({kind:'rect',x,y,w,h,alpha:state.globalAlpha})}},{get:(o,k)=>k==='globalAlpha'?state.globalAlpha:o[k]||(()=>{}),set:(o,k,v)=>(k==='globalAlpha'?state[k]=v:o[k]=v,true)});
 const elements={},el=id=>elements[id]??={getContext:()=>ctx,setAttribute(k,v){this[k]=v},classList:{toggle(){}},addEventListener(){},focus(){}};
 const box={console,Math,localStorage:{getItem:k=>storage[k]||null,setItem:(k,v)=>storage[k]=v},document:{getElementById:el,querySelectorAll:()=>[],addEventListener(){}},window:{addEventListener(){}},requestAnimationFrame(){},matchMedia:()=>({matches:false})};
 const js=source.replace(/\}\)\(\);\s*$/,`globalThis.t={startStage,reset,retry,updateBoss,updatePlayer,updateSpear,throwSpear,damageRaptor,victory,render,hud,makeRaptor,openSettings,closeSettings,pause,goHome,loadRecords,get p(){return player},get b(){return boss},get rs(){return raptors},get phase(){return raptorPhase},get summoned(){return summoned},get cleared(){return stageCleared},get mode(){return mode},get stage(){return stage},get keys(){return keys},get spear(){return spear},get records(){return stageRecords},get howl(){return howlRemaining},step:dt=>update(dt),setTime:n=>runTime=n};})();`);
 vm.createContext(box);vm.runInContext(js,box);return{t:box.t,box,elements,storage,draws};
}
let checks=0;function check(name,f){f();checks++;console.log('PASS: '+name)}
const env=boot(),{t,elements,storage}=env;
const fresh=()=>{t.startStage(2);t.p.x=1661;t.updatePlayer(0);t.p.inv=999;return t.rs[0]};
function summon(){const main=fresh();main.hp=480;t.updateBoss(0);t.updateBoss(1.59);assert.equal(t.rs.length,1);t.updateBoss(.02);return main}
function readyPair(){const main=summon();t.updateBoss(1);return main}
function upgrade(which=0){readyPair();t.rs[which].hp=150;t.updateBoss(0);return t.rs}
check('800 HP initial, speed 140, full health and actual preview hook',()=>{fresh();assert.equal(t.stage,2);assert.equal(t.mode,'playing');assert.equal(t.p.hp,6);assert.equal(t.rs.length,1);assert.equal(t.b.hp,800);assert.equal(t.b.max,800);assert.equal(t.b.speed,140);assert.equal(env.box.window.primalJourney.startStage,t.startStage);assert.equal(env.box.window.primalJourney.getState().stage,2)});
check('new journey starts cutscene; developer region hook enters dormant approach',()=>{t.goHome();elements.start.onclick();assert.equal(t.stage,1);assert.equal(t.mode,'cutscene');t.startStage(2);assert.equal(t.stage,2);assert.equal(t.p.x,150);t.updateBoss(12);assert.equal(t.b.elapsed,0);assert.equal(t.b.x,2400);assert(!elements.selectStage1);assert(!elements.selectStage2)});
check('phase 1 moves at 140 and jumps every 10 seconds with tell',()=>{const r=fresh();t.p.x=1700;const x=r.x;t.updateBoss(1);assert.equal(x-r.x,140);r.elapsed=9.99;t.updateBoss(.009);assert.equal(r.state,'walk');t.updateBoss(.0011);assert.equal(r.state,'jumpTell');assert.equal(r.jumpAt,20);assert.equal(r.timer,.55);t.updateBoss(.56);assert.equal(r.state,'jump');assert.equal(r.vy,-1550);for(let i=0;i<100&&r.state==='jump';i++)t.updateBoss(.01);assert.equal(r.y,602);r.elapsed=19.999;t.updateBoss(.002);assert.equal(r.state,'jumpTell');assert.equal(r.jumpAt,30)});
check('480 threshold exact, upward howl delays single wall summon of 480 HP',()=>{let r=fresh();r.hp=481;t.updateBoss(.01);assert.equal(t.phase,1);r.hp=480;t.updateBoss(0);assert.equal(t.phase,2);assert.equal(r.state,'howl');assert.equal(r.speed,190);assert.equal(t.rs.length,1);t.render();t.updateBoss(1.59);assert.equal(t.rs.length,1);assert.equal(t.summoned,false);t.updateBoss(.011);assert.equal(t.summoned,true);assert.equal(t.rs.length,2);assert.equal(t.rs[1].hp,480);assert.equal(t.rs[1].max,480);assert.equal(t.rs[1].state,'emerge');assert(t.rs[1].x>2720);assert.equal(t.rs[1].speed,190);t.render();for(let i=0;i<300;i++)t.updateBoss(.01);assert.equal(t.rs.length,2);assert.equal(t.rs[1].state,'walk');assert(t.rs[1].x<2730)});
check('both phase 2 basic speeds 190 and jump timers retained',()=>{readyPair();t.p.x=1600;for(const r of t.rs){r.state='walk';r.elapsed=2;r.x=2400}const xs=t.rs.map(r=>r.x);t.updateBoss(.5);t.rs.forEach((r,i)=>assert.equal(xs[i]-r.x,95));for(const r of t.rs)r.elapsed=9.99;t.updateBoss(.02);assert(t.rs.every(r=>r.state==='jumpTell'&&r.jumpAt===20))});
for(const target of [0,1])check('either living raptor at 150 upgrades both: target '+target,()=>{readyPair();t.rs[target].hp=151;t.updateBoss(0);assert.equal(t.phase,2);t.rs[target].hp=150;t.updateBoss(0);assert.equal(t.phase,3);for(const r of t.rs){assert.equal(r.phase,3);assert.equal(r.robot,true);assert.equal(r.speed,230);assert.equal(r.state,'upgrade')}t.render();t.updateBoss(1.21);t.p.x=1600;t.rs.forEach(r=>r.x=2400);t.updateBoss(.5);assert(t.rs.every(r=>r.x===2285))});
const near=(actual,expected,label)=>assert(Math.abs(actual-expected)<1e-8,`${label}: ${actual} expected ${expected}`);
check('live robot starts at 5 and 7.5, staggered 2.5, repeating every 5 for both',()=>{
 upgrade();t.rs.forEach((r,i)=>{assert.equal(r.elapsed,0);assert.equal(r.rollAt,5+i*2.5)});
 t.updateBoss(1.21);t.p.x=2000;
 const starts=t.rs.map(()=>[]),rolls=t.rs.map(()=>[]),dt=.01;
 // Observe actual state transitions without setting elapsed, rollAt, or attack states.
 for(let step=1;step<=1950;step++){
  const previous=t.rs.map(r=>r.state);t.updateBoss(dt);
  t.rs.forEach((r,i)=>{
   if(r.state==='rollTell'&&previous[i]!=='rollTell'){
    starts[i].push(step*dt);near(r.timer,.65,`${r.id} tell duration`);
    near(r.rollAt,5+i*2.5+starts[i].length*5,`${r.id} next rollAt`);
   }
   if(r.state==='roll'&&previous[i]!=='roll'){rolls[i].push(step*dt);near(r.timer,2.5,`${r.id} roll duration`);assert.equal(Math.abs(r.vx),310)}
   if(previous[i]==='roll'&&r.state!=='roll'){
    const duration=step*dt-rolls[i].at(-1);
    assert(duration>=2.5-1e-8&&duration<=2.5+dt+1e-8,`${r.id} actual roll duration ${duration}`);
   }
  });
 }
 starts.forEach((times,i)=>{
  assert.equal(times.length,3,`${t.rs[i].id} three natural starts`);
  near(times[0],5+i*2.5,`${t.rs[i].id} first start`);
  for(let n=1;n<times.length;n++)near(times[n]-times[n-1],5,`${t.rs[i].id} repeat ${n}`);
  assert.equal(rolls[i].length,3,`${t.rs[i].id} all attacks reach roll`);
 });
 near(starts[1][0]-starts[0][0],2.5,'first-start stagger');
});
for(const target of [0,1])check('robot tell, jump and 310-speed roll lasts 2.5 seconds: '+target,()=>{
 upgrade();t.updateBoss(1.21);t.p.x=1600;const r=t.rs[target],first=5+target*2.5;
 r.elapsed=first-.01;r.x=2600;t.updateBoss(.009);assert.equal(r.state,'walk');
 t.updateBoss(.0011);assert.equal(r.state,'rollTell');assert.equal(r.rollAt,first+5);near(r.timer,.65,'tell duration');t.render();
 t.updateBoss(.66);assert.equal(r.state,'rollJump');assert.equal(r.vy,-1550);t.render();
 for(let i=0;i<100&&r.state!=='roll';i++)t.updateBoss(.01);
 assert.equal(r.state,'roll');assert.equal(Math.abs(r.vx),310);assert.equal(r.timer,2.5);
 const x=r.x;t.updateBoss(.5);near(x-r.x,155,'roll displacement');near(r.timer,2,'remaining roll');t.render();
 t.updateBoss(1.99);assert.equal(r.state,'roll');t.updateBoss(.011);assert.equal(r.state,'walk');
});
for(const variant of ['normal','robot 0','robot 1'])check('actual moving tell and airborne horizontal displacement: '+variant,()=>{
 const rolling=variant!=='normal',target=variant==='robot 1'?1:0;let r;
 if(rolling){upgrade();t.updateBoss(1.21);r=t.rs[target]}else r=fresh();
 t.p.x=1700;r.x=2400;r.elapsed=rolling?r.rollAt:r.jumpAt;t.updateBoss(0);
 const tell=rolling?'rollTell':'jumpTell',jump=rolling?'rollJump':'jump',speed=rolling?230:140;
 assert.equal(r.state,tell);const x=r.x;t.updateBoss(.1);
 assert.equal(r.state,tell);near(x-r.x,speed*.1,'moving tell displacement');assert.equal(r.vx,-speed);
 // The tell must follow the current player rather than retain its initial direction.
 t.p.x=2600;const turnX=r.x;t.updateBoss(.1);assert.equal(r.state,tell);
 near(r.x-turnX,speed*.1,'tell reversal displacement');assert.equal(r.dir,1);
 for(let i=0;i<100&&r.state===tell;i++)t.updateBoss(.01);
 assert.equal(r.state,jump);assert.equal(r.vy,-1550);assert.equal(r.vx,speed);
 const takeoffX=r.x,floor=r.y;t.updateBoss(.05);
 assert.equal(r.state,jump);assert(r.y<floor,'actually airborne');near(r.x-takeoffX,speed*.05,'airborne x displacement');
});
for(const target of [0,1])check('natural roll reverses toward current player, stops without overshoot or wall hit: '+target,()=>{
 upgrade();t.updateBoss(1.21);t.p.x=1600;const r=t.rs[target];r.x=2600;r.elapsed=r.rollAt;t.updateBoss(0);
 assert.equal(r.state,'rollTell');t.updateBoss(.66);assert.equal(r.state,'rollJump');
 for(let i=0;i<100&&r.state!=='roll';i++)t.updateBoss(.01);
 assert.equal(r.state,'roll');const dt=.05;
 const follow=()=>{
  const before=r.x,delta=t.p.x-before,dir=Math.sign(delta);t.updateBoss(dt);
  assert.equal(r.state,'roll');near(r.x,before+dir*Math.min(310*dt,Math.abs(delta)),'current-player tracking');
  assert.equal(r.vx,dir*310);if(dir)assert.equal(r.dir,dir);
  assert(r.x>1575&&r.x<2710,'roll never hits either wall');
 };
 follow();assert.equal(r.dir,-1);
 t.p.x=r.x+80;follow();assert.equal(r.dir,1,'reverses immediately when player changes side');
 for(let i=0;i<5;i++)follow();near(r.x,t.p.x,'stops at player on right');follow();assert.equal(r.vx,0);
 t.p.x=r.x-35;for(let i=0;i<4;i++)follow();near(r.x,t.p.x,'stops at player on left');assert.equal(r.vx,0);
 t.p.x=r.x+7;follow();near(r.x,t.p.x,'sub-step gap cannot overshoot');follow();assert.equal(r.vx,0);
 t.p.x=2700;for(let i=0;i<25;i++)follow();near(r.x,t.p.x,'follows near right wall without hitting it');
 t.p.x=2600;follow();assert.equal(r.dir,-1,'reverses away from nearby wall');
});
check('main dying before howl completion does not skip delayed summon or win',()=>{fresh();t.damageRaptor(t.b,800);assert(t.b.dead);assert(!t.cleared);assert.equal(t.rs.length,1);t.updateBoss(1.61);assert.equal(t.rs.length,2);assert(!t.cleared);t.updateBoss(1);t.rs[1].hp=150;t.updateBoss(0);assert.equal(t.phase,3);assert.equal(t.rs[1].robot,true);assert.equal(t.b.robot,false)});
check('no win until both dead, record once, stage-specific victory UI',()=>{readyPair();const count=t.records[2].clears;t.damageRaptor(t.rs[0],800);assert(t.rs[0].dead);assert(!t.cleared);t.updateBoss(3);assert.equal(t.mode,'playing');t.victory();assert.equal(t.records[2].clears,count);t.damageRaptor(t.rs[1],500);assert(t.cleared);assert.equal(t.records[2].clears,count+1);t.victory();assert.equal(t.records[2].clears,count+1);t.updateBoss(2.4);assert.equal(t.mode,'won');assert.equal(elements.winName.textContent,'울림의 끝');assert.equal(typeof elements.continueJourney.onclick,'function')});
for(const first of [0,1])check('surviving enemy remains independently damageable when first dead: '+first,()=>{readyPair();t.damageRaptor(t.rs[first],1000);const survivor=t.rs[1-first],before=survivor.hp;t.p.x=2000;t.p.dir=1;survivor.x=2080;survivor.y=602;survivor.state='walk';t.keys.attack=true;t.updatePlayer(.01);assert.equal(survivor.hp,before-10);assert(!t.cleared)});
check('melee pierces both: exactly 10 per target per attack, next attack resets targets',()=>{readyPair();t.p.x=2000;t.p.dir=1;t.rs.forEach(r=>{r.x=2080;r.y=602});t.keys.attack=true;t.updatePlayer(.01);assert.equal(t.rs[0].hp,470);assert.equal(t.rs[1].hp,470);t.keys.attack=false;for(let i=0;i<10;i++)t.updatePlayer(.01);assert.equal(t.rs[0].hp,470);assert.equal(t.rs[1].hp,470);t.p.atk=0;t.p.atkCD=0;t.keys.attack=true;t.updatePlayer(.01);assert.equal(t.rs[0].hp,460);assert.equal(t.rs[1].hp,460)});
check('melee may hit second later in same attack without hitting first twice',()=>{readyPair();t.p.x=2000;t.p.dir=1;t.rs[0].x=2080;t.rs[1].x=2400;t.keys.attack=true;t.updatePlayer(.01);t.keys.attack=false;t.rs[1].x=2100;t.updatePlayer(.01);t.updatePlayer(.01);assert.equal(t.rs[0].hp,470);assert.equal(t.rs[1].hp,470)});
check('swept spear pierces both for 60 each and never repeats a hit',()=>{readyPair();t.p.x=2000;t.p.dir=1;t.rs.forEach((r,i)=>{r.x=2100+i*140;r.y=602});assert(t.throwSpear());assert(!t.throwSpear());t.spear.vy=-195;t.updateSpear(.3);assert.equal(t.rs[0].hp,420);assert.equal(t.rs[1].hp,420);assert(t.spear.x>t.rs[1].x);t.spear.vx=-760;t.spear.vy=-195;t.updateSpear(.3);assert.equal(t.rs[0].hp,420);assert.equal(t.rs[1].hp,420);assert.equal(t.spear.hits.size,2)});
check('normal unmodified throw arc hits and pierces compact grounded raptors',()=>{readyPair();t.p.x=1700;t.p.dir=1;t.rs[0].x=2450;t.rs[1].x=2520;t.throwSpear();assert.equal(t.spear.vy,-330);for(let i=0;i<115;i++)t.updateSpear(.01);assert.equal(t.rs[0].hp,420);assert.equal(t.rs[1].hp,420);assert.equal(t.spear.hits.size,2)});
check('actual damage crosses 480 and 150 thresholds, upgrades cannot repeat',()=>{const r=fresh();r.hp=481;t.damageRaptor(r,10);assert.equal(t.phase,2);assert.equal(r.state,'howl');t.updateBoss(1.61);t.updateBoss(1);t.rs[1].hp=151;t.damageRaptor(t.rs[1],10);assert.equal(t.phase,3);assert(t.rs.every(r=>r.robot));t.updateBoss(1.21);t.damageRaptor(r,10);assert.equal(r.state,'walk');assert.equal(t.rs.length,2)});
check('damageRaptor halves 10/60 only in roll, not other robot states',()=>{upgrade();t.updateBoss(1.21);for(const r of t.rs){r.hp=500;for(const state of ['walk','jumpTell','jump','rollTell','rollJump','upgrade','emerge','howl','roll']){r.state=state;for(const amount of [10,60]){const before=r.hp;t.damageRaptor(r,amount);assert.equal(before-r.hp,state==='roll'?amount/2:amount,`${r.id} ${state} damage ${amount}`);r.hp=500}}r.state='dead';r.dead=true;const before=r.hp;t.damageRaptor(r,60);assert.equal(r.hp,before)}});
for(const target of [0,1])check('actual melee deals 5 during roll and 10 after natural roll exit: '+target,()=>{upgrade();t.updateBoss(1.21);t.p.x=2000;t.p.dir=1;const r=t.rs[target],other=t.rs[1-target];other.x=2600;r.hp=500;r.x=2080;r.y=602;r.state='roll';r.timer=.001;r.vx=320;r.dir=1;t.keys.attack=true;t.updatePlayer(.001);assert.equal(r.hp,495);t.keys.attack=false;t.updateBoss(.002);assert.equal(r.state,'walk');t.p.atk=0;t.p.atkCD=0;t.keys.attack=true;t.updatePlayer(.001);assert.equal(r.hp,485);t.keys.attack=false});
for(const target of [0,1])check('actual swept spear deals 30 during roll and 60 after natural roll exit: '+target,()=>{for(const rolling of [true,false]){upgrade();t.updateBoss(1.21);t.p.x=2000;t.p.dir=1;const r=t.rs[target],other=t.rs[1-target],otherHP=other.hp;r.hp=500;r.x=2140;r.y=602;r.state='roll';r.timer=rolling?2.5:.001;r.vx=320;r.dir=1;other.x=2600;if(!rolling){t.updateBoss(.002);assert.equal(r.state,'walk')}assert(t.throwSpear());t.spear.vy=-195;t.updateSpear(.3);assert(t.spear.hits.has(r.id));assert.equal(r.hp,rolling?470:440);assert.equal(other.hp,otherHP,'untouched distant target')}});
for(const rolling of [false,true])check('measured '+(rolling?'rollJump':'normal jump')+' height >160 and airtime <.6 with asymmetric gravity',()=>{let r;if(rolling){upgrade();t.updateBoss(1.21);r=t.rs[0];r.elapsed=5}else{r=fresh();r.elapsed=10}r.x=2400;t.updateBoss(0);assert.equal(r.state,rolling?'rollTell':'jumpTell');t.updateBoss(rolling?.66:.56);const state=rolling?'rollJump':'jump';assert.equal(r.state,state);assert.equal(r.vy,-1550);const floor=r.y,dt=.001;let minY=floor,airtime=0,ascending=false,descending=false;while(r.state===state&&airtime<1){const vy=r.vy;t.updateBoss(dt);airtime+=dt;minY=Math.min(minY,r.y);if(r.state===state){const gravity=vy<0?6500:11000;assert(Math.abs(r.vy-vy-gravity*dt)<1e-8,`gravity at vy=${vy}`);if(vy<0)ascending=true;else descending=true}}const height=floor-minY;assert(ascending&&descending);assert(height>160,`height ${height}`);assert(airtime<.6,`airtime ${airtime}`);assert.equal(r.y,floor);assert.equal(r.state,rolling?'roll':'walk');console.log(`MEASURE: ${state} maxheight=${height.toFixed(3)} airtime=${airtime.toFixed(3)}`)});
check('ally HUD absent before spawn, entity reveal fades 0 to 1 over .7 seconds without numeric HP',()=>{fresh();const capture=()=>{env.draws.length=0;t.hud();return env.draws.slice()},allyDraws=draws=>draws.filter(d=>d.y>=40&&d.y<=70&&d.x>=658&&d.x<=914);assert.equal(allyDraws(capture()).length,0,'no ally name or bar before entity exists');const ally=t.makeRaptor('ally',500,2730);assert.equal(ally.hudReveal,0);t.rs.push(ally);let draws=capture();assert(allyDraws(draws).every(d=>d.alpha===0),'new entity HUD starts invisible');t.updateBoss(.175);assert(Math.abs(ally.hudReveal-.25)<1e-8);t.updateBoss(.175);assert(Math.abs(ally.hudReveal-.5)<1e-8);draws=capture();const half=allyDraws(draws);assert(half.some(d=>d.kind==='text'));assert(half.some(d=>d.kind==='rect'));assert(half.every(d=>Math.abs(d.alpha-.5)<1e-8),'ally label and bar share entity alpha');assert(draws.filter(d=>d.y===47&&d.x<658).every(d=>d.alpha===1),'main HUD remains opaque');t.updateBoss(.35);assert(Math.abs(ally.hudReveal-1)<1e-8);t.updateBoss(.2);assert.equal(ally.hudReveal,1);draws=capture();assert(allyDraws(draws).every(d=>d.alpha===1));for(const d of draws.filter(d=>d.kind==='text'&&d.y<=110))assert(!/\d/.test(d.text),`numeric HUD text: ${d.text}`);t.rs.pop();assert.equal(allyDraws(capture()).length,0,'removed entity leaves no HUD');summon();assert.equal(typeof t.rs[1].hudReveal,'number');assert(t.rs[1].hudReveal>=0&&t.rs[1].hudReveal<.05,'actual summon begins reveal near zero')});
check('all raptor phases use contact 1, including ally when main dead',()=>{for(const phase of [1,2,3]){if(phase===1)fresh();else if(phase===2)readyPair();else{upgrade();t.updateBoss(1.21)}const r=t.rs.at(-1);if(t.rs.length===2)t.damageRaptor(t.rs[0],1000);r.state=phase===3?'roll':'walk';r.x=t.p.x;r.y=602;t.p.inv=0;t.updatePlayer(.001);assert.equal(t.p.hp,5);t.updatePlayer(.001);assert.equal(t.p.hp,5)}});
check('reset and retry restore main 800 only, full player HP, clocks and spear cleared',()=>{upgrade();t.p.hp=1;t.throwSpear();t.retry();assert.equal(t.rs.length,1);assert.equal(t.b.hp,800);assert.equal(t.p.hp,6);assert.equal(t.phase,1);assert.equal(t.b.speed,140);assert.equal(t.b.jumpAt,10);assert.equal(t.b.elapsed,0);assert(!t.summoned);assert(!t.cleared);assert.equal(t.howl,0);assert.equal(t.spear,null);t.reset();assert.equal(t.b.hp,800);assert.equal(t.p.hp,6)});
check('pause and settings freeze stage 2 timers',()=>{fresh();t.updateBoss(2);t.pause();t.step(2);assert.equal(t.b.elapsed,2);t.pause();t.openSettings();t.step(2);assert.equal(t.b.elapsed,2);t.closeSettings();assert.equal(t.mode,'playing')});
check('records isolation, best stars/time, recent10, stage1 legacy migration and persistence',()=>{const legacy={clears:3,bestStars:4,bestTime:42,recent:[{at:Date.now(),hp:5,stars:4,seconds:42}]};const store={'primalJourney.records.v1':JSON.stringify(legacy)},e=boot(store),q=e.t;assert.equal(q.records[1].clears,3);assert.equal(q.records[2].clears,0);for(let i=0;i<12;i++){q.startStage(2);q.p.x=1661;q.updatePlayer(0);q.p.hp=i===0?6:2;q.setTime(100-i);q.damageRaptor(q.b,800);q.updateBoss(1.61);q.damageRaptor(q.rs[1],500);q.victory()}assert.equal(q.records[2].clears,12);assert.equal(q.records[2].bestStars,5);assert.equal(q.records[2].bestTime,89);assert.equal(q.records[2].recent.length,10);assert.equal(q.records[1].clears,3);assert.equal(store['primalJourney.records.v1'],JSON.stringify(legacy));q.startStage(1);q.victory();assert.equal(q.records[1].clears,4);assert.equal(q.records[2].clears,12);const reload=boot(store);assert.equal(reload.t.records[1].clears,4);assert.equal(reload.t.records[2].clears,12);assert.equal(reload.t.records[2].bestTime,89);assert.equal(reload.t.loadRecords(1).bestTime,0);assert.equal(reload.t.loadRecords(2).recent.length,10);assert.equal(JSON.parse(store['primalJourney.records.v2']).unlockedStage2,true);assert.equal(typeof e.elements.continueJourney.onclick,'function')});
check('both render paths and original stage1 HP survive region changes',()=>{t.startStage(1);assert.equal(t.b.hp,1080);assert.equal(t.mode,'cutscene');t.render();t.startStage(2);t.render();t.goHome();t.render()});
// 치고 빠지기 · 협공
const FLOORY=602,DT=1/120;
function runUntil(r,state,limit=10){for(let i=0;i<limit/DT&&r.state!==state;i++)t.updateBoss(DT);assert.equal(r.state,state,`reached ${state}`)}
check('hit-and-run: stalks at distance, .4 bite tell, short lunge, .5 opening, hop back',()=>{
 const r=fresh();t.p.x=2100;t.p.inv=0;t.p.hp=6;
 runUntil(r,'biteTell');const gap=Math.abs(t.p.x-r.x);assert(gap<=240&&gap>=150,`stalk gap ${gap}`);near(r.timer,.4,'bite tell');
 runUntil(r,'bite');const from=r.x;runUntil(r,'recover');
 const lunge=Math.abs(r.x-from);assert(lunge>100&&lunge<=170,`lunge ${lunge}`);assert(Math.abs(t.p.x-r.x)>=19.9,'lunge stops in front of the player');
 assert.equal(t.p.hp,5,'bite deals 1');const hold=r.x;t.updateBoss(.49);assert.equal(r.state,'recover');assert.equal(r.x,hold,'stands still during opening');
 t.updateBoss(.02);assert.equal(r.state,'retreat');runUntil(r,'walk');assert.equal(r.y,FLOORY);assert(Math.abs(t.p.x-r.x)>=140,'backs away after biting');
});
for(const guard of ['inv','dash'])check('bite respects '+guard,()=>{const r=fresh();t.p.x=2100;t.p.inv=0;t.p.hp=6;runUntil(r,'biteTell');t.p[guard]=guard==='inv'?5:.5;runUntil(r,'recover');assert.equal(t.p.hp,6)});
check('contact damage stays 1 in every new raptor state',()=>{for(const state of ['biteTell','bite','recover','retreat','leapTell','leap']){const r=fresh();r.state=state;r.timer=9;r.from=r.to=t.p.x;r.leapSide=1;r.x=t.p.x;r.y=FLOORY;t.p.inv=0;t.p.dash=0;t.p.hp=6;t.updatePlayer(.001);assert.equal(t.p.hp,5,state)}});
check('pair alternates bites, never bites together, and holds a pincer around an idle player',()=>{
 readyPair();t.p.x=2100;const order=[];let opposite=0,frames=0;
 for(let i=0;i<30/DT;i++){const prev=t.rs.map(r=>r.state);t.updateBoss(DT);
  assert(t.rs.filter(r=>['biteTell','bite'].includes(r.state)).length<=1,'only one biter at a time');
  t.rs.forEach((r,k)=>{if(r.state==='biteTell'&&prev[k]!=='biteTell')order.push(r.id)});
  if(t.rs.every(r=>r.state==='walk')){frames++;if(Math.sign(t.rs[0].x-t.p.x)!==Math.sign(t.rs[1].x-t.p.x))opposite++}}
 assert(order.filter(id=>id==='main').length>=4&&order.filter(id=>id==='ally').length>=4,`both bite: ${order}`);
 let swaps=0;for(let i=1;i<order.length;i++)if(order[i]!==order[i-1])swaps++;assert(swaps/(order.length-1)>=.7,`alternation ${order}`);
 assert(opposite/frames>=.6,`pincer ratio ${opposite/frames}`);
});
check('crossing leap swaps both raptors over the player without touching an idle player',()=>{
 readyPair();t.p.x=2100;t.p.inv=0;t.p.hp=6;let crossed=false;
 for(let i=0;i<20/DT&&!crossed;i++){const prev=t.rs.map(r=>r.state);t.updateBoss(DT);
  if(t.rs.every((r,k)=>r.state==='leapTell'&&prev[k]!=='leapTell')){crossed=true;const sides=t.rs.map(r=>Math.sign(r.x-t.p.x));
   for(let j=0;j<1.2/DT;j++){t.updateBoss(DT);t.p.hp=6;t.p.inv=0;t.updatePlayer(0);if(t.rs.some(r=>r.state==='leap'))assert.equal(t.p.hp,6,'leap arc clears a standing player')}
   t.rs.forEach((r,k)=>{assert.equal(Math.sign(r.x-t.p.x),-sides[k],'landed on the other side');assert.equal(r.y,FLOORY)})}}
 assert(crossed,'crossing leap happened within 20 seconds');
});
check('bites never delay the 10-second jump schedule of phase 1',()=>{const r=fresh();t.p.x=2100;const starts=[];for(let i=1;i<=25/DT;i++){const prev=r.state;t.updateBoss(DT);if(r.state==='jumpTell'&&prev!=='jumpTell')starts.push(r.elapsed)}assert.equal(starts.length,2);starts.forEach((e,i)=>assert(Math.abs(e-10*(i+1))<DT+1e-8,`jump at ${e}`))});
console.log(`All ${checks} raptor checks passed`);
