/********************
 * imports, exports *
 ********************/

import * as Start from './everything';
export type { A, B, C };

/**************
 * let, const *
 **************/

let someNumberVar = 123;

const NUMBER_CONST = 123;
const NUMBER_CONST_TYPED: number = 246;
const STRING_CONST = "ABC";
const OBJECT_CONST = { a: 1, b: 2, c: 3 };
const TUPLE_CONST: [string, number] = ["test", 123];

const UserDefinedSymbol = Symbol();
const MySymbol: unique symbol;

/****************
 * type aliases *
 ****************/

type StringAlias = string
type UnionType = string | number | boolean;
type Point = [number, number];
type ConditionalType<T> = T extends string ? string[] : number[];
type MappedType<T> = { [K in keyof T]: T[K] | null };
type EventName<T extends string> = `on${Capitalize<T>}`;
type Routes = `/${string}`;
type ReturnType<T> = T extends (...args: any[]) => infer R ? R : never;
type First<T> = T extends [infer F, ...any[]] ? F : never;

export type ExportedType = { id: number };
export default type DefaultType = string;

/*********
 * enums *
 *********/

enum Direction {
  Up = 1,
  Down,
  Left,
  Right,
}

const enum ConstEnum {
  Value1 = "string_value",
  Value2 = 42,
}

declare enum DeclaredEnum {
  Option1,
  Option2,
}

export enum ExportedEnum {
  First = "first",
  Second = "second",
}

enum ComputedEnum {
  A = 1 << 1,
  B = 1 << 2,
  C = A | B,
}

/*************
 * functions *
 *************/

function emptyFunction() {};
function emptyTypedFunction(a: number, s: string): void {};
async function emptyFunctionAsync() {};

function destructured({name, age}: {name: string, age: number}) {}
function optionalParams(required: string, optional?: number, defaulted: boolean = true) {}
function mixedParams(first: string, ...rest: number[]) {}

function overloadedFunction(x: string): string;
function overloadedFunction(x: number): number;
function overloadedFunction(x: boolean): boolean;
function overloadedFunction(x: string | number | boolean): string | number | boolean {
    return x;
}

function genericFunction<T>(param: T): T { return param; }
function constrainedGeneric<T extends string | number>(param: T): T { return param; }

/*******************
 * arrow functions *
 *******************/

const arrowFun = () => {};

// make sure that types show up in details correctly
const typedArrowFun = (a: string): void => { aaaaa };

type FunType = () => number;
const typedWithAliasArrowFun: FunType = () => {};

function nestedFunction(): void {
    function f() {}
    const a = () => {};
}

/***********
 * classes *
 ***********/

class A {
    methodFirst() {}

    regularProp: string = "test";

    constructor(
        public publicProp: string,
        private privateProp: number,
        normalParam: any  // should NOT become a property
    ) {}

    methodSecond() {}

    propertyAtEnd: boolean = true;

    methodLast() {}
}

class B {
    private static b = 123;
    c?: string;
    d: string = '';
    readonly xyz = 'abc';
    #privateVar = 123;

    constructor(c?: string | number) {
        if (typeof c === 'number') {
            this.c = 'num';
        } else {
            this.c = c || '';
        }
    }
}

function decorator(f) { return f; }

class C extends B {
    method() {}

    @decorator
    decoratedMethodA() {}

    @decorator()
    decoratedMethodB() {}

    private f() {}
}

class D implements Int {
    foo() {}
}

class GenericClass<T, U = string> {
    private value: T;
    constructor(value: T) {
        this.value = value;
    }

    someMethod<T>(): void {}
}

class MultipleInheritance extends AbstractClass implements Int {
    abstractMethod() {}
    foo() {}
}

export class ExportedClass {
    static staticMethod() {}
}

export default class DefaultExportClass {
    defaultMethod() {}
}

class WithComplexGenerics<T extends Record<string, any>, K extends keyof T> {
    process(obj: T, key: K): T[K] {
        return obj[key];
    }
}

