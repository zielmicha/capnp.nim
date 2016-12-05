import capnp
import simplerpc_capnp

class Obj(simplerpc_capnp.SimpleRpc.Server):
    def identity(self, a, _context):
        print('identity', a)
        return a

server = capnp.TwoPartyServer('127.0.0.1:6789', bootstrap=Obj())
server.run_forever()
