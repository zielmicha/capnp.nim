import capnp
import simplerpc_capnp

class Obj(simplerpc_capnp.SimpleRpc.Server):
    def identity(self, x, _context):
        return x

server = capnp.TwoPartyServer('127.0.0.1:6789', bootstrap=Obj())
server.run_forever()
