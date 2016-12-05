import reactor/async

template wrapFutureInSinglePointer*(typ, fieldName, value): typed =
  # value: Future[T], return: Future[typ]
  value.then(xxx => typ(fieldName: xxx))

template getFutureField*(value, fieldName): typed =
  value.then(xxx => xxx.fieldName)

template miscCapMethods*(typ) =
  proc createFromCap*[T: typ](cap: typedesc[T], obj: CapServer): T =
    return createCallWrapper(T, obj).asInterface(T)
