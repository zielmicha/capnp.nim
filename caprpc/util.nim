import tables

type
  QuestionTable*[K: uint32, V] = object
    t: Table[K, V]
    free: seq[K]
    firstFree: K

proc init*[K, V](self: var QuestionTable[K, V]) =
  self.t = initTable[K, V]()
  self.free = @[]
  self.firstFree = 0

proc contains*[K, V](self: QuestionTable[K, V], k: K): V =
  return k in self.t

proc `[]`*[K, V](self: QuestionTable[K, V], k: K): V =
  return self.t[k]

proc putNext*[K, V](self: QuestionTable[K, V], val: V): K =
  if self.free.len != 0:
    result = self.free[^1]
    self.free.pop
  else:
    result = self.firstFree
    self.firstFree += 1

  self.t[result] = val

proc del*[K, V](self: QuestionTable[K, V], k: K) =
  self.t.del(k)
  if k + 1 == self.firstFree:
    self.firstFree -= 1
  else:
    self.free.add(k)
  # TODO: remove items from free when (firstFree - 1) in free
