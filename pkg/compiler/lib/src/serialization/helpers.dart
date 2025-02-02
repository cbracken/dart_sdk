// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.10

part of 'serialization.dart';

/// Enum values used for identifying different kinds of serialized data.
///
/// This is used to for debugging data inconsistencies between serialization
/// and deserialization.
enum DataKind {
  bool,
  uint30,
  string,
  enumValue,
  uri,
  libraryNode,
  classNode,
  typedefNode,
  memberNode,
  treeNode,
  typeParameterNode,
  dartType,
  dartTypeNode,
  sourceSpan,
  constant,
  import,
  double,
  int,
}

/// Enum used for identifying the enclosing entity of a member in serialization.
enum MemberContextKind { library, cls }

/// Enum used for identifying [Local] subclasses in serialization.
enum LocalKind {
  jLocal,
  thisLocal,
  boxLocal,
  anonymousClosureLocal,
  typeVariableLocal,
}

/// Enum used for identifying [ir.TreeNode] subclasses in serialization.
enum _TreeNodeKind {
  cls,
  member,
  node,
  functionNode,
  typeParameter,
  functionDeclarationVariable,
  constant,
}

/// Enum used for identifying [ir.FunctionNode] context in serialization.
enum _FunctionNodeKind {
  procedure,
  constructor,
  functionExpression,
  functionDeclaration,
}

/// Enum used for identifying [ir.TypeParameter] context in serialization.
enum _TypeParameterKind {
  cls,
  functionNode,
}

/// Class used for encoding tags in [ObjectDataSink] and [ObjectDataSource].
class Tag {
  final String value;

  Tag(this.value);

  @override
  int get hashCode => value.hashCode * 13;

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! Tag) return false;
    return value == other.value;
  }

  @override
  String toString() => 'Tag($value)';
}

/// Enum used for identifying [DartType] subclasses in serialization.
enum DartTypeKind {
  none,
  legacyType,
  nullableType,
  neverType,
  voidType,
  typeVariable,
  functionTypeVariable,
  functionType,
  interfaceType,
  dynamicType,
  erasedType,
  anyType,
  futureOr,
}

/// Enum used for identifying [ir.DartType] subclasses in serialization.
enum DartTypeNodeKind {
  none,
  voidType,
  typeParameterType,
  functionType,
  functionTypeVariable,
  interfaceType,
  typedef,
  dynamicType,
  invalidType,
  thisInterfaceType,
  exactInterfaceType,
  doesNotComplete,
  neverType,
  futureOrType,
  nullType,
}

const String functionTypeNodeTag = 'function-type-node';

