import capnp/gensupport, capnp/unpack

type
  NodeKind* {.pure.} = enum
    file, struct, `enum`, `interface`, `const`, annotation

  Node* = ref object
    id*: uint64
    displayName*: string
    displayNamePrefixLength*: uint32
    scopeId*: uint64
    #nestedNodes*: seq[NestedNode]
    case kind*: NodeKind
    of NodeKind.file: discard
    of NodeKind.struct:
      dataWordCount*: uint16
      pointerCount*: uint16
      isGroup*: bool
      discriminantCount*: uint16
      discriminantOffset*: uint32
      #fields*: seq[Field]
    of NodeKind.`enum`: discard
    of NodeKind.`interface`: discard
    of NodeKind.`const`: discard
    of NodeKind.annotation: discard

  CodeGeneratorRequest* = ref object
    nodes*: seq[Node]

  CodeGeneratorRequest_RequestedFile* = ref object
    id*: uint64
    filename*: string

makeStructCoders(Node,
                 [(id, 0, 0), (displayNamePrefixLength, 8, 0), (scopeId, 16, 0)], # scalars
                 [(displayName, 0, PointerFlag.text)], # pointers
                 [(isGroup, 224, 0)] # bitfields
)

makeStructCoders(CodeGeneratorRequest,
                 [],
                 [(nodes, 0, PointerFlag.none)],
                 []
)
