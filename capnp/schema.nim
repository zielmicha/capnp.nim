import capnp/util, capnp/unpack, capnp/pack, capnp/gensupport
type
  Method* = ref object
    name*: string
    codeOrder*: uint16
    paramStructType*: uint64
    resultStructType*: uint64
    annotations*: seq[Annotation]

  Enumerant* = ref object
    name*: string
    codeOrder*: uint16
    annotations*: seq[Annotation]

  FieldKind* {.pure.} = enum
    slot = 0, group = 1

  Field* = ref object
    name*: string
    codeOrder*: uint16
    annotations*: seq[Annotation]
    discriminantValue*: uint16
    ordinal*: Field_ordinal
    case kind*: FieldKind:
    of FieldKind.slot:
      offset*: uint32
      `type`*: Type
      defaultValue*: Value
    of FieldKind.group:
      typeId*: uint64

  CodeGeneratorRequest_RequestedFile_Import* = ref object
    id*: uint64
    name*: string

  Field_ordinalKind* {.pure.} = enum
    implicit = 0, explicit = 1

  Field_ordinal* = object
    case kind*: Field_ordinalKind:
    of Field_ordinalKind.implicit:
      discard
    of Field_ordinalKind.explicit:
      explicit*: uint16

  CodeGeneratorRequest* = ref object
    nodes*: seq[Node]
    requestedFiles*: seq[CodeGeneratorRequest_RequestedFile]

  ValueKind* {.pure.} = enum
    void = 0, bool = 1, int8 = 2, int16 = 3, int32 = 4, int64 = 5, uint8 = 6, uint16 = 7, uint32 = 8, uint64 = 9, float32 = 10, float64 = 11, text = 12, data = 13, list = 14, `enum` = 15, struct = 16, `interface` = 17, anyPointer = 18

  Value* = ref object
    case kind*: ValueKind:
    of ValueKind.void:
      discard
    of ValueKind.bool:
      discard
    of ValueKind.int8:
      int8*: int8
    of ValueKind.int16:
      int16*: int16
    of ValueKind.int32:
      int32*: int16
    of ValueKind.int64:
      int64*: int64
    of ValueKind.uint8:
      uint8*: uint8
    of ValueKind.uint16:
      uint16*: uint16
    of ValueKind.uint32:
      uint32*: uint32
    of ValueKind.uint64:
      uint64*: uint64
    of ValueKind.float32:
      float32*: float32
    of ValueKind.float64:
      float64*: float64
    of ValueKind.text:
      text*: string
    of ValueKind.data:
      data*: string
    of ValueKind.list:
      discard
    of ValueKind.`enum`:
      `enum`*: uint16
    of ValueKind.struct:
      discard
    of ValueKind.`interface`:
      discard
    of ValueKind.anyPointer:
      discard

  CodeGeneratorRequest_RequestedFile* = ref object
    id*: uint64
    filename*: string
    imports*: seq[CodeGeneratorRequest_RequestedFile_Import]

  TypeKind* {.pure.} = enum
    void = 0, bool = 1, int8 = 2, int16 = 3, int32 = 4, int64 = 5, uint8 = 6, uint16 = 7, uint32 = 8, uint64 = 9, float32 = 10, float64 = 11, text = 12, data = 13, list = 14, `enum` = 15, struct = 16, `interface` = 17, anyPointer = 18

  Type* = ref object
    case kind*: TypeKind:
    of TypeKind.void:
      discard
    of TypeKind.bool:
      discard
    of TypeKind.int8:
      discard
    of TypeKind.int16:
      discard
    of TypeKind.int32:
      discard
    of TypeKind.int64:
      discard
    of TypeKind.uint8:
      discard
    of TypeKind.uint16:
      discard
    of TypeKind.uint32:
      discard
    of TypeKind.uint64:
      discard
    of TypeKind.float32:
      discard
    of TypeKind.float64:
      discard
    of TypeKind.text:
      discard
    of TypeKind.data:
      discard
    of TypeKind.list:
      elementType*: Type
    of TypeKind.`enum`:
      enum_typeId*: uint64
    of TypeKind.struct:
      struct_typeId*: uint64
    of TypeKind.`interface`:
      interface_typeId*: uint64
    of TypeKind.anyPointer:
      discard

  ElementSize* {.pure.} = enum
    empty = 0, bit = 1, byte = 2, twoBytes = 3, fourBytes = 4, eightBytes = 5, pointer = 6, inlineComposite = 7

  Node_NestedNode* = ref object
    name*: string
    id*: uint64

  NodeKind* {.pure.} = enum
    file = 0, struct = 1, `enum` = 2, `interface` = 3, `const` = 4, annotation = 5

  Node* = ref object
    id*: uint64
    displayName*: string
    displayNamePrefixLength*: uint32
    scopeId*: uint64
    nestedNodes*: seq[Node_NestedNode]
    annotations*: seq[Annotation]
    case kind*: NodeKind:
    of NodeKind.file:
      discard
    of NodeKind.struct:
      dataWordCount*: uint16
      pointerCount*: uint16
      preferredListEncoding*: ElementSize
      discriminantCount*: uint16
      discriminantOffset*: uint32
      fields*: seq[Field]
    of NodeKind.`enum`:
      enumerants*: seq[Enumerant]
    of NodeKind.`interface`:
      methods*: seq[Method]
      extends*: seq[uint64]
    of NodeKind.`const`:
      const_type*: Type
      value*: Value
    of NodeKind.annotation:
      annotation_type*: Type

  Annotation* = ref object
    id*: uint64
    value*: Value



