// Runs the HTML demo's own world-map code (c1,c9,c2,c3,c4) with a tiny canvas stub,
// then writes each world's map layers as PNG + a JSON of rooms/edges/labels for Godot.
const fs=require('fs'),vm=require('vm'),zlib=require('zlib');
const V='/home/claude/v2/';
let src=fs.readFileSync(V+'c1.js','utf8').replace('__SPRITES__',fs.readFileSync('/home/claude/demo/sprites.json','utf8')).replace('<script>','')+fs.readFileSync(V+'c9.js','utf8')+fs.readFileSync(V+'c2.js','utf8')+fs.readFileSync(V+'c3.js','utf8')+fs.readFileSync(V+'c4.js','utf8');
const W=320,H=180;
function parse(c){if(typeof c!=='string')return [0,0,0,0];c=c.trim();
  if(c[0]==='#'){if(c.length===4)c='#'+c[1]+c[1]+c[2]+c[2]+c[3]+c[3];const n=parseInt(c.slice(1,7),16);return [n>>16,(n>>8)&255,n&255,c.length>7?parseInt(c.slice(7,9),16)/255:1];}
  const m=c.match(/rgba?\(([^)]*)\)/);if(m){const p=m[1].split(',').map(Number);return [p[0],p[1],p[2],p.length>3?p[3]:1];}
  return [255,0,255,1];}
function makeCtx(){const buf=new Float32Array(W*H*4);const g={buf,fillStyle:'#000',globalAlpha:1,imageSmoothingEnabled:false,
  fillRect(x,y,w,h){const [r,gg,b,a0]=parse(this.fillStyle);const a=a0*this.globalAlpha;x=Math.round(x);y=Math.round(y);w=Math.round(w);h=Math.round(h);
    if(w<0){x+=w;w=-w;}if(h<0){y+=h;h=-h;}
    for(let j=Math.max(0,y);j<Math.min(H,y+h);j++)for(let i=Math.max(0,x);i<Math.min(W,x+w);i++){const k=(j*W+i)*4;
      const da=buf[k+3],oa=a+da*(1-a);if(oa<=0)continue;buf[k]=(r*a+buf[k]*da*(1-a))/oa;buf[k+1]=(gg*a+buf[k+1]*da*(1-a))/oa;buf[k+2]=(b*a+buf[k+2]*da*(1-a))/oa;buf[k+3]=oa;}},
  clearRect(){buf.fill(0);},save(){},restore(){},beginPath(){},fill(){},stroke(){},arc(){},moveTo(){},lineTo(){},drawImage(){},fillText(){},setTransform(){},translate(){},scale(){}};return g;}
const anyStub=new Proxy(function(){},{get:(t,k)=>k===Symbol.toPrimitive?(()=>0):(k==='getContext'?()=>makeCtx():(k==='clientWidth'?1280:anyStub)),apply:()=>anyStub,construct:()=>anyStub,set:()=>true});
const doc={getElementById:()=>({getContext:()=>makeCtx(),style:{},addEventListener(){},appendChild(){},clientWidth:1280,classList:{add(){},remove(){},toggle(){}}}),
  createElement:()=>({getContext:()=>makeCtx(),style:{},width:0,height:0,append(){},appendChild(){},addEventListener(){},classList:{add(){},remove(){},toggle(){}},setAttribute(){},insertAdjacentHTML(){}}),
  documentElement:{style:{setProperty(){}}},body:anyStub,querySelector:()=>null,querySelectorAll:()=>[],addEventListener(){}};
const ctxObj={document:doc,window:{},matchMedia:()=>({matches:false}),ResizeObserver:function(){this.observe=()=>{}},requestAnimationFrame(){},setTimeout(){},setInterval(){},addEventListener(){},
  localStorage:{getItem:()=>null,setItem(){}},navigator:{},performance:{now:()=>0},Image:function(){},console,Math,JSON,Object,Array,Uint8Array,Float32Array,Set,Map,Promise,location:{search:'',hash:''},URLSearchParams:function(){this.get=()=>null}};
