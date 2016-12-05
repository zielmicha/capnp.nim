import tables, collections/pprint

type
  QuestionTable*[K: uint32, V] = object {.requiresinit.}
    t: Table[K, V]
    free: seq[K]
    firstFree: K

proc initQuestionTable*[K, V](): QuestionTable[K, V] =
  result = QuestionTable[K, V]()
  result.t = initTable[K, V]()
  result.free = @[]
  result.firstFree = 0

proc init*[K, V](self: var QuestionTable[K, V]) =
  self = initQuestionTable[K, V]()

proc contains*[K, V](self: QuestionTable[K, V], k: K): bool =
  return k in self.t

proc `[]`*[K, V](self: QuestionTable[K, V], k: K): V =
  return self.t[k]

proc putNext*[K, V](self: var QuestionTable[K, V], val: V): K =
  if self.free.len != 0:
    result = self.free.pop
  else:
    result = self.firstFree
    self.firstFree += 1

  self.t[result] = val

proc del*[K, V](self: var QuestionTable[K, V], k: K) =
  self.t.del(k)
  if k + 1 == self.firstFree:
    self.firstFree -= 1
  else:
    self.free.add(k)
  # TODO: remove items from free when (firstFree - 1) in free

proc pprint*[K, V](self: QuestionTable[K, V]): string =
  return "QuestionTable " & pprint(self.t)
