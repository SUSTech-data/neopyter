from typing import Optional, Sequence
import asyncio
from asyncio import StreamReader, StreamWriter, Server
from .msgpack_queue import labextension_queue, client_queue

class TcpServer(object):
    def __init__(self) -> None:
        self.server: Optional[Server] = None

    
    @property
    def is_running(self)->bool:
        return self.server != None

    async def start(self, host: str|Sequence[str]="127.0.0.1", port:int|str=8889):
        # support update?
        if self.server:
            await self.stop()

        self.server = await asyncio.start_server(lambda r,w:self.client_connected(r,w), host, port)
        addrs = ', '.join(str(sock.getsockname()) for sock in self.server.sockets)
        print(f'Serving on {addrs}')

    async def client_connected(self, reader: StreamReader, writer: StreamWriter):
        if  self.server == None:
            writer.close()
            await writer.wait_closed()
            return
        print("New cient connected ")

        while not writer.is_closing() and not reader.at_eof():
            while labextension_queue.qsize() > 0:
                buf = await labextension_queue.get()
                print("get labextension_queue", buf)
                writer.write(buf)
            while True:
                buf = await reader.read(512)
                if len(buf) == 0:
                    # EOF
                    break
                print("put client_queue", buf)
                client_queue.put(buf)
                if len(buf) != 512:
                    break
            await asyncio.sleep(0.2)
        print("Client disconnected ")

    async def stop(self):
        # maybe repeat check, whatever
        if self.server:
            self.server.close()
            await self.server.wait_closed()

# global variable?
tcpServer = TcpServer()

def setup_tcp_server():
    global tcpServer
    # TODO:read config
    pass