// Constructor overloads testing
class ConstructorOverloads {
    private value: string | number;

    constructor(name: string);
    constructor(id: number);
    constructor(name: string, suffix: string);
    constructor(nameOrId: string | number, suffix?: string) {
        if (typeof nameOrId === "string" && suffix) {
            this.value = nameOrId + suffix;
        } else {
            this.value = nameOrId;
        }
    }

    getValue(): string | number {
        return this.value;
    }
}

// Additional property examples for testing
class PropertyExamples {
    // Basic properties
    public name: string;
    private age: number = 25;
    protected email: string = "test@example.com";

    // Static properties
    static readonly VERSION: string = "1.0.0";
    static count: number = 0;

    // Optional and readonly
    readonly id: number;
    optional?: boolean;

    // Complex types
    callback: (value: string) => void;
    data: { [key: string]: any };
    items: Array<{ id: number; name: string }>;

    // Computed/getter properties
    get fullName(): string {
        return this.name;
    }

    set fullName(value: string) {
        this.name = value;
    }
}

class ClassIndexSignature {
  [key: string]: any;
  [index: number]: string;

}

class WithStaticBlock {
    static { }
}

class DecoratedProps {
    @validate
    @transform
    decoratedProp: string = "test";
}

const key = "dynamicKey";
class ComputedProperties {
    [key]: string;
    ["literalKey"]: number;
}

/*************
 * interface *
 *************/

interface SimpleInterface {
    name: string;
    age: number;
}

interface GenericInterface<T> {
    data: T;
    process(item: T): T;
}

interface ExtendedInterface extends SimpleInterface {
    email: string;
}

interface MultipleExtends extends SimpleInterface, GenericInterface<string> {
    id: number;
}

interface WithMethods {
    readonly id: number;
    optional?: string;
    method(): void;
    genericMethod<T>(param: T): T;
}

export interface ExportedInterface {
    exported: boolean;
}

interface ComplexGenericInterface<T extends Record<string, any>, U = keyof T> {
    process<V extends U>(key: V): T[V];
}

interface IndexSignature {
    [key: string]: any;
    [index: number]: string;
}

interface Callable {
    // not supported
    (param: string): number;

    // not supported
    new (param: string): SomeClass;
}

interface MergedInterface {
  prop1: string;
}

interface MergedInterface {
  prop2: number;
}

/*************
 * namespace *
 *************/

namespace TypedNamespace {
    export type NestedType = string;
    type PrivateType = number;

    export namespace InnerNamespace {
        type DeepType = boolean;
        function deepFunction(): DeepType { return true; }
    }
}

namespace EmptyNamespace {
}

namespace NestedNamespaces {
    namespace Level1 {
        namespace Level2 {
            namespace Level3 {
                function deeplyNested() {}
            }
        }
    }
}

export namespace ExportedNamespace {
    export function exportedFunction() {}
    export const exportedConst = "test";
}

declare namespace DeclaredNamespace {
    function declaredFunction(): void;
    const declaredConst: string;
}


abstract class AbstractClassMethods {
    abstract abstractMethod(): void;

    concreteMethod() {
        return "concrete";
    }
}

/***********
 * declare *
 ***********/

declare const DECLARED_CONST;
declare const MySymbol: unique symbol;

declare function getWidget(n: number): Widget;
declare function getWidget(s: string): Widget[];

declare class Greeter {
  constructor(greeting: string);
  greeting: string;
  showGreeting(): void;
}

declare namespace GreetingLib.Options {
  function makeGreeting(s: string): string;
  let numberOfGreetings: number;

  interface Log {
    verbose?: boolean;
  }
  interface Alert {
    modal: boolean;
    title?: string;
    color?: string;
  }
}

declare module "SomeModule" {
  export function fn(): string;

  interface Request {
    user?: { id: string; name: string };
  }
}

declare global {
  interface Window {
    myCustomProperty: string;
  }
}
