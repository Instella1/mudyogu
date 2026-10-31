const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(__dirname+'/../primal-journey.html','utf8');
const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const KEY='primalJourney.progress.v1',REC='primalJourney.records.v1',REC2='primalJourney.records.v2';
function boot(storage={}){
 const gradient={addColorStop(){}},draws=[],events={},els={},writes=[];
 const ctx=new Proxy({createLinearGradient:()=>gradient,createRadialGradient:()=>gradient,fillText:t=>draws.push(t)},{get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 const el=id=>els[id]??={hidden:new RegExp('id="'+id+'"[^>]*\\bhidden').test(html),getContext:()=>ctx,setAttribute(k,v){this[k]=v},classList:{values:new Set(),toggle(k,on){on?this.values.add(k):this.values.delete(k)}},addEventListener(){},focus(){els.focused=this}};
 for(const match of html.matchAll(/\bid="([^"]+)"/g))el(match[1]);
 const box={console,Math,localStorage:{getItem:k=>storage[k]||null,setItem(k,v){writes.push(k);storage[k]=v}},document:{getElementById:el,querySelectorAll:()=>[],addEventListener(){}},window:{addEventListener:(k,f)=>events[k]=f},requestAnimationFrame(){},matchMedia:()=>({matches:false})};
 const js=source.replace(/\}\)\(\);\s*$/,`globalThis.t={...window.primalJourney,pause,retry,reset,enterRegion,restoreProgress,openSettings,closeSettings,requestHome,cancelHome,victory,die,damageRaptor,updateBoss,updatePlayer,throwSpear,saveProgress,recordClear,get p(){return player},get b(){return boss},get rs(){return raptors},get keys(){return keys},get press(){return press},get records(){return stageRecords},get progress(){return progress},get spear(){return spear},get clocks(){return {time,runTime,hitstop,shake,flash}},step:dt=>update(dt)};})();`);
 vm.createContext(box);vm.runInContext(js,box);
 const key=(code,repeat=false)=>{const e={code,repeat,target:els.focused,prevented:false,preventDefault(){this.prevented=true}};events.keydown(e);return e};
 return{t:box.t,els,storage,writes,key,draws};
}
let checks=0;function check(label,f){f();checks++;console.log('통과: '+label)}
const state=e=>e.t.getState();
check('디버그 지역 자유 이동·페이즈 선택·정상 저장 보존',()=>{const e=boot();e.t.start();e.t.finishIntro();const saved=e.storage[KEY],writes=e.writes.length;e.t.toggleDebug();for(const region of [3,2,1,3]){assert(e.t.debugStage(region));assert.equal(state(e).stage,region);assert.equal(state(e).mode,'debug');assert(state(e).arena);assert.equal(e.t.p.hp,6);assert.equal(e.t.b.hp,{1:1080,2:800,3:1100}[region]);assert(e.t.debugPhase(3));assert.equal(region===2?state(e).raptorPhase:e.t.b.phase,3);assert(state(e).debugJourney);assert.equal(e.writes.length,writes)}assert(!e.t.debugStage(5));e.t.closeDebug();assert.equal(state(e).mode,'playing');e.t.goHome();assert.equal(e.storage[KEY],saved);assert.equal(state(e).progress.stage,1);assert(!state(e).debugJourney)});
const play=(e,stage=1)=>{e.t.startStage(stage);if(stage===1)e.t.finishIntro()};
const select=(e,n)=>{if(state(e).mode!=='debug')assert(e.t.toggleDebug());assert(e.t.debugPhase(n))};
check('프테라 디버그 체력 1100/700/400, 최대 체력과 재도전 1100 유지',()=>{
 const e=boot();play(e,3);assert.equal(e.t.b.hp,1100);assert.equal(e.t.b.max,1100);
 for(const n of [3,1,2,3,2,1]){select(e,n);assert.equal(e.t.b.hp,[0,1100,700,400][n]);assert.equal(e.t.b.max,1100);assert.equal(e.t.b.phase,n);assert.equal(e.t.b.robot,n>=2);e.t.closeDebug();e.t.updateBoss(0);assert.equal(e.t.b.phase,n)}
 select(e,3);e.t.closeDebug();e.t.retry();assert.equal(e.t.b.hp,1100);assert.equal(e.t.b.max,1100);assert.equal(e.t.b.phase,1);assert(!e.t.b.robot);
});
check('패널·터치 버튼 기본 숨김, hidden 우선 CSS 및 우측 상단 배치',()=>{
 const e=boot();assert(e.els.debugPanel.hidden);assert(e.els.debugBtn.hidden);assert(html.includes('[hidden]{display:none!important}'));assert(/#debugPanel\{[^}]*right:16px;top:55px/.test(html));assert(html.includes('#shell.at-title #debugBtn'));
 assert(!e.t.toggleDebug());e.key('F2');assert.equal(state(e).mode,'title');e.t.start();e.key('F2');assert.equal(state(e).mode,'cutscene');e.t.pause();assert(!e.t.toggleDebug());e.t.pause();e.t.finishIntro();assert(!e.els.debugBtn.hidden);
});
check('F2·반복 방지·Esc와 터치 열기/닫기: 전투 및 모든 타이머 정지',()=>{
 const e=boot();play(e);e.t.keys.attack=true;e.t.press.jump=true;const before=JSON.stringify(state(e)),clocks=JSON.stringify(e.t.clocks);
 assert(e.key('F2').prevented);assert.equal(state(e).mode,'debug');assert(!e.els.debugPanel.hidden);assert.equal(e.els.debugBtn['aria-expanded'],'true');assert.equal(Object.keys(e.t.keys).length,0);assert.equal(Object.keys(e.t.press).length,0);
 e.key('F2',true);assert.equal(state(e).mode,'debug');e.t.step(3);assert.equal(JSON.stringify(e.t.clocks),clocks);assert.equal(e.t.p.x,JSON.parse(before).player.x);
 for(const k of ['KeyJ','KeyR','KeyF','Space','Enter'])e.key(k);assert.equal(state(e).mode,'debug');assert.equal(Object.keys(e.t.press).length,0);assert.equal(e.key('Enter').prevented,false);assert.equal(e.key('Space').prevented,false);
 e.key('Escape');assert.equal(state(e).mode,'playing');assert(e.els.debugPanel.hidden);assert(!state(e).debugUsed);e.els.debugBtn.onclick();e.els.closeDebug.onclick();assert.equal(state(e).mode,'playing');
});
check('일시정지에서 열고 닫으면 정지 유지, 설정·홈 왕복에 반환 모드 보존',()=>{
 for(const paused of [false,true]){const e=boot();play(e);if(paused)e.t.pause();const expected=paused?'paused':'playing';e.t.toggleDebug();e.t.openSettings();assert.equal(state(e).mode,'settings');assert(e.els.debugPanel.hidden);e.t.closeSettings();assert.equal(state(e).mode,expected);e.t.toggleDebug();e.t.requestHome();assert.equal(state(e).mode,'home');assert(e.els.debugPanel.hidden);e.key('Escape');assert.equal(state(e).mode,expected);e.t.toggleDebug();e.key('Escape');assert.equal(state(e).mode,expected)}
});
for(const stage of [1,2])check(stage+'지역: 모든 단계 즉시 정착·왕복, 접근 중 안전 배치와 체력 유지',()=>{
 const e=boot();play(e,stage);e.t.p.hp=3;
 for(const n of [3,1,2,3,2,1]){
  select(e,n);assert(state(e).arena&&state(e).checkpoint);assert.equal(state(e).cam,1500);assert.equal(e.t.p.x,1750);assert.equal(e.t.p.hp,3);assert.equal(e.t.p.y,602);assert.equal(e.t.b.state,'walk');assert.equal(e.t.b.phase,n);
  if(stage===1){assert.equal(e.t.b.hp,[0,1080,720,360][n]);assert.equal(e.t.b.max,1080);assert.equal(e.t.rs.length,0)}
  else{assert.equal(e.t.rs.length,n===1?1:2);assert.equal(state(e).raptorPhase,n);assert.equal(state(e).summoned,n>=2);assert.equal(state(e).howlRemaining,0);e.t.rs.forEach((r,i)=>{assert.equal(r.hp,i===0?[0,800,480,150][n]:480);assert.equal(r.max,i===0?800:480);assert.equal(r.phase,n);assert.equal(r.robot,n===3);assert.equal(r.speed,[0,140,190,230][n]);assert.equal(r.state,'walk');assert.equal(r.hudReveal,1)})}
  e.t.closeDebug();e.t.step(.01);assert.equal(e.t.b.phase,n);assert.equal(e.t.b.state,'walk');e.t.render();
 }
 assert(state(e).debugUsed&&state(e).debugJourney);assert(e.draws.includes('디버그 테스트 · 기록·진행 저장 제외'));
});
check('이전 변신·레이저·방어·투척·플레이어 동작 타이머 완전 제거',()=>{
 const e=boot();play(e);e.t.throwSpear();Object.assign(e.t.b,{state:'transform',timer:99,transform:99,elapsed:99,guardAt:0,diveAt:0,chargeCD:0,laserDelay:0,laserTime:9,laserWarm:8,laserAngle:2,kick:5,hit:8,vx:1000});Object.assign(e.t.p,{dash:.15,atk:.2,inv:10,hurt:1,vx:850,vy:-500,jumpBuffer:.13});
 select(e,2);for(const key of ['timer','transform','elapsed','laserTime','laserWarm','laserAngle','kick','hit','vx'])assert.equal(e.t.b[key],0,key);assert.equal(e.t.b.laserDelay,-1);assert.equal(e.t.b.guardAt,9);assert.equal(e.t.b.diveAt,7);assert.equal(e.t.b.chargeCD,1.8);assert.equal(e.t.spear,null);for(const key of ['dash','atk','inv','hurt','vx','vy','jumpBuffer'])assert.equal(e.t.p[key],0,key);e.t.closeDebug();e.t.step(.01);assert.equal(e.t.b.phase,2);assert.equal(e.t.b.state,'walk');assert.equal(e.t.b.laserTime,0);
});
check('랩터 이전 울음·등장·강철 전환 제거, 구체 첫 발동 5 / 7.5초 및 5초 반복',()=>{
 const e=boot();play(e,2);e.t.p.x=1661;e.t.updatePlayer(0);e.t.b.hp=480;e.t.updateBoss(0);assert(state(e).howlRemaining>0);select(e,3);assert.equal(state(e).howlRemaining,0);e.t.rs.forEach((r,i)=>{assert.equal(r.elapsed,0);assert.equal(r.jumpAt,10);assert.equal(r.rollAt,5+i*2.5);assert.equal(r.timer,0);assert.equal(r.vy,0)});e.t.closeDebug();
 const starts=[[],[]];for(let step=1;step<=1300;step++){const prev=e.t.rs.map(r=>r.state);e.t.updateBoss(.01);e.t.rs.forEach((r,i)=>{if(r.state==='rollTell'&&prev[i]!=='rollTell')starts[i].push(step/100)})}
 assert.deepEqual(starts,[[5,10],[7.5,12.5]]);select(e,1);e.t.closeDebug();e.t.updateBoss(2);assert.equal(e.t.rs.length,1);assert.equal(state(e).raptorPhase,1);assert(!state(e).summoned);
});
check('단순 패널 열기·닫기는 정상 기록·진행 저장을 막지 않음',()=>{
 const e=boot();play(e);e.t.toggleDebug();assert(!e.t.debugPhase(0));assert(!e.t.debugPhase('2'));e.t.closeDebug();const writes=e.writes.length;e.t.victory();assert.equal(e.t.records[1].clears,1);assert(e.writes.length>writes);assert(e.storage[REC]);assert(JSON.parse(e.storage[KEY]).cleared[1]);assert(!state(e).debugJourney);
});
check('디버그 클리어·재도전·지역 이동 이후도 기록/저장 차단, 홈에서 원본 이어하기 복원',()=>{
  const saved={version:1,stage:1,checkpoint:'camp',cleared:{1:false,2:false,3:false}},legacy={clears:2,bestStars:5,bestTime:32,recent:[{at:Date.now(),hp:6,stars:5,seconds:32}]};
 const e=boot({[KEY]:JSON.stringify(saved),[REC]:JSON.stringify(legacy)});e.els.continue.onclick();const storageBefore=JSON.stringify(e.storage),recordBefore=JSON.stringify(e.t.records),writes=e.writes.length;
 select(e,3);e.t.closeDebug();e.t.retry();assert(state(e).debugJourney);e.t.reset(true);assert(state(e).debugUsed);e.t.victory();e.t.updateBoss(2.4);assert(e.els.clearRating.textContent.includes('기록 제외'));e.t.continueJourney();e.t.p.x=3610;e.t.updatePlayer(0);assert.equal(state(e).stage,2);assert(state(e).debugJourney);
 e.t.p.x=1661;e.t.updatePlayer(0);select(e,3);e.t.closeDebug();e.t.damageRaptor(e.t.rs[0],1000);e.t.damageRaptor(e.t.rs[1],1000);e.t.updateBoss(2.4);e.t.continueJourney();e.t.p.x=3200;e.t.updatePlayer(0);e.t.saveProgress();e.t.recordClear();assert.equal(e.writes.length,writes);assert.equal(JSON.stringify(e.storage),storageBefore);assert.equal(JSON.stringify(e.t.records),recordBefore);
 e.t.goHome();assert.equal(e.writes.length,writes);assert.deepEqual(JSON.parse(JSON.stringify(e.t.progress)),{...saved,cleared:{...saved.cleared,4:false}},'옛 저장은 4지역 미클리어로 이관');assert(!e.els.continue.hidden);assert(e.els.debugPanel.hidden);assert(!state(e).debugJourney);e.els.continue.onclick();assert.equal(state(e).stage,1);assert.equal(e.t.p.x,1430);assert(!state(e).stageCleared);assert.equal(e.t.b.hp,1080);e.t.p.x=1661;e.t.updatePlayer(0);e.t.victory();assert.equal(e.t.records[1].clears,3);assert(e.storage[REC2]);
});
check('저장 없는 테스트는 홈에서 가짜 이어하기를 남기지 않음',()=>{
 const e=boot();e.t.enterRegion(2);select(e,3);e.t.closeDebug();e.t.damageRaptor(e.t.rs[0],1000);e.t.damageRaptor(e.t.rs[1],1000);e.t.goHome();assert.equal(e.t.progress,null);assert(e.els.continue.hidden);assert.equal(e.writes.length,0);assert.equal(e.t.records[2].clears,0);
});
check('새 여행 및 저장 이어하기만 오염 해제, 사망·승리·설정에서 F2 무시',()=>{
 const e=boot();play(e);select(e,3);e.t.closeDebug();e.t.retry();assert(state(e).debugJourney);e.t.start();e.t.finishIntro();assert(!state(e).debugJourney);select(e,2);e.t.closeDebug();e.t.continueSaved();assert(!state(e).debugJourney);assert.equal(e.t.b.phase,1);
 e.t.openSettings();e.key('F2');assert.equal(state(e).mode,'settings');e.t.closeSettings();e.t.victory();e.t.updateBoss(2.4);e.key('F2');assert.equal(state(e).mode,'won');assert(!e.t.debugPhase(1));e.t.start();e.t.finishIntro();e.t.die();e.key('F2');assert.equal(state(e).mode,'dead');
});
console.log(`디버그 검사 ${checks}개 통과`);
