"""Single-port HTTP health endpoint and WebSocket proxy for free web hosting."""
import asyncio,contextlib,os,signal,socket

async def main():
 public_port=int(os.environ.get('PORT','10000'))
 internal_port=public_port+1
 child_env=dict(os.environ,PORT=str(internal_port),GAME_SERVER='1',GAME_BIND_ADDRESS='127.0.0.1')
 binary=os.environ.get('GAME_SERVER_BINARY','/app/GameForMe-Server')
 process=await asyncio.create_subprocess_exec(binary,'--headless',env=child_env)
 stopping=asyncio.Event();ready=False;connections=0
 async def watch():
  await process.wait();stopping.set()
 async def readiness():
  nonlocal ready
  while process.returncode is None and not stopping.is_set():
   try:
    _,writer=await asyncio.open_connection('127.0.0.1',internal_port)
    writer.close();await writer.wait_closed();ready=True;return
   except OSError:await asyncio.sleep(.15)
 async def relay(reader,writer):
  while data:=await reader.read(65536):
   writer.write(data);await writer.drain()
 async def handle(reader,writer):
  nonlocal connections
  connections+=1
  backend=None
  try:
   if connections>64:return
   header=await asyncio.wait_for(reader.readuntil(b'\r\n\r\n'),10)
   lines=header.split(b'\r\n');request=lines[0].split()
   fields={}
   for line in lines[1:]:
    if b':' in line:
     key,value=line.split(b':',1);fields[key.strip().lower()]=value.strip().lower()
   if len(request)!=3:return
   if fields.get(b'upgrade')==b'websocket' and ready:
    backend_reader,backend=await asyncio.open_connection('127.0.0.1',internal_port)
    backend.write(header);await backend.drain()
    jobs=[asyncio.create_task(relay(reader,backend)),asyncio.create_task(relay(backend_reader,writer))]
    try:
     _,pending=await asyncio.wait(jobs,return_when=asyncio.FIRST_COMPLETED)
     for job in pending:job.cancel()
     await asyncio.gather(*jobs,return_exceptions=True)
    finally:
     for job in jobs:job.cancel()
    return
   healthy=ready and process.returncode is None
   ok=request[1] in [b'/',b'/healthz'] and healthy
   status=b'200 OK' if ok else b'503 Service Unavailable'
   body=(b'GameForMe server ready. Connect from the game using F8 and the wss:// address of this service.' if ok else b'Game server starting. Retry shortly.')
   writer.write(b'HTTP/1.1 '+status+b'\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\nContent-Length: '+str(len(body)).encode()+b'\r\n\r\n')
   if request[0]!=b'HEAD':writer.write(body)
   await writer.drain()
  except (OSError,asyncio.TimeoutError,asyncio.IncompleteReadError,asyncio.LimitOverrunError):pass
  finally:
   connections-=1
   if backend:
    backend.close()
    with contextlib.suppress(OSError):await backend.wait_closed()
   writer.close()
   with contextlib.suppress(OSError):await writer.wait_closed()
 tasks=[asyncio.create_task(watch()),asyncio.create_task(readiness())]
 loop=asyncio.get_running_loop()
 for sig in [signal.SIGTERM,signal.SIGINT]:loop.add_signal_handler(sig,stopping.set)
 server=await asyncio.start_server(handle,'0.0.0.0',public_port,limit=16384)
 print(f'GameForMe HTTP/WebSocket gateway listening on {public_port}',flush=True)
 try:
  async with server:await stopping.wait()
 finally:
  server.close();await server.wait_closed()
  if process.returncode is None:
   process.terminate()
   try:await asyncio.wait_for(process.wait(),5)
   except asyncio.TimeoutError:process.kill();await process.wait()
  for task in tasks:task.cancel()
 return process.returncode or 0
if __name__=='__main__':raise SystemExit(asyncio.run(main()))
