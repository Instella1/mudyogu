const fs=require('fs'),vm=require('vm'),assert=require('assert');
let js=fs.readFileSync(__dirname+'/../primal-journey.html','utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
js=js.replace(/\}\)\(\);\s*$/,`globalThis.t={reset,start,finishIntro,updateIntro,render,pause,retry,openSettings,closeSettings,throwSpear,updateSpear,updateBoss,updatePlayer,updateLaser,hurt,bossRect,laserHitsPlayer,assignKey,actionFor,clearStarsFor,victory,get spear(){return spear},get introTime(){return introTime},get picked(){return introPicked},get landed(){return introLanded},get p(){return player},get b(){return boss},get mode(){return mode},get keys(){return keys},run(){mode='playing'},step(dt){update(dt)}};})();`);
const grad={addColorStop(){}};const ctx=new Proxy({createLinearGradient:()=>grad,createRadialGradient:()=>grad},{get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});const els={};const el=id=>els[id]??={getContext:()=>ctx,setAttribute(){},classList:{toggle(){}},addEventListener(){},focus(){}};
js=js.replace('globalThis.t={','globalThis.t={loadRecords,get records(){return records},');
const storage={};const box={console,Math,localStorage:{getItem(k){return storage[k]||null},setItem(k,v){storage[k]=v}},document:{getElementById:el,querySelectorAll:()=>[],addEventListener(){}},window:{addEventListener(){}},requestAnimationFrame(){},matchMedia:()=>({matches:false})};vm.createContext(box);vm.runInContext(js,box);const t=box.t;
let n=0;function check(name,f){f();console.log('통과: '+name);n++}
check('체력 변경: 주인공 6 / 보스 1080',()=>{t.reset(true);assert.equal(t.p.hp,6);assert.equal(t.b.hp,1080)});
for(const phase of [2,3])check(`${phase}단계 돌진 주기 7초 및 속도 확인`,()=>{t.reset(true);t.run();t.b.hp=phase===2?700:350;t.updateBoss(.01);t.updateBoss(2);assert.equal(t.b.diveAt,7);t.b.elapsed=5;t.b.state='walk';t.updateBoss(.01);assert.equal(t.b.state,'walk');t.b.elapsed=6.99;t.updateBoss(.02);assert.equal(t.b.state,'diveTell');assert.equal(t.b.diveAt,14);t.updateBoss(.76);assert.equal(t.b.state,'dive');assert.equal(Math.abs(t.b.vx),phase===3?1200:940)});
for(const phase of [1,2,3])for(const x of [1535,2100,2750])check(`${phase}단계, 위치 ${x}: 무입력 대기 시 보스가 피해를 줌`,()=>{t.reset(true);t.run();t.p.x=x;t.b.x=x<2100?2400:1700;t.b.phase=phase;t.b.hp=phase===1?1080:phase===2?700:350;for(let i=0;i<2400&&t.p.hp===6;i++)t.step(1/120);assert(t.p.hp<6,'가만히 있어도 공격을 받아야 함')});
for(const phase of [2,3])for(const x of [1535,2100,2750])check(`${phase}단계, 위치 ${x}: 돌진·레이저·발구르기 없이도 접근 발차기 명중`,()=>{t.reset(true);t.run();t.p.x=x;t.b.x=x<2100?2200:1800;t.b.phase=phase;t.b.hp=phase===2?700:350;t.b.state='walk';t.b.guardAt=999;t.b.diveAt=999;t.b.stompAt=999;for(let i=0;i<2400&&t.p.hp===6;i++){t.updateBoss(1/120);t.updatePlayer(1/120)}assert.equal(t.p.hp,4);assert.equal(Math.abs(t.p.vx),1000);assert(t.b.kick>0)});
check('페이즈 전환 체력 720 / 360',()=>{t.reset(true);t.b.hp=720;t.updateBoss(.016);assert.equal(t.b.phase,2);t.updateBoss(2);t.b.hp=360;t.updateBoss(.016);assert.equal(t.b.phase,3)});
check('돌진 종료 2초 후 레이저 유지',()=>{t.reset(true);t.b.phase=2;t.b.hp=700;t.b.state='dive';t.b.timer=0;t.updateBoss(.01);assert.equal(t.b.laserDelay,2);t.updateLaser(1.99);assert.equal(t.b.laserTime,0);t.updateLaser(.02);assert(t.b.laserTime>0)});
check('키 변경 기능 유지',()=>{assert(t.assignKey('attack','KeyQ'));assert.equal(t.actionFor('KeyQ'),'attack')});
check('레이저 추적 각속도 초당 0.28로 감소',()=>{t.reset(true);t.b.phase=2;t.b.hp=700;t.b.laserTime=2;t.b.laserAngle=0;t.p.x=t.b.x-200;t.updateLaser(.1);assert(Math.abs(t.b.laserAngle)<=.028001);assert(Math.abs(t.b.laserAngle)>.0279)});
check('시작 컷신: 추락·착지·창 줍기·자동 게임 진입',()=>{t.start();assert.equal(t.mode,'cutscene');t.updateIntro(1);t.render();t.updateIntro(2);assert(t.landed);t.render();t.updateIntro(5.8);t.render();t.updateIntro(1);assert(t.picked);t.render();t.updateIntro(4);assert.equal(t.mode,'playing');assert.equal(t.p.x,150);assert.equal(t.p.hp,6)});
check('컷신 건너뛰기와 재도전 시 컷신 생략',()=>{t.start();t.finishIntro();assert.equal(t.mode,'playing');t.retry();assert.equal(t.mode,'playing')});
check('컷신 일시정지 및 설정 복귀 시 진행 지점 유지',()=>{t.start();t.updateIntro(5);t.pause();assert.equal(t.mode,'paused');t.step(.2);assert.equal(t.introTime,5);t.pause();assert.equal(t.mode,'cutscene');t.openSettings();t.closeSettings();assert.equal(t.mode,'cutscene');assert.equal(t.introTime,5)});
check('투척 포물선과 60 피해 및 적 관통·중복피해 방지',()=>{t.reset(true);t.run();t.p.x=2000;t.p.dir=1;t.b.x=2200;t.b.phase=2;t.b.hp=700;t.b.state='walk';assert(t.throwSpear());assert(!t.throwSpear());const initial=t.spear.vy;for(let i=0;i<50;i++)t.updateSpear(.01);assert.equal(t.b.hp,640);assert(t.spear.x>t.b.x);assert(t.spear.vy>initial);for(let i=0;i<10;i++)t.updateSpear(.01);assert.equal(t.b.hp,640);t.render()});
check('창 없는 상태 일반공격 차단, 땅에서 회수 후 공격 복구',()=>{t.p.x=1900;t.keys.attack=true;t.p.atkCD=0;t.updatePlayer(.01);assert.equal(t.p.atk,0);for(let i=0;i<600&&t.spear.state!=='ground';i++)t.updateSpear(.01);assert.equal(t.spear.state,'ground');t.p.x=t.spear.x;t.p.y=602;t.updateSpear(.01);assert.equal(t.spear,null);t.p.atkCD=0;t.updatePlayer(.01);assert(t.p.atk>0)});
check('맵 끝 벽에 3초 박혔다가 바닥으로 낙하',()=>{t.reset(true);t.run();t.p.x=2700;t.p.y=420;t.p.dir=1;t.throwSpear();while(t.spear.state==='flying')t.updateSpear(.01);assert.equal(t.spear.state,'stuck');t.p.x=2000;t.updateSpear(2.99);assert.equal(t.spear.state,'stuck');t.updateSpear(.02);assert.equal(t.spear.state,'falling');for(let i=0;i<300&&t.spear.state!=='ground';i++)t.updateSpear(.01);assert.equal(t.spear.state,'ground');t.retry();assert.equal(t.spear,null)});
check('투척 키 변경 가능',()=>{assert(t.assignKey('throw','KeyV'));assert.equal(t.actionFor('KeyV'),'throw')});
check('남은 체력 6·5·4·3·2·1 별점 5·4·3·2·1·1',()=>{assert.deepEqual([6,5,4,3,2,1].map(t.clearStarsFor),[5,4,3,2,1,1]);for(const hp of [1,2,3,4,5,6]){t.reset(true);t.run();t.p.hp=hp;t.victory();assert.equal((els.clearStars.innerHTML.match(/class="earned"/g)||[]).length,t.clearStarsFor(hp));t.updateBoss(2.4);assert.equal(t.mode,'won');assert(els.clearRating.textContent.includes(`남은 체력 ${hp}칸`))}});
check('클리어 저장·중복 집계 방지·최고별 유지·재로딩 복원',()=>{const before=t.records.clears;t.reset(true);t.run();t.p.hp=6;t.victory();assert.equal(t.records.clears,before+1);t.victory();assert.equal(t.records.clears,before+1);t.reset(true);t.run();t.p.hp=1;t.victory();assert.equal(t.records.bestStars,5);assert.equal(t.records.recent[0].hp,1);const restored=t.loadRecords();assert.equal(restored.clears,before+2);assert.equal(restored.bestStars,5);assert(storage['primalJourney.records.v1']);assert(els.titleRecord.textContent.includes('총'));for(let i=0;i<12;i++){t.reset(true);t.run();t.victory()}assert.equal(t.records.recent.length,10)});
// 발 구르기 충격파 · 방어 반격
const DT=1/120;
function arenaPhase(phase){t.reset(true);t.run();t.b.hp=[0,1080,700,350][phase];t.updateBoss(.01);if(phase>1)t.updateBoss(2);assert.equal(t.b.phase,phase);t.b.state='walk';t.b.x=2300;t.b.guardAt=999;t.b.diveAt=999;t.b.chargeCD=999;t.b.elapsed=3.99;t.b.stompAt=4;t.p.x=2000;t.p.y=602;t.p.vx=0;t.p.inv=0;t.p.hp=6}
for(const phase of [1,2,3])check(`${phase}단계 발 구르기: 0.8초 예고, 양쪽 충격파 ${phase>1?'2번 0.9초 간격':'1번'}, 피해 1`,()=>{
 arenaPhase(phase);t.updateBoss(.02);assert.equal(t.b.state,'stompTell');assert.equal(t.b.timer,.8);assert(Math.abs(t.b.stompAt-(t.b.elapsed+6))<1e-9,'다음 발 구르기 6초 뒤');
 t.updateBoss(.79);assert.equal(t.b.waves.length,0);t.updateBoss(.02);assert.equal(t.b.waves.length,2);assert.deepEqual(t.b.waves.map(w=>w.dir).sort(),[-1,1]);assert(t.b.waves.every(w=>w.speed===(phase===3?650:520)));
 if(phase>1){t.updateBoss(.89);assert.equal(t.b.state,'stomp');t.updateBoss(.02);assert(t.b.waves.length>=3)}
 assert.equal(t.b.state,'recover');
 for(let i=0;i<2/DT;i++){t.updateBoss(DT);t.updatePlayer(DT)}assert.equal(t.p.hp,5,'멈춰 있으면 충격파에 1 피해');
});
for(const phase of [1,2,3])check(`${phase}단계 충격파는 점프로 넘고, 2번째도 착지 후 다시 뛰어 넘음`,()=>{
 arenaPhase(phase);let jumps=0;
 for(let i=0;i<4/DT&&!(i>1/DT&&t.b.state==='walk'&&!t.b.waves.length);i++){if(t.p.ground&&t.b.waves.some(w=>w.dir<0&&w.x>t.p.x&&w.x-t.p.x<w.speed*.29)){t.p.jumpBuffer=.13;jumps++}t.updateBoss(DT);t.updatePlayer(DT);t.p.x=2000;t.p.vx=0}
 assert.equal(t.p.hp,6,phase+'단계 점프로 충격파를 넘음');assert.equal(jumps,phase>1?2:1);assert.equal(t.b.waves.length,0,'충격파는 벽에서 사라짐');
});
check('충격파는 회피·무적을 존중',()=>{for(const guard of ['inv','dash']){arenaPhase(1);t.updateBoss(.02);t.updateBoss(.81);assert.equal(t.b.waves.length,2);for(let i=0;i<1/DT;i++){t.p[guard]=1;t.updateBoss(DT)}assert.equal(t.p.hp,6,guard)}});
check('발 구르기는 방어·엎드린 돌진 예약을 밀지 않음',()=>{for(const phase of [1,2]){arenaPhase(phase);t.b.guardAt=6.4;t.updateBoss(.02);assert.equal(t.b.state,'walk','방어까지 2.5초 이하면 시작 안 함');t.b.guardAt=999;if(phase===2){t.b.diveAt=6.4;t.updateBoss(.02);assert.equal(t.b.state,'walk','돌진까지 2.5초 이하면 시작 안 함')}}});
check('멀리 있으면 발 구르기 안 함, 예약은 사거리 안에 들어오면 발동',()=>{arenaPhase(1);t.p.x=1700;t.updateBoss(.02);assert.notEqual(t.b.state,'stompTell');t.p.x=2000;t.b.x=2300;t.updateBoss(.02);assert.equal(t.b.state,'stompTell')});
for(const phase of [1,2])check(`${phase}단계 방어 중 근접 공격 → 0.25초 예고 후 반격 1 피해, 방어 한 번에 한 번`,()=>{
 arenaPhase(phase);t.b.stompAt=999;t.b.guardAt=4;t.p.x=2180;t.p.dir=1;t.updateBoss(.02);assert.equal(t.b.state,'guard');const hp=t.b.hp;
 t.keys.attack=true;t.p.atkCD=0;t.updatePlayer(.001);t.keys.attack=false;assert.equal(t.b.hp,hp,'방어 중엔 피해 없음');assert.equal(t.b.state,'counterTell');assert.equal(t.b.timer,.25);
 t.updateBoss(.26);assert.equal(t.b.state,'counterSweep');t.updateBoss(.01);assert.equal(t.p.hp,5);assert(Math.abs(t.p.vx)===350,'반격은 일반 넉백');
 t.updateBoss(.21);assert.equal(t.b.state,'recover');t.p.inv=0;t.p.hurt=0;t.p.vx=0;t.p.x=2180;t.p.dir=1;t.p.atk=0;t.p.atkCD=0;t.keys.attack=true;t.updatePlayer(.001);t.keys.attack=false;assert.equal(t.b.hp,hp-10,'반격 뒤 빈틈에 피해');
 t.b.state='guard';t.b.timer=1;t.p.atk=0;t.p.atkCD=0;t.keys.attack=true;t.updatePlayer(.001);t.keys.attack=false;assert.equal(t.b.state,'guard','같은 방어에서 두 번째 반격 없음');
});
check('방어 중 창 던지기는 튕기기만 하고 반격 없음, 반격 판정은 회피 존중',()=>{arenaPhase(1);t.b.stompAt=999;t.b.guardAt=4;t.p.x=2000;t.p.dir=1;t.updateBoss(.02);assert(t.throwSpear());for(let i=0;i<60;i++)t.updateSpear(.01);assert.equal(t.b.state,'guard');assert.equal(t.b.hp,1080);
 t.b.state='counterSweep';t.b.timer=.2;t.b.counterHit=false;t.b.dir=-1;t.p.x=2200;t.p.dash=1;t.updateBoss(.01);assert.equal(t.p.hp,6)});
console.log(`총 ${n}개 검사 통과`);
