import reactor/async

template wrapFutureInSinglePointer*(typ, fieldName, value): typed =
  # value: Future[T], return: Future[typ]
  value.then(xxx => typ(fieldName: xxx))

template getFutureField*(value, fieldName): typed =
  value.then(xxx => xxx.fieldName)

template miscCapMethods*(typ, typWrapper) =
  proc createCallWrapper[T: typ](ty: typedesc[T], capServer: CapServer): typWrapper =
    return typWrapper(cap: capServer)

  proc toCapServer*(obj: typWrapper): CapServer =
    return obj.cap

  proc createFromCap*[T: typ](cap: typedesc[T], obj: CapServer): T =
    return createCallWrapper(T, obj).asInterface(T)