class DartTypeNodeWriter
    extends ir.DartTypeVisitor1<void, List<ir.TypeParameter>> {
  final DataSinkWriter _sink;

  DartTypeNodeWriter(this._sink);

  void visitTypes(
      List<ir.DartType> types, List<ir.TypeParameter> functionTypeVariables) {
    _sink.writeInt(types.length);
    for (ir.DartType type in types) {
      _sink._writeDartTypeNode(type, functionTypeVariables);
    }
  }

  @override
  void defaultDartType(
      ir.DartType node, List<ir.TypeParameter> functionTypeVariables) {
    throw UnsupportedError(
        "Unexpected ir.DartType $node (${node.runtimeType}).");
  }

  @override
  void visitInvalidType(
      ir.InvalidType node, List<ir.TypeParameter> functionTypeVariables) {
    _sink.writeEnum(DartTypeNodeKind.invalidType);
  }

  @override
  void visitDynamicType(
      ir.DynamicType node, List<ir.TypeParameter> functionTypeVariables) {
    _sink.writeEnum(DartTypeNodeKind.dynamicType);
  }

  @override
  void visitVoidType(
      ir.VoidType node, List<ir.TypeParameter> functionTypeVariables) {
    _sink.writeEnum(DartTypeNodeKind.voidType);
  }

  @override
  void visitNeverType(
      ir.NeverType node, List<ir.TypeParameter> functionTypeVariables) {
    if (node == const DoesNotCompleteType()) {
      _sink.writeEnum(DartTypeNodeKind.doesNotComplete);
    } else {
      _sink.writeEnum(DartTypeNodeKind.neverType);
      _sink.writeEnum(node.nullability);
    }
  }

  @override
  void visitNullType(
      ir.NullType node, List<ir.TypeParameter> functionTypeVariables) {
    _sink.writeEnum(DartTypeNodeKind.nullType);
  }

  @override
  void visitInterfaceType(
      ir.InterfaceType node, List<ir.TypeParameter> functionTypeVariables) {
    if (node is ThisInterfaceType) {
      _sink.writeEnum(DartTypeNodeKind.thisInterfaceType);
    } else if (node is ExactInterfaceType) {
      _sink.writeEnum(DartTypeNodeKind.exactInterfaceType);
    } else {
      _sink.writeEnum(DartTypeNodeKind.interfaceType);
    }
    _sink.writeClassNode(node.classNode);
    _sink.writeEnum(node.nullability);
    visitTypes(node.typeArguments, functionTypeVariables);
  }

  @override
  void visitFutureOrType(
      ir.FutureOrType node, List<ir.TypeParameter> functionTypeVariables) {
    _sink.writeEnum(DartTypeNodeKind.futureOrType);
    _sink.writeEnum(node.declaredNullability);
    _sink._writeDartTypeNode(node.typeArgument, functionTypeVariables);
  }

  @override
  void visitFunctionType(
      ir.FunctionType node, List<ir.TypeParameter> functionTypeVariables) {
    _sink.writeEnum(DartTypeNodeKind.functionType);
    _sink.begin(functionTypeNodeTag);
    functionTypeVariables = List<ir.TypeParameter>.from(functionTypeVariables)
      ..addAll(node.typeParameters);
    _sink.writeInt(node.typeParameters.length);
    for (ir.TypeParameter parameter in node.typeParameters) {
      _sink.writeString(parameter.name);
      _sink._writeDartTypeNode(parameter.bound, functionTypeVariables);
      _sink._writeDartTypeNode(parameter.defaultType, functionTypeVariables);
    }
    _sink._writeDartTypeNode(node.returnType, functionTypeVariables);
    _sink.writeEnum(node.nullability);
    _sink.writeInt(node.requiredParameterCount);
    visitTypes(node.positionalParameters, functionTypeVariables);
    _sink.writeInt(node.namedParameters.length);
    for (ir.NamedType parameter in node.namedParameters) {
      _sink.writeString(parameter.name);
      _sink.writeBool(parameter.isRequired);
      _sink._writeDartTypeNode(parameter.type, functionTypeVariables);
    }
    _sink._writeDartTypeNode(node.typedefType, functionTypeVariables,
        allowNull: true);
    _sink.end(functionTypeNodeTag);
  }

  @override
  void visitTypeParameterType(
      ir.TypeParameterType node, List<ir.TypeParameter> functionTypeVariables) {
    int index = functionTypeVariables.indexOf(node.parameter);
    if (index != -1) {
      _sink.writeEnum(DartTypeNodeKind.functionTypeVariable);
      _sink.writeInt(index);
      _sink.writeEnum(node.declaredNullability);
      _sink._writeDartTypeNode(node.promotedBound, functionTypeVariables,
          allowNull: true);
    } else {
      _sink.writeEnum(DartTypeNodeKind.typeParameterType);
      _sink.writeTypeParameterNode(node.parameter);
      _sink.writeEnum(node.declaredNullability);
      _sink._writeDartTypeNode(node.promotedBound, functionTypeVariables,
          allowNull: true);
    }
  }

  @override
  void visitTypedefType(
      ir.TypedefType node, List<ir.TypeParameter> functionTypeVariables) {
    _sink.writeEnum(DartTypeNodeKind.typedef);
    _sink.writeTypedefNode(node.typedefNode);
    _sink.writeEnum(node.nullability);
    visitTypes(node.typeArguments, functionTypeVariables);
  }
}

/// Data sink helper that canonicalizes [E] values using indices.
class IndexedSink<E> {
  final DataSink _sink;
  Map<E, int> cache;

  IndexedSink(this._sink, {this.cache}) {
    // [cache] slot 0 is pre-allocated to `null`.
    this.cache ??= {null: 0};
  }

  /// Write a reference to [value] to the data sink.
  ///
  /// If [value] has not been canonicalized yet, [writeValue] is called to
  /// serialize the [value] itself.
  void write(E value, void writeValue(E value)) {
    const int pending = -1;
    int index = cache[value];
    if (index == null) {
      index = cache.length;
      _sink.writeInt(index);
      cache[value] = pending; // Increments length to allocate slot.
      writeValue(value);
      cache[value] = index;
    } else if (index == pending) {
      throw ArgumentError("Cyclic dependency on cached value: $value");
    } else {
      _sink.writeInt(index);
    }
  }
}

/// Data source helper reads canonicalized [E] values through indices.
class IndexedSource<E> {
  final DataSource _sourceReader;
  List<E> cache;

  IndexedSource(this._sourceReader, {this.cache}) {
    // [cache] slot 0 is pre-allocated to `null`.
    this.cache ??= [null];
  }

  /// Reads a reference to an [E] value from the data source.
  ///
  /// If the value hasn't yet been read, [readValue] is called to deserialize
  /// the value itself.
  E read(E readValue()) {
    int index = _sourceReader.readInt();
    if (index >= cache.length) {
      assert(index == cache.length);
      cache.add(null); // placeholder.
      E value = readValue();
      cache[index] = value;
      return value;
    } else {
      E value = cache[index];
      if (value == null && index != 0) {
        throw StateError('Unfilled index $index of $E');
      }
      return value;
    }
  }
}
