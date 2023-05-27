const std = @import("std");
const mem = std.mem;

pub const Value = union(enum) {
    boolean: bool,
    enumV: []u8,
    floatV: f64,
    intV: i64,
    string: []u8,
    variable: Variable,
    list: std.ArrayList(Value),
    object: std.StringHashMap(Value),
};

pub const FieldDefinition = struct {
    description: ?[]u8,
    name: []u8,
    arguments: std.ArrayList(InputValueDefinition),
    type: Type,
    directives: std.ArrayList(Directive),
};

pub const InputValueDefinition = struct {
    description: ?[]u8,
    name: []u8,
    type: Type,
    defaultValue: ?Value,
    directives: std.ArrayList(Directive),
};

pub const Document = struct {
    definitions: std.ArrayList(TopLevelDefinition),
};

pub const TopLevelDefinition = union(enum) {
    schema: SchemaDefinition,
    operation: OperationDefinition,
    fragment: FragmentDefinition,
    directive: DirectiveDefinition,
    scalar: ScalarDefinition,
    objectType: ObjectTypeDefinition,
    interface: InterfaceDefinition,
    unionD: UnionDefinition,
    enumD: EnumDefinition,
    inputObject: InputObjectDefinition,
};

pub const UnionDefinition = struct {
    description: ?[]u8,
    extend: bool,
    name: []u8,
    directives: std.ArrayList(Directive),
    types: std.ArrayList(NamedType),
};

pub const EnumValueDefinition = struct {
    description: ?[]u8,
    name: []u8,
    directives: std.ArrayList(Directive),
};

pub const EnumDefinition = struct {
    description: ?[]u8,
    extend: bool,
    name: []u8,
    directives: std.ArrayList(Directive),
    values: std.ArrayList(EnumValueDefinition),
};

pub const InputObjectDefinition = struct {
    description: ?[]u8,
    extend: bool,
    name: []u8,
    directives: std.ArrayList(Directive),
    fields: std.ArrayList(InputValueDefinition),
};

pub const ScalarDefinition = struct {
    description: ?[]u8,
    extend: bool,
    name: []u8,
    directives: std.ArrayList(Directive),
};

pub const ObjectTypeDefinition = struct {
    description: ?[]u8,
    extend: bool,
    name: []u8,
    interfaces: std.ArrayList(NamedType),
    directives: std.ArrayList(Directive),
    fields: std.ArrayList(FieldDefinition),
};

pub const InterfaceDefinition = struct {
    description: ?[]u8,
    extend: bool,
    name: []u8,
    interfaces: std.ArrayList(NamedType),
    directives: std.ArrayList(Directive),
    fields: std.ArrayList(FieldDefinition),
};

pub const SchemaDefinition = struct {
    description: ?[]u8,
    extend: bool,
    directives: std.ArrayList(Directive),
    operationTypes: std.AutoHashMap(OperationType, NamedType),
};

pub const OperationDefinition = struct {
    description: ?[]u8,
    name: ?[]u8,
    operationType: OperationType,
    variableDefinitions: std.ArrayList(VariableDefinition),
    directives: std.ArrayList(Directive),
    selectionSet: SelectionSet,
};

pub const FragmentDefinition = struct {
    name: []u8,
    typeCondition: NamedType,
    directives: std.ArrayList(Directive),
    selectionSet: SelectionSet,
};

pub const DirectiveDefinition = struct {
    description: ?[]u8,
    name: []u8,
    arguments: std.ArrayList(InputValueDefinition),
    repeatable: bool,
    locations: std.ArrayList(DirectiveLocation),
};

pub const DirectiveLocation = enum {
    QUERY,
    MUTATION,
    SUBSCRIPTION,
    FIELD,
    FRAGMENT_DEFINITION,
    FRAGMENT_SPREAD,
    INLINE_FRAGMENT,
    VARIABLE_DEFINITION,
    SCHEMA,
    SCALAR,
    OBJECT,
    FIELD_DEFINITION,
    ARGUMENT_DEFINITION,
    INTERFACE,
    UNION,
    ENUM,
    ENUM_VALUE,
    INPUT_OBJECT,
    INPUT_FIELD_DEFINITION,
};

pub const SelectionSet = std.ArrayList(Selection);

pub const Selection = union(enum) {
    field: Field,
    fragmentSpread: FragmentSpread,
    inlineFragment: InlineFragment,
};

pub const Field = struct {
    alias: ?[]u8,
    name: []u8,
    arguments: std.ArrayList(Argument),
    directives: std.ArrayList(Directive),
    selectionSet: ?SelectionSet,
};

pub const FragmentSpread = struct {
    name: []u8,
    directives: std.ArrayList(Directive),
};

pub const InlineFragment = struct {
    typeCondition: NamedType,
    directives: std.ArrayList(Directive),
    selectionSet: SelectionSet,
};

pub const VariableDefinition = struct {
    name: []u8,
    type: Type,
    defaultValue: ?Value,
    directives: std.ArrayList(Directive),
};

pub const Directive = struct {
    name: []u8,
    arguments: std.ArrayList(Argument),
};

pub const NamedType = []u8;
pub const Variable = []u8;

pub const Type = union(enum) {
    named: NamedType,
    list: ListType,
    nonNull: NonNullType,

    pub fn deinit(self: *Type, alloc: mem.Allocator) void {
        switch (self) {
            .named => |n| alloc.free(n),
            .list => |l| l.deinit(alloc),
            .nonNull => |nn| nn.deinit(alloc),
        }
    }
};

pub const ListType = *Type;
pub const NonNullType = *Type;

pub const Argument = struct {
    name: []u8,
    value: Value,
};

pub const OperationType = enum {
    Query,
    Mutation,
    Subscription,
};
