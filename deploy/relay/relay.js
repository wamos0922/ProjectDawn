// Project Dawn crew relay with room codes. Node 18+, no npm packages.
'use strict';
const http = require('http');
const crypto = require('crypto');

const PORT = Number(process.env.PORT || 8090);
const HOST = process.env.HOST || '127.0.0.1';
const MAX_PER_ROOM = 4;
const MAX_MESSAGE = 1 << 20;
const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';   // no I/O/0/1
const rooms = new Map();                               // code -> Map(id -> conn)

// ---- minimal WebSocket
function accept(req, socket) {
  const key = req.headers['sec-websocket-key'];
  if (!key || (req.headers.upgrade || '').toLowerCase() !== 'websocket') { socket.destroy(); return null; }
  const hash = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
  socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n' +
               `Sec-WebSocket-Accept: ${hash}\r\n\r\n`);
  socket.setNoDelay(true);
  const c = { socket, buf: Buffer.alloc(0), frags: [], fragOp: 0, alive: true, open: true, onText: null, onBinary: null, onClose: null };
  socket.on('data', (d) => { c.buf = Buffer.concat([c.buf, d]); parse(c); });
  socket.on('close', () => closeConn(c));
  socket.on('error', () => closeConn(c));
  return c;
}

function parse(c) {
  while (c.buf.length >= 2) {
    const b0 = c.buf[0], b1 = c.buf[1];
    const fin = (b0 & 0x80) !== 0, op = b0 & 0x0f, masked = (b1 & 0x80) !== 0;
    let len = b1 & 0x7f, off = 2;
    if (len === 126) { if (c.buf.length < 4) return; len = c.buf.readUInt16BE(2); off = 4; }
    else if (len === 127) { if (c.buf.length < 10) return; len = Number(c.buf.readBigUInt64BE(2)); off = 10; }
    if (len > MAX_MESSAGE) { c.socket.destroy(); return; }
    const need = off + (masked ? 4 : 0) + len;
    if (c.buf.length < need) return;
    let payload = c.buf.subarray(off + (masked ? 4 : 0), need);
    if (masked) {
      const mask = c.buf.subarray(off, off + 4);
      payload = Buffer.from(payload);
      for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
    }
    c.buf = c.buf.subarray(need);
    if (op === 0x8) { frame(c, 0x8, Buffer.alloc(0)); c.socket.end(); closeConn(c); return; }
    if (op === 0x9) { frame(c, 0xA, payload); continue; }
    if (op === 0xA) { c.alive = true; continue; }
    if (op === 0x1 || op === 0x2) c.fragOp = op;
    if (op <= 0x2) {
      c.frags.push(payload);
      if (fin) {
        const msg = Buffer.concat(c.frags); c.frags = [];
        if (c.fragOp === 0x1) c.onText && c.onText(msg.toString('utf8'));
        else c.onBinary && c.onBinary(msg);
      }
    }
  }
}

function frame(c, op, data) {
  if (!c.open || c.socket.destroyed) return;
  const len = data.length;
  let head;
  if (len < 126) head = Buffer.from([0x80 | op, len]);
  else if (len < 65536) { head = Buffer.alloc(4); head[0] = 0x80 | op; head[1] = 126; head.writeUInt16BE(len, 2); }
  else { head = Buffer.alloc(10); head[0] = 0x80 | op; head[1] = 127; head.writeBigUInt64BE(BigInt(len), 2); }
  c.socket.write(Buffer.concat([head, data]));
}
const text = (c, obj) => frame(c, 0x1, Buffer.from(JSON.stringify(obj)));

function closeConn(c) {
  if (!c.open) return;
  c.open = false;
  c.onClose && c.onClose();
}

// ---- rooms
function newCode() {
  for (let tries = 0; tries < 1000; tries++) {
    let s = '';
    for (let i = 0; i < 4; i++) s += LETTERS[crypto.randomInt(LETTERS.length)];
    if (!rooms.has(s)) return s;
  }
  return null;
}

function newId(room) {
  let id;
  do { id = 2 + crypto.randomInt(2147483000); } while (room.has(id));
  return id;
}

const server = http.createServer((req, res) => {
  let players = 0; for (const r of rooms.values()) players += r.size;
  res.writeHead(200, { 'content-type': 'text/plain' });
  res.end(`Project Dawn relay OK · ${rooms.size} crews · ${players} players\n`);
});

server.on('upgrade', (req, socket) => {
  const c = accept(req, socket); if (!c) return;
  let code = null, id = 0;

  c.onText = (raw) => {
    let m; try { m = JSON.parse(raw); } catch { return; }
    if (code) return;
    if (m.t === 'host') {
      code = newCode();
      if (!code) return text(c, { t: 'error', reason: 'Server is busy, try again.' });
      id = 1;
      rooms.set(code, new Map([[1, c]]));
      text(c, { t: 'ok', id, code, peers: [] });
      log(`room ${code} opened`);
    } else if (m.t === 'join') {
      const want = String(m.code || '').trim().toUpperCase();
      const room = rooms.get(want);
      if (!room) return text(c, { t: 'error', reason: `No crew with code ${want}. Check the code with the host.` });
      if (room.size >= MAX_PER_ROOM) return text(c, { t: 'error', reason: 'That crew is full (4 players).' });
      const asked = Number(m.id);
      code = want;
      id = (Number.isInteger(asked) && asked > 1 && asked < 2147483647 && !room.has(asked)) ? asked : newId(room);
      text(c, { t: 'ok', id, code, peers: [...room.keys()] });
      for (const other of room.values()) text(other, { t: 'peer', id });
      room.set(id, c);
      log(`room ${code} +${id} (${room.size})`);
    }
  };

  c.onBinary = (buf) => {
    if (!code || buf.length < 4) return;
    const room = rooms.get(code); if (!room) return;
    const target = buf.readInt32LE(0);
    const out = Buffer.allocUnsafe(buf.length);
    out.writeInt32LE(id, 0);
    buf.copy(out, 4, 4);
    if (target > 0) { const t = room.get(target); if (t) frame(t, 0x2, out); return; }
    for (const [pid, p] of room) if (pid !== id && pid !== -target) frame(p, 0x2, out);
  };

  c.onClose = () => {
    if (!code) return;
    const room = rooms.get(code); if (!room) return;
    room.delete(id);
    if (id === 1) {
      for (const p of room.values()) { text(p, { t: 'gone', id: 1 }); p.socket.end(); }
      rooms.delete(code);
      log(`room ${code} closed (host left)`);
      return;
    }
    for (const p of room.values()) text(p, { t: 'gone', id });
    log(`room ${code} -${id} (${room.size})`);
  };
});

setInterval(() => {   // drop dead connections
  for (const room of rooms.values()) for (const c of room.values()) {
    if (!c.alive) { c.socket.destroy(); closeConn(c); continue; }
    c.alive = false; frame(c, 0x9, Buffer.alloc(0));
  }
}, 15000);

function log(s) { console.log(new Date().toISOString(), s); }
server.listen(PORT, HOST, () => log(`relay on ${HOST}:${PORT}`));