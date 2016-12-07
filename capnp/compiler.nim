import capnp/schema, capnp, tables, hashes, collections/base, collections/iterate, collections/misc, strutils, tables

type
  Generator* = ref object
    nodes: Table[uint64, Node]
    typeNames: Table[uint64, string]
    isGroup: Table[uint64, bool]
    toplevel: string
    bottom: string
    enableRpc: bool

proc hash(x: uint64): Hash {.inline.} =
  result = Hash(x and 0xFFFFFFF)

proc walkType(self: Generator, id: uint64, prefix: string="") =
  let node = self.nodes[id]

  for child in node.nestedNodes:
    let name = prefix & child.name

    self.typeNames[child.id] = name
    self.walkType(child.id, name & "_")

  if node.kind == NodeKind.struct:
    for field in node.fields:
      if field.kind == FieldKind.group:
        let name = prefix & field.name

        if field.discriminantValue == 0xFFFF:
          self.isGroup[field.typeId] = true
          self.typeNames[field.typeId] = name

        self.walkType(field.typeId, name & "_")
  elif node.kind == NodeKind.`interface`:
    # TODO: superclasses
    for m in node.methods:
      let p = prefix & m.name & "_"

      self.typeNames[m.paramStructType] = p & "Params"
      self.walkType(m.paramStructType, p & "Params_")

      self.typeNames[m.resultStructType] = p & "Result"
      self.walkType(m.resultStructType, p & "Result_")
  elif node.kind != NodeKind.file:
    stderr.writeLine("ignoring ", node.kind, " ", id)

proc addToplevel(self: Generator, s: string) =
  self.toplevel &= s
  self.toplevel &= "\n"

proc quoteId(s: string): string =
  const keywords = "addr and as asm atomic bind block break case cast concept const continue converter defer discard distinct div do elif else end enum except export finally for from func generic if import in include interface is isnot iterator let macro method mixin mod nil not notin object of or out proc ptr raise ref return shl shr static template try tuple type using var when while with without xor yield".split(" ")
  if s in keywords: return "`$1`" % s
  return s

proc quoteFieldId(s: string): string =
  const primitiveTypes = "void bool int8 int16 int32 int64 uint8 uint16 uint32 uint64 float32 float64".split(" ")
  #if s in primitiveTypes: return s & "_field"
  return s.quoteId

proc type2nim(self: Generator, t: Type): string =
  case t.kind:
    of TypeKind.void: return "void"
    of TypeKind.bool: return "bool"
    of TypeKind.int8: return "int8"
    of TypeKind.int16: return "int16"
    of TypeKind.int32: return "int32"
    of TypeKind.int64: return "int64"
    of TypeKind.uint8: return "uint8"
    of TypeKind.uint16: return "uint16"
    of TypeKind.uint32: return "uint32"
    of TypeKind.uint64: return "uint64"
    of TypeKind.float32: return "float32"
    of TypeKind.float64: return "float64"
    of TypeKind.text: return "string"
    of TypeKind.data: return "string"
    of TypeKind.list:
      return "seq[$1]" % self.type2nim(t.elementType)
    of TypeKind.`enum`:
      return self.typeNames[t.enum_typeId]
    of TypeKind.struct:
      return self.typeNames[t.struct_typeId]
    of TypeKind.`interface`:
      return self.typeNames[t.interface_typeId]
    of TypeKind.anyPointer:
      return "AnyPointer"

proc typesize(t: Type): int =
  case t.kind:
    of TypeKind.int8: return 1
    of TypeKind.int16: return 2
    of TypeKind.int32: return 4
    of TypeKind.int64: return 8
    of TypeKind.uint8: return 1
    of TypeKind.uint16: return 2
    of TypeKind.uint32: return 4
    of TypeKind.uint64: return 8
    of TypeKind.float32: return 4
    of TypeKind.float64: return 8
    of TypeKind.`enum`: return 2
    else: doAssert(false, "bad type $1" % $t.kind)

proc makeDefaultValue(self: Generator, typ: Type, val: Value): string =
  case typ.kind:
  of TypeKind.bool: return $(if val.bool: "true" else: "false")
  of TypeKind.int8: return $(val.int8)
  of TypeKind.int16: return $(val.int16)
  of TypeKind.int32: return $(val.int32)
  of TypeKind.int64: return $(val.int64)
  of TypeKind.uint8: return $(val.uint8)
  of TypeKind.uint16: return $(val.uint16)
  of TypeKind.uint32: return $(val.uint32)
  of TypeKind.uint64: return $(val.uint64)
  of TypeKind.float32: return $(val.float32) # risky, we probably need exact value
  of TypeKind.float64: return $(val.float64)
  of TypeKind.`enum`:
    return "$1($2)" % [self.typeNames[typ.enum_typeId], $val.`enum`]
  else:
    doAssert(false, "bad type $1" % $typ.kind)

proc isTextType(t: Type): bool =
  ## is `t` Text or a list containing Text?
  if t.kind == TypeKind.text:
    return true
  elif t.kind == TypeKind.list:
    return isTextType(t.elementType)
  else:
    return false

