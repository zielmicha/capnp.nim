import collections/iface
import caprpc/schema
import reactor

type
  VatNetwork*[VatId] = Interface

  Connection* = Pipe[Message]

interfaceMethods VatNetwork[VatId]:
  connect(varId: VatId): Connection
  accept(): Future[Connection]
