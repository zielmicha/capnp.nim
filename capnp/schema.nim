import capnp/gensupport, capnp/unpack

type
  NodeKind* {.pure.} = enum
    file = 0, struct = 1, `enum` = 2, `interface` = 3, `const` = 4, annotation = 5

  Node* = ref object
    id*: uint64
    displayName*: string
    displayNamePrefixLength*: uint32
    scopeId*: uint64
    nestedNodes*: seq[Node_NestedNode]
    case kind*: NodeKind
    of NodeKind.file: discard
    of NodeKind.struct:
      dataWordCount*: uint16
      pointerCount*: uint16
      isGroup*: bool
      discriminantCount*: uint16
      discriminantOffset*: uint32
      fields*: seq[Field]
    of NodeKind.`enum`:
      enumerants*: seq[Enumerant]
    of NodeKind.`interface`: discard
    of NodeKind.`const`: discard
    of NodeKind.annotation: discard

  Node_NestedNode* = ref object
    id*: uint64
    name*: string

  CodeGeneratorRequest* = ref object
    nodes*: seq[Node]
    requestedFiles*: seq[CodeGeneratorRequest_RequestedFile]

  CodeGeneratorRequest_RequestedFile* = ref object
    id*: uint64
    filename*: string

  FieldKind* {.pure.} = enum
    slot = 0, group = 1

  TypeKind* {.pure.} =  enum
    void, bool, int8, int16, int32, int64, uint8, uint16, uint32, uint64, float32, float64, text, data, list, `enum`, struct, `interface`, anyPointer

  Type* = ref object
    case kind*: TypeKind:
    of TypeKind.void: discard
    of TypeKind.bool: discard
    of TypeKind.int8: discard
    of TypeKind.int16: discard
    of TypeKind.int32: discard
    of TypeKind.int64: discard
    of TypeKind.uint8: discard
    of TypeKind.uint16: discard
    of TypeKind.uint32: discard
    of TypeKind.uint64: discard
    of TypeKind.float32: discard
    of TypeKind.float64: discard
    of TypeKind.text: discard
    of TypeKind.data: discard
    of TypeKind.list:
      elementType*: Type
    of TypeKind.`enum`:
      enum_typeId*: uint64
    of TypeKind.struct:
      struct_typeId*: uint64
    of TypeKind.`interface`:
      interface_typeId*: uint64
    of TypeKind.anyPointer: discard

  Field* = ref object
    name*: string
    codeOrder*: uint16
    discriminantValue*: uint16
    case kind*: FieldKind
    of FieldKind.slot:
      offset*: uint32
      `type`*: Type
      #defaultValue*: Value
    of FieldKind.group:
      typeId*: uint64

    `ordinal`: FieldOrdinal

  FieldOrdinalKind* {.pure.} = enum
    implicit, explicit

  FieldOrdinal* = object
    case kind*: FieldOrdinalKind
    of FieldOrdinalKind.implicit: discard
    of FieldOrdinalKind.explicit: discard

  Enumerant* = ref object
    name*: string
    codeOrder*: uint16

makeStructCoders(Node_NestedNode,
                 [(id, 0, 0, true)],
                 [(name, 0, PointerFlag.text, true)],
                 []
)

makeStructCoders(Enumerant,
                 [(codeOrder, 0, 0, true)],
                 [(name, 0, PointerFlag.text, true)],
                 []
)

makeStructCoders(Field,
                 [(codeOrder, 0, 0, true),
                  (discriminantValue, 2, 65535, true),
                  (kind, 8, low(FieldKind), true),
                  (offset, 4, 0, result.kind == FieldKind.slot),
                  (ordinal.kind, 10, high(FieldOrdinalKind), true),
                  (typeId, 16, 0, result.kind == FieldKind.group)],
                 [(name, 0, PointerFlag.text, true),
                  (`type`, 2, PointerFlag.none, result.kind == FieldKind.slot)
                 ],
                 [])

makeStructCoders(Type,
                 [(kind, 0, low(TypeKind), true),
                  (enum_typeId, 8, 0, result.kind == TypeKind.`enum`),
                  (struct_typeId, 8, 0, result.kind == TypeKind.struct),
                  (interface_typeId, 8, 0, result.kind == TypeKind.`interface`)],
                 [(elementType, 0, PointerFlag.none, result.kind == TypeKind.list),],
                 [])

makeStructCoders(Node,
                 [(id, 0, 0, true),
                  (displayNamePrefixLength, 8, 0, true),
                  (scopeId, 16, 0, true),
                  (kind, 12, low(NodeKind), true),
                  (dataWordCount, 14, 0, result.kind == NodeKind.struct),
                  (pointerCount, 24, 0, result.kind == NodeKind.struct),
                  (discriminantCount, 30, 0, result.kind == NodeKind.struct),
                  (discriminantOffset, 32, 0, result.kind == NodeKind.struct)
                 ], # scalars
                 [(displayName, 0, PointerFlag.text, true),
                  (nestedNodes, 1, PointerFlag.none, true),
                  (fields, 3, PointerFlag.none, result.kind == NodeKind.struct),
                  (enumerants, 3, PointerFlag.none, result.kind == NodeKind.`enum`)
                 ], # pointers
                 [(isGroup, 224, 0, result.kind == NodeKind.struct)
                 ] # bitfields
)

makeStructCoders(CodeGeneratorRequest_RequestedFile,
                 [(id, 0, 0, true)],
                 [],
                 [])

makeStructCoders(CodeGeneratorRequest,
                 [],
                 [(nodes, 0, PointerFlag.none, true),
                  (requestedFiles, 1, PointerFlag.none, true)],
                 []
)