proc generateStruct(self: Generator, name: string, node: Node) =
  let unionFields = node.fields.filter(f => f.discriminantValue != 0xFFFF).toSeq
  let hasUnion = unionFields.len != 0

  if hasUnion:
    var s = "  $1Kind* {.pure.} = enum\n    " % name
    s &= unionFields.map(f => "$1 = $2" % [$quoteId(f.name), $f.discriminantValue]).toSeq.join(", ")
    s &= "\n"
    self.addToplevel(s)

  proc fieldDecl(f: Field, namePrefix=""): string =
    result = quoteFieldId(namePrefix & f.name) & "*: "
    if f.kind == FieldKind.slot:
      result &= self.type2nim(f.`type`)
    else:
      result &= self.typeNames[f.typeId]

  var s: string
  if self.isGroup.getOrDefault(node.id):
    s = "  $1* = object\n" % name
  else:
    s = "  $1* = ref object\n" % name

  for field in node.fields:
    if field.discriminantValue != 0xFFFF:
      continue

    s &= "    " & fieldDecl(field) & "\n"

  var unionCoders: seq[tuple[name: string, fields: seq[tuple[field: Field, namePrefix: string]]]] = @[]

  if hasUnion:
    var unionSubfields: seq[tuple[name: string, fields: seq[Field]]] = @[]

    for field in unionFields:
      if field.kind == FieldKind.slot:
        unionSubfields.add((field.name, @[field]))
      else:
        unionSubfields.add((field.name, self.nodes[field.typeId].fields))

    let nameCounter = unionSubfields.flatMap(x => x.fields).map(f => f.name).toCounter

    s &= "    case kind*: $1Kind:\n" % name
    for subfields in unionSubfields:
      s &= "    of $1Kind.$2:\n" % [name, quoteId(subfields.name)]
      unionCoders.add((subfields.name, @[]))

      let goodFields = subfields.fields.filter(f => f.kind == FieldKind.slot and f.`type`.kind notin {TypeKind.void, TypeKind.anypointer}).toSeq
      if goodFields.len == 0:
        s &= "      discard\n"
      for field in goodFields:
        let namePrefix = if nameCounter[field.name] == 1: "" else: subfields.name & "_"
        s &= "      " & fieldDecl(field, namePrefix) & "\n"
        unionCoders[^1].fields.add((field, namePrefix))

  var pointerCoderArgs: seq[string] = @[]
  var scalarCoderArgs: seq[string] = @[]
  var boolCoderArgs: seq[string] = @[]

  proc addCoderFields(node: Node, prefix: string, condition: string)

  proc addCoderField(f: Field, prefix: string, condition: string) =
    let fieldName = prefix & f.name
    if f.kind == FieldKind.slot:
      if f.`type`.kind in {TypeKind.text, TypeKind.data, TypeKind.list, TypeKind.struct, TypeKind.anyPointer, TypeKind.`interface`}:
        let flags = if isTextType(f.`type`): "PointerFlag.text" else: "PointerFlag.none"
        let s = "($1, $2, $3, $4)" % [quoteFieldId(fieldName), $f.offset, flags, condition]
        pointerCoderArgs.add s
      elif f.`type`.kind == TypeKind.bool:
        let defaultVal = self.makeDefaultValue(f.`type`, f.defaultValue)
        let s = "($1, $2, $3, $4)" % [quoteFieldId(fieldName), $(f.offset.int), defaultVal, condition]
        boolCoderArgs.add s
      else:
        let defaultVal = self.makeDefaultValue(f.`type`, f.defaultValue)
        let s = "($1, $2, $3, $4)" % [quoteFieldId(fieldName), $(f.offset.int * f.`type`.typesize), defaultVal, condition]
        scalarCoderArgs.add s
    else:
      addCoderFields(self.nodes[f.typeId], fieldName & ".", condition)

  proc addCoderFields(node: Node, prefix: string, condition: string) =
    for f in node.fields:
      if f.discriminantValue == 0xFFFF:
        addCoderField(f, prefix, condition)

  addCoderFields(node, "", "true")

  if hasUnion:
    scalarCoderArgs.add("(kind, $1, low($2Kind), true)" % [$(node.discriminantOffset * 2), name])
    for c in unionCoders:
      for f in c.fields:
        addCoderField(f.field, f.namePrefix, "$1Kind.$2" % [name, quoteFieldId(c.name)])

  proc joinList(v: seq[string]): string =
    if v.len == 0: return ""
    else: return "\n  " & v.join(",\n  ") & "\n  "

  self.bottom &= "makeStructCoders($1, [$2], [$3], [$4])\n\n" % [
    name,
    scalarCoderArgs.joinList(),
    pointerCoderArgs.joinList(),
    boolCoderArgs.joinList()
  ]

  self.addToplevel(s)

proc generateEnum(self: Generator, name: string, node: Node) =
  var s = "  $1* {.pure.} = enum\n    " % name
  s &= node.enumerants.map(en => "$1 = $2" % [$quoteId(en.name), $en.codeOrder]).toSeq.join(", ")
  s &= "\n"
  self.addToplevel(s)

