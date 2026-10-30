const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(__dirname+'/../primal-journey.html','utf8');
const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
// 가짜 네트워크: 같은 방 채널의 다른 참가자에게만 전달(자기 자신 제외), flush 때 도착.
function makeBus(){const topics={},queue=[];return{queue,factory(topic,onMsg,onStatus){const subs=topics[topic]??=[];const me={onMsg,onStatus,open:true};subs.push(me);queue.push(()=>me.open&&onStatus('joined'));return{send(m){const copy=JSON.parse(JSON.stringify(m));for(const s of subs)if(s!==me)queue.push(()=>s.open&&s.onMsg(copy))},close(){me.open=false}}},flush(){let n=0;while(queue.length&&n<5000){queue.shift()();n++}}}}
function boot(bus,storage={}){
 const gradient={addColorStop(){}},draws=[],els={};
 const ctx=new Proxy({createLinearGradient:()=>gradient,createRadialGradient:()=>gradient,fillText(text,x,y){draws.push({text:String(text),x,y})}},{get:(o,k)=>o[k]||(()=>{}),set:(o,k,v)=>(o[k]=v,true)});
 const el=id=>els[id]??={hidden:false,value:'',innerHTML:'',textContent:'',getContext:()=>ctx,setAttribute(k,v){this[k]=v},classList:{toggle(){},add(){},remove(){}},addEventListener(){},focus(){}};
 const events={};const box={console,Math,JSON,localStorage:{getItem:k=>storage[k]||null,setItem(k,v){storage[k]=v}},document:{getElementById:el,querySelectorAll:()=>[],addEventListener(){}},window:{addEventListener:(k,f)=>events[k]=f},requestAnimationFrame(){},matchMedia:()=>({matches:false}),setTimeout,setInterval:()=>0,clearInterval(){}};
 const js=source.replace(/\}\)\(\);\s*$/,`globalThis.t={...window.primalJourney,updatePlayer,killerTrap,trapLive,trapGeom,activateTrap,onlineUnlocked,runBlocks:()=>[...COURSES.run.blocks,...trapFloors().map(f=>[f.x,f.y,f.w,20])],refreshContinue,supabaseTransport,get o(){return online},get p(){return player},get cam(){return cam},get mode(){return mode},get keys(){return keys},get press(){return press},get run(){return courseRun},get records(){return stageRecords},tick:dt=>update(dt)};})();`);
 vm.createContext(box);vm.runInContext(js,box);if(bus)box.t.online.setTransport(bus.factory);return{t:box.t,els,draws,events,box};
}
let count=0;function check(label,f){f();console.log('PASS: '+label);count++}
const DT=1/30;
function step(bus,cs,seconds){for(let i=0;i<Math.round(seconds/DT);i++){for(const c of cs){if(c.t.o&&c.t.o.round&&c.t.o.round.state[c.t.o.me]&&c.t.mode==='playing'){c.t.p.inv=Math.max(c.t.p.inv,c.keepInv||0)}c.t.tick(DT)}bus.flush()}}
function room(n){const bus=makeBus(),cs=[];const host=boot(bus);host.t.online.create('방장');bus.flush();cs.push(host);const code=host.t.o.code;for(let i=1;i<n;i++){const c=boot(bus);c.t.online.join('친구'+i,code);cs.push(c);bus.flush();bus.flush()}step(bus,cs,.2);return{bus,cs,host,code}}
const state=c=>c.t.online.state();

