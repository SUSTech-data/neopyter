
from tornado.queues import Queue
# from asyncio.queues import Queue

# jupyter lab frontend extension => labextension_queue => client(neovim)
labextension_queue = Queue()

# client(neovim) => client_queue => jupyter lab frontend extension
client_queue = Queue()

