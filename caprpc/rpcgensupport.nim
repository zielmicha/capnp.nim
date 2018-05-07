import reactor/async

template wrapFutureInSinglePointer*(typ, fieldName, value): typed =
  # value: Future[T], return: Future[typ]
  value.then(xxx => typ(fieldName: xxx)).toAnyPointerFuture

template getFutureField*(value, fieldName: untyped): typed =
  value.then((xxx: type(value.get)) => xxx.fieldName)

template miscCapMethods*(typ, typWrapper) =
  proc createCallWrapper[T: typ](ty: typedesc[T], capServer: CapServer): typWrapper =
    return typWrapper(cap: capServer)

  proc toCapServer*(obj: typWrapper): CapServer =
    return obj.cap

  proc createFromCap*[T: typ](cap: typedesc[T], obj: CapServer): T =
    return createCallWrapper(T, obj).asInterface(T)

  proc castAs*[T](self: typ, ty: typedesc[T]): T =
    self.toAnyPointer.castAs(T)

  converter toCapServer*[T: NullCapT](x: T): typ =
    return createFromCap(typ, nullCap)
