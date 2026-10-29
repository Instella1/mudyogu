const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(__dirname+'/../primal-journey.html','utf8');
const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const KEY='primalJourney.progress.v1';
function boot(storage={},fail=false,coarse=false){
 const grad={addColorStop(){}},draws=[];
 const ctx=new Proxy({createLinearGradient:()=>grad,createRadialGradient:()=>grad,fillText:t=>draws.push(t)},{get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 const els={},events={},el=id=>els[id]??={getContext:()=>ctx,hidden:false,setAttribute(k,v){this[k]=v},classList:{values:new Set(),toggle(k,on){on?this.values.add(k):this.values.delete(k)}},addEventListener(){},focus(){}};
 let writes=0;
 const box={console,Math,localStorage:{getItem(k){if(fail)throw Error('blocked');return storage[k]||null},setItem(k,v){writes++;if(fail)throw Error('blocked');storage[k]=v}},document:{getElementById:el,querySelectorAll:()=>[],addEventListener(){}},window:{addEventListener:(k,f)=>events[k]=f},requestAnimationFrame(){},matchMedia:q=>({matches:q.includes('coarse')&&coarse})};
 const js=source.replace(/\}\)\(\);\s*$/,`globalThis.t={start,finishIntro,updatePlayer,updateBoss,victory,damageRaptor,continueJourney,restoreProgress,goHome,retry,render,openSettings,closeSettings,get p(){return player},get b(){return boss},get rs(){return raptors},get keys(){return keys},get records(){return stageRecords},get progress(){return progress},getState:window.primalJourney.getState,step:dt=>update(dt)};})();`);
 vm.createContext(box);vm.runInContext(js,box);return{t:box.t,els,storage,events,draws,writes:()=>writes};
}
let n=0;function check(label,f){f();console.log('PASS: '+label);n++}
check('home uses separate confirmation, freezes play and cancel restores prior state',()=>{const e=boot();e.t.start();e.t.finishIntro();e.els.homeBtn.onclick();assert.equal(e.t.getState().mode,'home');assert(e.els.homeConfirm.classList.values.has('open'));assert(!e.els.settings.classList.values.has('open'));const x=e.t.p.x;e.t.step(1);assert.equal(e.t.p.x,x);e.els.cancelHome.onclick();assert.equal(e.t.getState().mode,'playing');assert(!e.els.homeConfirm.classList.values.has('open'));e.t.openSettings();e.els.homeBtn.onclick();e.events.keydown({code:'Escape',preventDefault(){}});assert.equal(e.t.getState().mode,'settings');e.t.closeSettings();e.els.homeBtn.onclick();e.els.confirmHome.onclick();assert.equal(e.t.getState().mode,'title');assert(!e.els.homeConfirm.classList.values.has('open'))});
function walk(e,until,max=2000){e.t.keys.right=true;for(let i=0;i<max&&!until();i++){e.t.p.inv=999;e.t.step(1/60)}e.t.keys.right=false;assert(until(),'walking did not reach destination')}
function clearValley(e){e.t.start();e.t.finishIntro();walk(e,()=>e.t.getState().arena);e.t.victory();e.t.updateBoss(2.4);assert.equal(e.t.getState().mode,'won')}
check('minimal title has no stage selector, dashboard, spoilers or gameplay drawing',()=>{
 const title=html.match(/<div id="title"[\s\S]*?<div id="records"/)[0];
 assert(!/selectStage|stageHeading|stageNote|record-card|controls|스테이지|베타/.test(title));
 assert(!/selectStage|STAGE2_TEST_UNLOCK|nextStage/.test(html));
 const e=boot();assert.equal(e.els.continue.hidden,true);e.t.render();assert.equal(e.draws.length,0);
 assert(html.includes('#shell.at-title #touch'));assert(html.includes('prefers-reduced-motion'));
});
check('new journey resets progression, not legacy best records; continue skips cutscene',()=>{
 const legacy={clears:2,bestStars:5,bestTime:32,recent:[{at:Date.now(),hp:6,stars:5,seconds:32}]};
 const e=boot({'primalJourney.records.v1':JSON.stringify(legacy)});e.els.start.onclick();assert.equal(e.t.getState().mode,'cutscene');assert.equal(e.els.continue.hidden,false);e.t.goHome();e.els.continue.onclick();assert.equal(e.t.getState().mode,'playing');assert.equal(e.t.p.x,150);assert.equal(e.t.records[1].clears,2);e.t.start();assert(!e.t.progress.cleared[1]);assert.equal(e.t.records[1].bestTime,32);
});
check('invalid, stale, impossible and malformed saves do not enable continue',()=>{
  for(const p of ['{bad',JSON.stringify({version:0,stage:1}),JSON.stringify({version:1,stage:3,checkpoint:'entry',cleared:{1:true,2:false}}),JSON.stringify({version:1,stage:2,checkpoint:'camp',cleared:{1:false,2:false}}),JSON.stringify({version:1,stage:1,checkpoint:'passage',cleared:{1:false,2:false}}),JSON.stringify({version:1,stage:2,checkpoint:'entry',cleared:{1:true,2:true}})]){const e=boot({[KEY]:p});assert(e.els.continue.hidden);assert.equal(e.t.restoreProgress(),false)}
});
check('record overlay hides uncleared regions behind ??? and reveals only cleared region',()=>{
 const e=boot();e.els.openRecords.onclick();assert.equal(e.t.getState().mode,'records');assert(e.els.records.classList.values.has('open'));assert(!e.els.caveRecords.innerHTML.includes('울림의 동굴'));assert.equal(e.els.valleyRecordName.textContent,'???');assert.equal(e.els.titleBest.textContent,'???');assert.equal(e.els.titleRecord.textContent,'???');assert(e.els.recordDetails.hidden);assert.equal(e.els.recordList.innerHTML,'');assert.equal(e.t.getState().stage,1);e.events.keydown({code:'Escape'});assert.equal(e.t.getState().mode,'title');clearValley(e);assert.equal(e.els.valleyRecordName.textContent,'잊힌 뿔의 계곡');assert(e.els.titleBest.textContent.includes('★'));assert(e.els.titleRecord.textContent.includes('총 1회'));assert(!e.els.caveRecords.innerHTML.includes('울림의 동굴'));const loaded=boot(e.storage);assert.equal(loaded.els.valleyRecordName.textContent,'잊힌 뿔의 계곡');assert(loaded.els.caveRecords.innerHTML.includes('???'));
});
check('boss win -> overlay -> playable cleared arena -> open gate -> real passage -> dormant approach -> camp -> arena',()=>{
 const e=boot();clearValley(e);const at=e.t.p.x;e.els.continueJourney.onclick();assert.equal(e.t.getState().stage,1);assert.equal(e.t.p.x,at);assert(e.t.b.dead);e.t.step(.1);assert.equal(e.t.getState().mode,'playing');walk(e,()=>e.t.p.x>3000);assert.equal(e.t.getState().stage,1);assert.equal(e.t.progress.checkpoint,'passage');assert(e.t.getState().cam>1500);assert.equal(e.t.rs.length,0);
 const passage=boot({...e.storage});passage.els.continue.onclick();assert.equal(passage.t.p.x,2920);assert(passage.t.b.dead);
 walk(e,()=>e.t.getState().stage===2);assert.deepEqual(JSON.parse(JSON.stringify(e.t.getState().course)).stage,2,'parkour course before the boss');assert.equal(e.t.p.x,120);assert(!e.t.getState().arena);assert.equal(e.t.progress.checkpoint,'entry');e.t.p.x=10400;e.t.p.y=260;e.t.step(.02);assert.equal(e.t.getState().course,null,'course end reached');e.t.step(.02);assert.equal(e.t.p.x,1430);assert(!e.t.getState().arena);assert(!e.t.getState().stageCleared);assert.equal(e.t.rs.length,1);const bossX=e.t.b.x;e.t.step(3);assert.equal(e.t.b.elapsed,0);assert.equal(e.t.b.x,bossX);
 walk(e,()=>e.t.p.x>1450);assert(!e.t.getState().arena);assert.equal(e.t.progress.checkpoint,'camp');assert.equal(e.t.b.elapsed,0);assert.equal(e.t.rs.length,1);
 const restored=boot({...e.storage});restored.els.continue.onclick();assert.equal(restored.t.p.x,1430);assert(!restored.t.b.dead);assert.equal(restored.t.b.hp,800);assert(!restored.t.getState().stageCleared);walk(restored,()=>restored.t.getState().arena);restored.t.step(.1);assert(restored.t.b.elapsed>0);assert.equal(restored.t.rs.length,1);
});
check('cleared save and R preserve win without adding records or reopening overlay',()=>{
 const e=boot();clearValley(e);const count=e.t.records[1].clears;e.t.retry();assert.equal(e.t.getState().mode,'playing');e.t.retry();assert(e.t.b.dead);assert(e.t.getState().stageCleared);e.t.step(4);assert.equal(e.t.getState().mode,'playing');assert.equal(e.t.records[1].clears,count);e.t.goHome();const re=boot({...e.storage});re.els.continue.onclick();assert(re.t.b.dead);assert(re.t.getState().stageCleared);assert.equal(re.t.p.x,2530);re.t.step(4);assert.equal(re.t.getState().mode,'playing');
});
check('uncleared camp retries fresh fight from before gate, preserves progression',()=>{
 const e=boot();e.t.start();e.t.finishIntro();walk(e,()=>e.t.getState().arena);e.t.b.hp=1;e.t.retry();assert.equal(e.t.p.x,1430);assert(!e.t.getState().arena);assert.equal(e.t.b.hp,1080);assert.equal(e.t.progress.checkpoint,'camp');
});
check('cave defeat opens passage and rightward travel enters dormant third region',()=>{
  const e=boot({[KEY]:JSON.stringify({version:1,stage:2,checkpoint:'camp',cleared:{1:true,2:false}})});e.els.continue.onclick();walk(e,()=>e.t.getState().arena);e.t.damageRaptor(e.t.b,800);e.t.updateBoss(1.61);e.t.damageRaptor(e.t.rs[1],500);e.t.updateBoss(2.4);e.els.continueJourney.onclick();walk(e,()=>e.t.p.x>3200);assert.equal(e.t.getState().stage,2);assert.equal(e.t.progress.checkpoint,'passage');const re=boot({...e.storage});re.els.continue.onclick();assert.equal(re.t.p.x,2920);assert(re.t.getState().stageCleared);assert(re.t.rs.every(r=>r.dead));walk(re,()=>re.t.getState().stage===3);assert.equal(re.t.p.x,150);assert.equal(re.t.getState().course.stage,3);assert(!re.t.getState().arena);assert.equal(re.t.b.hp,1100);re.t.step(3);assert.equal(re.t.b.elapsed,0);re.t.p.x=550;re.t.p.y=-5490;re.t.step(.02);assert.equal(re.t.getState().course,null);re.t.step(.02);assert.equal(re.t.progress.checkpoint,'camp');walk(re,()=>re.t.getState().arena);re.t.step(.1);assert(re.t.b.elapsed>0);
});
check('storage errors are graceful and persistence is event-based, not per frame',()=>{
 const e=boot({},true,true);e.t.start();e.t.finishIntro();assert(e.els.journeyStatus.textContent.includes('이번 여행'));e.t.goHome();e.els.continue.onclick();assert.equal(e.t.getState().mode,'playing');
 const normal=boot();normal.t.start();normal.t.finishIntro();const before=normal.writes();for(let i=0;i<300;i++)normal.t.step(1/60);assert.equal(normal.writes(),before);normal.t.goHome();assert.equal(normal.writes(),before+1);
});
console.log(`All ${n} journey checks passed`);