makeStructCoders(Method, [
  (codeOrder, 0, 0, true),
  (paramStructType, 8, 0, true),
  (resultStructType, 16, 0, true)
  ], [
  (name, 0, PointerFlag.text, true),
  (annotations, 1, PointerFlag.none, true)
  ], [])

makeStructCoders(Enumerant, [
  (codeOrder, 0, 0, true)
  ], [
  (name, 0, PointerFlag.text, true),
  (annotations, 1, PointerFlag.none, true)
  ], [])

makeStructCoders(Field, [
  (codeOrder, 0, 0, true),
  (discriminantValue, 2, 65535, true),
  (kind, 8, low(FieldKind), true),
  (offset, 4, 0, FieldKind.slot),
  (typeId, 16, 0, FieldKind.group)
  ], [
  (name, 0, PointerFlag.text, true),
  (annotations, 1, PointerFlag.none, true),
  (`type`, 2, PointerFlag.none, FieldKind.slot),
  (defaultValue, 3, PointerFlag.none, FieldKind.slot)
  ], [])

makeStructCoders(CodeGeneratorRequest_RequestedFile_Import, [
  (id, 0, 0, true)
  ], [
  (name, 0, PointerFlag.text, true)
  ], [])

makeStructCoders(Field_ordinal, [
  (kind, 10, low(Field_ordinalKind), true),
  (explicit, 12, 0, Field_ordinalKind.explicit)
  ], [], [])

makeStructCoders(CodeGeneratorRequest, [], [
  (nodes, 0, PointerFlag.none, true),
  (requestedFiles, 1, PointerFlag.none, true)
  ], [])

makeStructCoders(Value, [
  (kind, 0, low(ValueKind), true),
  (int8, 2, 0, ValueKind.int8),
  (int16, 2, 0, ValueKind.int16),
  (int32, 4, 0, ValueKind.int32),
  (int64, 8, 0, ValueKind.int64),
  (uint8, 2, 0, ValueKind.uint8),
  (uint16, 2, 0, ValueKind.uint16),
  (uint32, 4, 0, ValueKind.uint32),
  (uint64, 8, 0, ValueKind.uint64),
  (float32, 4, 0, ValueKind.float32),
  (float64, 8, 0, ValueKind.float64),
  (`enum`, 2, 0, ValueKind.`enum`)
  ], [
  (text, 0, PointerFlag.text, ValueKind.text),
  (data, 0, PointerFlag.none, ValueKind.data)
  ], [])

makeStructCoders(CodeGeneratorRequest_RequestedFile, [
  (id, 0, 0, true)
  ], [
  (filename, 0, PointerFlag.text, true),
  (imports, 1, PointerFlag.none, true)
  ], [])

makeStructCoders(Type, [
  (kind, 0, low(TypeKind), true),
  (enum_typeId, 8, 0, TypeKind.`enum`),
  (struct_typeId, 8, 0, TypeKind.struct),
  (interface_typeId, 8, 0, TypeKind.`interface`)
  ], [
  (elementType, 0, PointerFlag.none, TypeKind.list)
  ], [])

makeStructCoders(Node_NestedNode, [
  (id, 0, 0, true)
  ], [
  (name, 0, PointerFlag.text, true)
  ], [])

makeStructCoders(Node, [
  (id, 0, 0, true),
  (displayNamePrefixLength, 8, 0, true),
  (scopeId, 16, 0, true),
  (kind, 12, low(NodeKind), true),
  (dataWordCount, 14, 0, NodeKind.struct),
  (pointerCount, 24, 0, NodeKind.struct),
  (preferredListEncoding, 26, ElementSize(0), NodeKind.struct),
  (discriminantCount, 30, 0, NodeKind.struct),
  (discriminantOffset, 32, 0, NodeKind.struct)
  ], [
  (displayName, 0, PointerFlag.text, true),
  (nestedNodes, 1, PointerFlag.none, true),
  (annotations, 2, PointerFlag.none, true),
  (fields, 3, PointerFlag.none, NodeKind.struct),
  (enumerants, 3, PointerFlag.none, NodeKind.`enum`),
  (methods, 3, PointerFlag.none, NodeKind.`interface`),
  (extends, 4, PointerFlag.none, NodeKind.`interface`),
  (const_type, 3, PointerFlag.none, NodeKind.`const`),
  (value, 4, PointerFlag.none, NodeKind.`const`),
  (annotation_type, 3, PointerFlag.none, NodeKind.annotation)
  ], [])

makeStructCoders(Annotation, [
  (id, 0, 0, true)
  ], [
  (value, 0, PointerFlag.none, true)
  ], [])