proc generateInterface(self: Generator, name: string, node: Node) =
  self.enableRpc = true
  var s = "  $1* = distinct Interface\L" % name
  s &= "  $1_CallWrapper* = ref object of CapServerWrapper\L" % name
  self.addToplevel(s)

  proc makeParams(typ: uint64): string =
    let typNode = self.nodes[typ]
    return typNode.fields.map(x => (x.name.quoteId) & ": " & self.type2nim(x.`type`)).toSeq.join(", ")

  proc makeResult(typ: uint64): string =
    let typNode = self.nodes[typ]
    if typNode.fields.len == 0:
      return "void"
    elif typNode.fields.len == 1:
      return self.type2nim(typNode.fields[0].`type`)
    else:
      return self.type2nim(Type(kind: TypeKind.struct, struct_typeId: typ))

  var helpers = "interfaceMethods " & name & ":\L"
  helpers &= "  toCapServer(): CapServer\L"
  for m in node.methods:
    helpers &= "  $1($2): Future[$3]\L" % [m.name.quoteId,
                                   makeParams(m.paramStructType),
                                   makeResult(m.resultStructType)]

  helpers &= "\Lproc getIntefaceId*(t: typedesc[$1]): uint64 = return $2'u64\L" % [name.quoteId, $node.id]

  # Call method by ID + AnyPointer args on existing interface object
  helpers &= """

miscCapMethods($1, $1_CallWrapper)

proc capCall*[T: $1](cap: T, id: uint64, args: AnyPointer): Future[AnyPointer] =
  case id:
""" % name

  for methodId, m in node.methods:
    helpers &= "    of $1:\L" % [$methodId]
    helpers &= "      let argObj = args.castAs($1_$2_Params)\L" % [name, m.name]
    let paramFields = self.nodes[m.paramStructType].fields
    let retFields = self.nodes[m.resultStructType].fields
    let args = paramFields.map(x => "argObj." & x.name).toSeq.join(", ")
    helpers &= "      let retVal = cap.$1($2)\L" % [m.name.quoteId, args]
    var makeResult = ""

    if retFields.len == 0:
      helpers &= "      return retVal.then(() => $1_$2_Result())\L" % [name, m.name]
    elif retFields.len == 1:
      helpers &= "      return wrapFutureInSinglePointer($1_$2_Result, $3, retVal)\L" % [name, m.name, retFields[0].name.quoteId]
    else:
      let retArgs = retFields.map(x => x.name & ": retVal." & x.name).toSeq.join(", ")
      helpers &= "      return retVal.asAnyPointerFuture\L" % [name, m.name, retArgs]
  helpers &= "    else: raise newException(NotImplementedError, \"not implemented\")\L"

  # CallWrapper implementation -
  for methodId, m in node.methods:
    let mname = name & "_" & m.name

    helpers &= "\Lproc $1*[T: $2_CallWrapper](self: T, $3): Future[$4] =\L" % [
      m.name.quoteId,
      name,
      makeParams(m.paramStructType),
      makeResult(m.resultStructType)]

    let arguments = self.nodes[m.paramStructType].fields.map(
      x => "$1: $1" % [x.name.quoteId]).toSeq

    let callExpr =  "self.cap.call($1'u64, $2, toAnyPointer($3_Params($4))).castAs($3_Result)" % [
      $(node.id),
      $(methodId),
      mname,
      arguments.join(", ")]

    let retFields = self.nodes[m.resultStructType].fields

    if retFields.len == 0:
      helpers &= "  return $1.ignoreResultValue\L" % [callExpr]
    elif retFields.len == 1:
      helpers &= "  return getFutureField($1, $2)\L" % [callExpr, retFields[0].name.quoteId]
    else:
      helpers &= "  return $1\L" % [callExpr]

  self.bottom &= helpers & "\L"

proc generateType(self: Generator, id: uint64) =
  let name = self.typeNames[id]
  let node = self.nodes[id]

  if node.kind == NodeKind.struct:
    self.generateStruct(name, node)
  elif node.kind == NodeKind.`enum`:
    self.generateEnum(name, node)
  elif node.kind == NodeKind.`interface`:
    self.generateInterface(name, node)

proc generateCode*(req: CodeGeneratorRequest) =
  let self = new(Generator)
  self.nodes = initTable[uint64, Node]()
  self.typeNames = initTable[uint64, string]()
  self.isGroup = initTable[uint64, bool]()
  self.toplevel = ""
  self.bottom = ""

  for node in req.nodes:
    self.nodes[node.id] = node

  for file in req.requestedFiles:
    walkType(self, file.id)

  for id in sorted(self.typeNames.keys):
    self.generateType(id)

  echo "import capnp, capnp/gensupport, collections/iface\n"
  if self.enableRpc:
    echo "import reactor, caprpc, caprpc/rpcgensupport"
  echo "type\n" & self.toplevel
  echo()
  echo self.bottom
