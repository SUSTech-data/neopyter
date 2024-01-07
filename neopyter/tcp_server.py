import socket
from typing import Optional, Sequence
import asyncio
from asyncio import StreamReader, StreamWriter, Server
from .msgpack_queue import labextension_queue, client_queue


async def check_port(host, port):
    try:
        _, w = await asyncio.open_connection(host, port)
        w.close()
        await w.wait_closed()
        return True
    except OSError:
        return False


async def find_empty_port(start_idx):
    idx = start_idx
    while await check_port("127.0.0.1", idx):
        idx = idx + 1
    return idx


def get_all_id_addresses():
    hostname = socket.gethostname()
    ip_addresses = set()
    ip_addresses.add("127.0.0.1")
    for info in socket.getaddrinfo(hostname, None, family=socket.AF_INET):
        ip_addresses.add(info[4][0])
    return ip_addresses


class TcpServer(object):
    def __init__(self) -> None:
        self.server: Optional[Server] = None
        self.host: Optional[Sequence[str]] = None
        self.port: Optional[int | str] = None

    @property
    def is_running(self) -> bool:
        return self.server is not None

    async def start(
        self,
        host: Optional[Sequence[str]] = None,
        port: Optional[int | str] = None,
    ):
        # support update?
        if self.server:
            await self.stop()

        if not host:
            host = list(get_all_id_addresses())
        if not port:
            port = await find_empty_port(9001)
        self.host = host
        self.port = port

        self.server = await asyncio.start_server(
            lambda r, w: self.client_connected(r, w), host, port
        )
        addrs = ", ".join(str(sock.getsockname()) for sock in self.server.sockets)
        print(f"Serving on {addrs}")

    async def client_connected(self, reader: StreamReader, writer: StreamWriter):
        if self.server is None:
            writer.close()
            await writer.wait_closed()
            return
        print("New client connected ")
        await asyncio.gather(
            asyncio.create_task(self.start_reader_loop(reader, writer)),
            asyncio.create_task(self.start_writer_loop(writer)),
        )
        print("Client disconnected, clear queue")

    async def start_reader_loop(self, reader: StreamReader, writer: StreamWriter):
        print("Client reader loop start")
        while not reader.at_eof():
            buf = await reader.read(512)
            if len(buf) == 0:
                continue
            # print("put client_queue", buf)
            await client_queue.put(buf)
        print("Client reader loop end")
        writer.close()

    async def start_writer_loop(self, writer: StreamWriter):
        print("Client writer loop start")
        while not writer.is_closing():
            while labextension_queue.qsize() > 0:
                buf = await labextension_queue.get()
                # print("get labextension_queue", buf)
                writer.write(buf)
            await asyncio.sleep(0.3)
        print("Client writer loop end")

    async def stop(self):
        # maybe repeat check, whatever
        if self.server:
            self.server.close()
            await self.server.wait_closed()
        self.host = None
        self.port = None


# global variable?
tcpServer = TcpServer()


def setup_tcp_server():
    global tcpServer
    # TODO:read config
    pass