check('every element id the script looks up exists in the page (the test mock would hide a typo)',()=>{
 const ids=new Set([...html.matchAll(/id="([^"]+)"/g)].map(m=>m[1])),used=new Set([...source.matchAll(/\$\('([A-Za-z0-9_-]+)'\)/g)].map(m=>m[1]));
 const dynamic=['debugPhase','debugStage','trap-'];const missing=[...used].filter(id=>!ids.has(id)&&!dynamic.some(d=>id===d));assert.deepEqual(missing,[])});
check('unlocked only after clearing region 4; the title button appears then',()=>{
 const a=boot(null);a.t.refreshContinue();assert.equal(a.els.onlineBtn.hidden,true);
 const b=boot(null,{'primalJourney.records.v2':JSON.stringify({stages:{4:{clears:1,bestStars:3,bestTime:200,recent:[]}}})});b.t.refreshContinue();assert.equal(b.els.onlineBtn.hidden,false);assert(b.t.onlineUnlocked())});
check('host makes a 4-letter room; friends join with the code; everyone sees the same roster',()=>{
 const {cs,code}=room(4);assert(/^[A-Z]{4}$/.test(code));for(const c of cs){const s=state(c);assert.equal(s.phase,'lobby');assert.equal(s.players.length,4);assert.deepEqual(s.players.map(p=>p.name),['방장','친구1','친구2','친구3'])}assert(state(cs[0]).isHost);assert(!state(cs[1]).isHost)});
check('a ninth player is turned away: the room holds at most 8',()=>{
 const {bus,cs,code}=room(8);assert.equal(state(cs[0]).players.length,8);const late=boot(bus);late.t.online.join('늦은이',code);bus.flush();bus.flush();assert.equal(state(late).phase,'closed');assert(state(late).notice.includes('가득'));assert.equal(state(cs[0]).players.length,8)});
check('a wrong code ends with a clear message after 6 seconds',()=>{const bus=makeBus(),c=boot(bus);c.t.online.join('혼자','ZZZZ');step(bus,[c],6.5);assert.equal(state(c).phase,'closed');assert(state(c).notice.includes('찾지 못'))});
check('start needs 2+ players; round 1 picks one killer, same on every screen, then a 3s countdown',()=>{
 const solo=room(1);assert.equal(solo.host.t.online.start(),false);
 const {bus,cs}=room(4);assert(cs[0].t.online.start());bus.flush();const k=state(cs[0]).round.killer;for(const c of cs){const s=state(c);assert.equal(s.phase,'countdown');assert.equal(s.round.killer,k);assert.equal(s.round.runners.length,3);assert(!s.round.runners.includes(k))}
 step(bus,cs,3.1);for(const c of cs)assert.equal(state(c).phase,'run')});
function started(n=3){const r=room(n);r.cs[0].t.online.start();r.bus.flush();step(r.bus,r.cs,3.05);const k=state(r.cs[0]).round.killer;r.killer=r.cs.find(c=>state(c).me===k);r.runners=r.cs.filter(c=>c!==r.killer);return r}
check('screen scrolls on its own; runners broadcast positions ~5 times a second and others see them',()=>{
 const r=started(3),[a,b]=r.runners;const cam0=a.t.cam;step(r.bus,r.cs,2);assert(a.t.cam>cam0+90,'auto scroll');a.t.keys.right=true;step(r.bus,r.cs,1);a.t.keys.right=false;
 const seen=b.t.o.remote[state(a).me];assert(seen&&seen.length>=3,'position updates');assert(Math.abs(seen[seen.length-1].x-a.t.p.x)<90,'within one send interval')});
check('killer triggers on-screen traps 1-4 for everyone; a falling rock costs a runner a life and they respawn in the sky',()=>{
 const r=started(3),[a,b]=r.runners;const traps=a.t.run.trap;const rockIdx=a.t.o&&0;// 첫 바위(x 500)
 const k=r.killer.t;step(r.bus,r.cs,.5);a.t.p.x=500;a.t.p.y=602;a.t.p.vx=0;a.t.p.inv=0;
 assert(k.killerTrap('rock'));assert.equal(k.killerTrap('rock'),false,'cooldown');r.bus.flush();assert(a.t.trapLive(0)>=0&&b.t.trapLive(0)>=0,'trap active on every screen');
 for(let i=0;i<40&&state(a).round.state[state(a).me].lives===3;i++){a.t.p.x=500;a.t.p.y=602;a.t.p.vx=0;step(r.bus,r.cs,DT)}
 const s=state(a).round.state[state(a).me];assert.equal(s.lives,2);assert(Math.abs(a.t.p.x-(a.t.cam+640))<20,'respawn at screen center');assert(a.t.p.y<300,'in the sky');assert(a.t.p.inv>1)});
check('spikes, mace and the trap floor work and only fire while on screen',()=>{
 const r=started(2),k=r.killer.t,a=r.runners[0].t;assert.equal(k.killerTrap('mace'),true,'mace at x1000 is on screen at the start');
 r.bus.flush();const g=a.trapGeom(2,1);assert(g.ball&&g.r===26);assert.equal(k.killerTrap('floor'),false,'no trap floor on the first screen yet')});
check('three lives lost = out; standing still gets crushed by the left edge',()=>{
 const r=started(2),a=r.runners[0];for(let i=0;i<300&&!state(a).round.state[state(a).me].out;i++){a.t.p.vx=0;a.t.keys.right=false;a.t.p.inv=0;step(r.bus,r.cs,DT*3)}
 assert(state(a).round.state[state(a).me].out,'out after 3 lives');assert(state(r.cs[0]).round.state[state(a).me].out,'host knows')});
check('with an idle killer, a runner who jumps the pits and steps finishes inside 90 seconds',()=>{
 const r=started(2),a=r.runners[0];
 const host=r.cs[0];let jumpedAt=-1;
 for(let i=0;i<Math.round(92/DT)&&state(host).phase==='run';i++){const p=a.t.p;a.t.keys.right=true;
  const ahead=p.x+40,bl=a.t.runBlocks(),support=bl.some(b=>ahead>=b[0]&&ahead<=b[0]+b[2]&&Math.abs(b[1]-p.y)<3),wall=bl.some(b=>ahead>=b[0]&&ahead<=b[0]+b[2]&&b[1]<p.y-3);
  // 착지할 땅이 아직 화면 밖이면(화면 오른쪽 끝에 막혀 떨어진다) 구덩이 앞에서 기다린다.
  const land=bl.filter(b=>b[0]>p.x&&b[1]>=p.y-110).map(b=>b[0]).sort((x,y)=>x-y)[0]??Infinity;if(p.ground&&!support&&land+40>a.t.cam+1260){a.t.keys.right=false;a.t.p.vx=0}
  else if(p.ground&&(!support||wall)){a.t.press.jump=true;jumpedAt=i}else if(!p.ground&&p.jumps===1&&p.vy>-60&&i-jumpedAt>4){a.t.press.jump=true}
  step(r.bus,r.cs,DT);a.t.press.jump=false}
 a.t.keys.right=false;const me=state(a).round.state[state(a).me];assert(me.fin,'finished with '+me.lives+' lives');assert.equal(me.lives,3,'no life lost without traps')});
check('round end: unfinished runners are eliminated; if nobody is eliminated the killer is; last one standing wins',()=>{
 const r=started(3),[a,b]=r.runners;const host=r.cs[0];
 // a 는 끝까지 완주, b 는 탈락
 for(let i=0;i<Math.round(90/DT)&&state(host).phase==='run';i++){a.t.p.inv=99;a.t.p.x=Math.max(a.t.p.x,a.t.cam+300);a.t.p.y=Math.min(a.t.p.y,602);if(a.t.cam>4200){a.t.p.x=5470;a.t.p.y=602}b.t.p.inv=0;b.t.p.vx=0;step(r.bus,r.cs,DT)}
 const res=state(host).round.result;assert(res,'round ended');assert.deepEqual(res.elim,[state(b).me]);assert(!res.winner);
 for(const c of r.cs)assert.equal(state(c).phase,'result');step(r.bus,r.cs,5.2);
 const two=state(host).round;assert.equal(two.no,2);assert.equal(two.runners.length+1,2,'two players left: one killer, one runner');
 // 2라운드: 아무도 탈락하지 않으면 킬러가 탈락 → 우승자 결정
 step(r.bus,r.cs,3.1);const runner=r.cs.find(c=>state(c).me===two.runners[0]);
 for(let i=0;i<Math.round(90/DT)&&state(host).phase==='run';i++){runner.t.p.inv=99;runner.t.p.x=Math.max(runner.t.p.x,runner.t.cam+300);runner.t.p.y=Math.min(runner.t.p.y,602);if(runner.t.cam>4200){runner.t.p.x=5470;runner.t.p.y=602}step(r.bus,r.cs,DT)}
 const res2=state(host).round.result;assert.deepEqual(res2.elim,[two.killer]);assert.equal(res2.winner,two.runners[0]);step(r.bus,r.cs,5.2);
 for(const c of r.cs){assert.equal(state(c).phase,'over');assert.equal(c.t.mode,'online')}
 assert(host.t.online.restart());r.bus.flush();for(const c of r.cs)if(state(c).phase!=='closed')assert.equal(state(c).phase,'lobby')});
check('90 seconds run out: everyone not at the finish line is eliminated',()=>{
 const r=started(3),host=r.cs[0];for(const c of r.runners)c.keepInv=99;step(r.bus,r.cs,91);const res=state(host).round.result;assert(res);assert.equal(res.elim.length,2)});
check('host leaving closes the room for everyone; a silent host times out after 6s',()=>{
 const {bus,cs}=room(3);cs[0].t.online.leave();bus.flush();assert.equal(state(cs[1]).phase,'closed');assert(state(cs[1]).notice.includes('방장'));
 const r2=room(2);r2.cs[0].t.online.setTransport(()=>({send(){},close(){}}));for(let i=0;i<Math.round(7/DT);i++){r2.cs[1].t.tick(DT);r2.bus.flush()}assert.equal(state(r2.cs[1]).phase,'closed')});
check('a friend leaving: removed in the lobby, eliminated during a match; joining a running match is refused',()=>{
 const {bus,cs,code}=room(3);cs[2].t.online.leave();bus.flush();assert.equal(state(cs[0]).players.length,2);
 const r=started(3),gone=r.runners.find(c=>c!==r.cs[0]);gone.t.online.leave();r.bus.flush();const hs=state(r.cs[0]);const leftP=hs.players.find(p=>p.left);assert(leftP&&!leftP.alive,'marked as left and eliminated');assert.equal(hs.round.state[leftP.id].out,true,'counts as out in this round');
 const late=boot(r.bus);late.t.online.join('늦은이',r.code);r.bus.flush();r.bus.flush();assert.equal(state(late).phase,'closed');assert(state(late).notice.includes('시작'))});
check('pause, retry and debug are blocked during a match; Esc does not freeze the shared game',()=>{
 const r=started(2),a=r.runners[0];a.events.keydown({code:'Escape',preventDefault(){},repeat:false});assert.equal(a.t.mode,'playing');a.events.keydown({code:'KeyR',preventDefault(){},repeat:false});assert.equal(state(a).phase,'run');
 r.killer.events.keydown({code:'Digit2',preventDefault(){},repeat:false});assert(r.killer.t.o.cool.spike>0,'killer key 2 fires spikes')});
check('every online screen renders without errors (lobby, countdown, run as killer/runner, result, over)',()=>{
 const r=started(3);for(const c of r.cs)c.t.render();step(r.bus,r.cs,1);for(const c of r.cs){c.draws.length=0;c.t.render();assert(c.draws.some(d=>d.text.includes('원시런')))}assert(r.killer.draws.some(d=>d.text.includes('킬러')))});
check('Supabase Realtime wire format: join with broadcast config, heartbeat topic, broadcast event m',()=>{
 const sent=[];let sock;class FakeWS{constructor(url){sock=this;this.url=url;this.readyState=0}send(s){sent.push(JSON.parse(s))}close(){}}
 const e=boot(null);e.box.WebSocket=FakeWS;const got=[],st=[];const tx=e.t.supabaseTransport('pj-ABCD',m=>got.push(m),s=>st.push(s));
 assert(sock.url.startsWith('wss://nvpvdkxovknhqglfbhmv.supabase.co/realtime/v1/websocket?apikey='));assert(sock.url.endsWith('&vsn=1.0.0'));
 tx.send({k:'hello',from:'a'});assert.equal(sent.length,0,'queued until open');sock.readyState=1;sock.onopen();
 assert.equal(sent[0].event,'phx_join');assert.equal(sent[0].topic,'realtime:pj-ABCD');assert.equal(sent[0].payload.config.broadcast.self,false);assert.equal(sent[1].event,'broadcast');assert.deepEqual(sent[1].payload,{type:'broadcast',event:'m',payload:{k:'hello',from:'a'}});
 sock.onmessage({data:JSON.stringify({topic:'realtime:pj-ABCD',event:'phx_reply',payload:{status:'ok'}})});assert.deepEqual(st,['joined']);
 sock.onmessage({data:JSON.stringify({topic:'realtime:pj-ABCD',event:'broadcast',payload:{type:'broadcast',event:'m',payload:{k:'pos',from:'b'}}})});assert.deepEqual(got,[{k:'pos',from:'b'}]);
 sock.onmessage({data:JSON.stringify({topic:'realtime:other',event:'broadcast',payload:{type:'broadcast',event:'m',payload:{k:'x'}}})});assert.equal(got.length,1,'other topics ignored')});
check('the journey save is untouched by online play',()=>{const storage={};const r={bus:makeBus()};const h=boot(r.bus,storage);h.t.online.create('a');const before=storage['primalJourney.progress.v1'];h.t.online.leave();assert.equal(storage['primalJourney.progress.v1'],before);assert.equal(h.t.mode,'title')});
console.log(`All ${count} online checks passed`);