ctxObj.window=ctxObj;
// stop before the IIFE end: export what we need
const hook=`\n;globalThis.__X={world,DEFS,G,TONES,inside,isLocked,toneOf,P};\n`;
src=src+hook+'})();';
vm.createContext(ctxObj);
try{vm.runInContext(src,ctxObj,{filename:'demo.js'});}catch(e){console.error('ERR',e.stack.split('\n').slice(0,4).join('\n'));process.exit(1);}
const X=ctxObj.__X;
function png(buf,file){const raw=Buffer.alloc((W*4+1)*H);for(let y=0;y<H;y++){raw[y*(W*4+1)]=0;for(let x=0;x<W*4;x++)raw[y*(W*4+1)+1+x]=Math.round(Math.min(255,x%4===3?buf[y*W*4+x]*255:buf[y*W*4+x]));}
  const crc=(b)=>{let c,t=[];for(let n=0;n<256;n++){c=n;for(let k=0;k<8;k++)c=c&1?0xedb88320^(c>>>1):c>>>1;t[n]=c>>>0;}let r=-1;for(const x of b)r=t[(r^x)&255]^(r>>>8);return (r^-1)>>>0;};
  const chunk=(ty,d)=>{const l=Buffer.alloc(4);l.writeUInt32BE(d.length);const td=Buffer.concat([Buffer.from(ty),d]);const c=Buffer.alloc(4);c.writeUInt32BE(crc(td));return Buffer.concat([l,td,c]);};
  const ih=Buffer.alloc(13);ih.writeUInt32BE(W,0);ih.writeUInt32BE(H,4);ih[8]=8;ih[9]=6;
  fs.writeFileSync(file,Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ih),chunk('IDAT',zlib.deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]));}
const out={};const OUT=process.argv[2]||'.';
for(const wk of ['earth','moon','mars']){
  const D=X.DEFS[wk];
  for(const variant of [0,1]){
    X.G.hydro=!!variant;
    // layer "under": base + corridors (what buildWorld paints before the rooms)
    const W0=X.world(wk);
    const under=makeCtx();D.paintBase(under);
    const ROOM=W0.ROOM;
    for(let i=0;i<W*H;i++)if(W0.IDG[i]===200){const x=i%W,y=(i/W)|0;under.fillStyle=((x+y)&3)?D.cor[0]:D.cor[1];under.fillRect(x,y,1,1);}
    for(const e of D.edges){if(e[4]&&e[4].when&&!e[4].when())continue;if(e[4]&&e[4].surface)continue;const A=ROOM[e[0]],B=ROOM[e[1]];const n=Math.hypot(B.cx-A.cx,B.cy-A.cy)/6;for(let i=1;i<n;i++){const x=A.cx+(B.cx-A.cx)*i/n,y=A.cy+(B.cy-A.cy)*i/n;under.fillStyle=D.corLine;under.fillRect(x|0,y|0,2,1);}}
    const over=makeCtx();D.furnish&&D.furnish(over);
    const sfx=variant?'_h':'';
    if(variant&&wk!=='earth')continue;
    png(under.buf,`${OUT}/${wk}_under${sfx}.png`);png(over.buf,`${OUT}/${wk}_over${sfx}.png`);
  }
  X.G.hydro=false;const W0=X.world(wk);
  out[wk]={rooms:W0.rooms.map(r=>({k:r.k,name:r.name,shape:r.shape,tone:r.tone,utone:r.utone||null,cx:r.cx,cy:r.cy,bb:r.bb,lock:r.lock||null})),
    edges:D.edges.map(e=>({a:e[0],b:e[1],surface:!!(e[4]&&e[4].surface),when:!!(e[4]&&e[4].when)})),
    labelY:D.labelY||{},labels:D.labels||[]};
}
out.tones={};for(const k in X.TONES)out.tones[k]=X.TONES[k];
fs.writeFileSync(`${OUT}/map.json`,JSON.stringify(out,null,1));console.log('ok');
