/**
This module contains all the function-related templates.
Its main use is to generate functions from strings, with the naryFun template,
an extension of std.functional.unaryFun and binaryFun.
*/
module functional2;

import std.algorithm;
import std.array;
import std.bigint;
import std.contracts;
import std.conv;
import std.functional;
import std.math;
import std.metastrings;
import std.range;
import std.stdio;
import std.string;
import std.traits;
import std.typecons;
import std.typetuple;

import traits2;
import predicate;
import tuple2;
import range2;
import algorithm2;

/**
Gives the arity of a function: unary, binary, etc. A 0-args function has a arity of 0.

----
int foo0() { return 0;}
int foo1(int a) { return a;}
int foo2(int a, int b) { return a+b;}
T foo3(T, U)(T t, U u) { return t;} // templated
assert(arity!foo0 == 0);
assert(arity!foo1 == 1);
assert(arity!foo2 == 2);
----

It does not work on non-instantiated template functions (because they
are not functions) and gives an arity of 1 for variadic functions, because
their variadic list is considered as one arg.
----
T foo(T)(T t) { ...};
auto a = arity!foo; // error !
auto b = arity!(foo!int); // OK.
//
int foov(int a...) { return 0;}
assert(arity!foov == 1);
----
*/
template arity(alias fun) if (isFunction!fun) {
    enum size_t arity = ParameterTypeTuple!(fun).length;
}

template arity(string fun)
{
    alias aritySImpl!(" " ~ fun ~ " ",0).result arity;
}

unittest {
    int foo0() { return 0;}
    int foo1(int a) { return a;}
    int foo2(int a, int b) { return a+b;}
    T foo3(T, U)(T t, T tt, U u) { return t;} // templated
    assert(arity!foo0 == 0);
    assert(arity!foo1 == 1);
    assert(arity!foo2 == 2);
    assert(!__traits(compiles, arity!foo3)); // does not work on non-instantiated functions
    assert(arity!(foo3!(int,double)) == 3);  // foo3!(int, double) is a 3-args function

    int foov(int a...) { return 0;}
    assert(arity!foov == 1);
}

template IsBetween(char c, char a, char b) {
    static if ((to!int(c) >= to!int(a)) && (to!int(c) <= to!int(b) )) {
        enum bool IsBetween = true;
    }
    else {
        enum bool IsBetween = false;
    }
}

template IsOneChar(char a, char b, char c)
{
    static if(!(IsBetween!(a, 'A', 'Z') || IsBetween!(a, 'a', 'z'))
           &&   IsBetween!(b, 'a', 'z')
           && !(IsBetween!(c, 'A', 'Z') || IsBetween!(c, 'a', 'z')))
    {
        enum bool IsOneChar = true;
    }
    else
    {
        enum bool IsOneChar = false;
    }
}

template CharArity(char a)
{
    enum int CharArity = to!int(a) - 96;
}

template aritySImpl(string s, size_t index)
{
    static if (s.length > 3)
    {
        static if (IsOneChar!(s[0], s[1], s[2]) && (CharArity!(s[1])>index))
        {
            alias aritySImpl!(s[1..$], CharArity!(s[1])).result result;
        }
        else
        {
            alias aritySImpl!(s[1..$], index).result result;
        }
    }
    else
    {
        static if (s.length == 3) {
            static if (IsOneChar!(s[0], s[1], s[2]) && (CharArity!(s[1])>index))
            {
                alias CharArity!(s[1]) result;
            }
            else
            {
                alias index result;
            }
        }
        else
        {
            enum size_t result = 0;
        }
    }
}

/**
Is true iff fun can be applied on the TypeTuple ARGS.
Example:
----
assert(CompatibilityFuncArgs!("a+b", int, int)); // 'string' function are templated by unaryFun or binaryFun
                                                 // They will always be compatible with their args
assert(CompatibilityFuncArgs!(binaryFun!"a+b", int, int));

int foo(int a, double b) { return a;}
assert(CompatibilityFuncArgs!(foo, int, double));
assert(CompatibilityFuncArgs!(foo, int, int)); // You can pass an int as second argument for foo, as it will be converted
assert(!CompatibilityFuncArgs!(foo, double, double));  // But not a double as first arg.
assert(!CompatibilityFuncArgs!(foo, int, string));

int bar() { return 0;}
assert(CompatibilityFuncArgs!bar); // For bar, no args...
assert(CompatibilityFuncArgs!(bar, TypeTuple!())); // For bar, no args...

assert(CompatibilityFuncArgs!((int a) { return -a;}, int)); // Works for anonymous functions
----
*/
template CompatibilityFuncArgs(alias fun, ARGS...) if (isFunction!(fun)) {
    enum bool CompatibilityFuncArgs = __traits(compiles, {
                                                            ARGS args;
                                                            fun(args);
                                                         }
                                              );
}

template CompatibilityFuncArgs(alias fun, ARGS...) if (!isFunction!(fun)) {
   static if (is(typeof(fun) : string)) {
        enum bool CompatibilityFuncArgs = true;
    }
    else {
        enum bool CompatibilityFuncArgs = __traits(compiles, {
                                                                ARGS args;
                                                                fun!(ARGS)(args);
                                                            }
                                                   );
    }
}

unittest {
    assert(CompatibilityFuncArgs!("a+b", int, int)); // 'string' function are templated by unaryFun or binaryFun
                                                     // They will always be compatible with their args
    assert(CompatibilityFuncArgs!(binaryFun!"a+b", int, int));

    int foo(int a, double b) { return a;}
    assert(CompatibilityFuncArgs!(foo, int, double));
    assert(CompatibilityFuncArgs!(foo, int, int)); // You can pass an int as second argument for foo, as it will be converted
    assert(!CompatibilityFuncArgs!(foo, double, double));  // But not a double as first arg.
    assert(!CompatibilityFuncArgs!(foo, int, string));

    int bar() { return 0;}
    assert(CompatibilityFuncArgs!bar); // For bar, no args...
    assert(CompatibilityFuncArgs!(bar, TypeTuple!())); // For bar, no args...

    assert(CompatibilityFuncArgs!((int a) { return -a;}, int)); // Works for anonymous functions
}


template Loop(uint n, uint max, alias Action)
{
    static if (n < max) {
        enum string Loop = Action(n, max) ~ Loop!(n+1, max, Action);
    }
    else{
        enum string Loop = "";
    }
}

string az(uint n)  { return "abcdefghijklmnopqrstuvwxyz"[n..n+1];}
string PTL(uint n, uint max) { return "ElementType" ~ to!string(n) ~ (n < max-1 ? ", " : "");}
string PNL(uint n, uint max) { return " ElementType" ~ to!string(n) ~ " " ~ az(n) ~ ";";}
string BNL(uint n, uint max) { return " ElementType" ~ to!string(n) ~ " __" ~ az(n) ~ (n < max-1 ? ", " : "");}
string AL(uint n, uint max)  { return " alias __" ~ az(n) ~ " " ~ az(n) ~ ";";}

/**
A generalization of std.functional.unaryFun and .binaryFun for as many params as you need, in the 'a' - 'z' (included)
range. You can indicate the desired final arity if you want but otherwise a compile-time heuristics
tries to determine the string's 'arity'.
As for unaryFun and binaryFun, 'a' means first argument, 'b' the second and so on.
As for unaryFun and binaryFun, it creates a templated function, with the type of each parameter left undecided.
As for unaryFun and binaryFun, it does not change fun if it's already a function.
Examples:
----
alias naryFun!("a+b*c-d") test4;  // Creates a templated 4-args function test4(A, B, C, D)(A a, B b, C c, D d) { return a+b*c-d;}
assert(test4(1,2,3,4) == 3);        // instantiate test4!(int, int, int, int)
assert(test4(1.0,2.0,3,4) == 3.0);  // instantiate test4!(double, double, int, int)

alias naryFun!("a+b",3) test3;      // You can create a fun with more args than necessary, if you wish
assert(test3(1,2,100) == 3);        // without the 3, naryFun!"a+b" would create a binary function.
assert(test3(1.0,2.0,100) == 3.0);

alias naryFun!"sin(a)+cos(b)*c" testsincos; // functional2.d imports a lot of other D modules, to have their functions accessible.

alias naryFun!"tuple(a,a,a)" toTuple;
assert(toTuple(1) == tuple(1,1,1));

alias naryFun!"a.expand[1]" tuple1; // tuple1 will be created, but can be used only on types defining a .expand field.
assert(tuple1(toTuple(1)) == 1);

alias naryFun!"[b,a,c]" arrayTwister; // will return a static array
assert(arrayTwister(0,1,2) == [1,0,2]);

alias naryFun!"f" projection6; // 'a' -> 1 arg, 'b' -> binary, ..., 'f' -> 6-args function. In this case, returning only its sixth argument.
assert(projection6(0,1,2,3,4,5) == 5);

alias naryFun!"3" test0;               // A 0-arg function. It's exactly: int test0() { return 3;}
assert(test0 == 3);                    // Constant return
assert(is(typeof(test0) == function)); // But it's a function, not a constant.

int foo(int a, int b) { return a*b;}
alias naryFun!(foo) nfoo;           // function test
assert(nfoo(2,3) == 6);

int bar() { return 1;}
alias naryFun!bar nbar;             // 0-arg function test
assert(nbar == 1);
----
*/
template naryFun(string fun, uint Nparam)
{
    alias naryFunImpl!(fun, Nparam).result naryFun;
}
/// ditto
template naryFun(string fun)
{
    alias naryFunImpl!(fun, arity!fun).result naryFun;
}

// Works OK, but only at runtime. I need to code this for compile-time.
// OK, done.
/*
size_t arityHeuristics(string s) {
    auto padded = " " ~ s ~ " ";
    char[] paddedchars = cast(char[])padded; // To get rid of those pesky immutable(char)
    bool isaz(char c) { return isOneOf!lowercase(c);} // lowercase is defined in std.string
    bool isazAZ(char c) { return isOneOf!letters(c);} // letters is defined in std.string
    bool isOneChar(char a, char b, char c) { return !isazAZ(a) && isaz(b) && !isazAZ(c);}
    size_t charArity(char c) { return to!int(c)-96;} // 1 for 'a', 2 for 'b'
    size_t loneIndex(char a, char b, char c) { return isOneChar(a,b,c) ? charArity(b) : 0;}
    auto loneIndices = nMap!loneIndex(paddedchars);
    return reduce!max(loneIndices);
}
*/

template naryFunImpl(alias fun, uint Nparam) if (is(typeof(fun) : string))
{
    static if (Nparam > 0)
    {
        enum string paramTypeList = Loop!(0, Nparam, PTL);
        enum string paramNameList = Loop!(0, Nparam, PNL);
        enum string bodyNameList  = Loop!(0, Nparam, BNL);
        enum string aliasList     = Loop!(0, Nparam, AL);
        enum string code = "typeof({" ~ paramNameList ~ " return (" ~ fun ~ ");}()) result(" ~ paramTypeList ~ ")(" ~ bodyNameList ~ ") { " ~ aliasList ~ " return (" ~ fun ~ ");}";
    }
    else
    {
        enum string code = "typeof((){return " ~ fun ~ ";}()) result() {return " ~fun ~ ";}";
    }

    mixin(code);
}

/// ditto
template naryFun(alias fun, uint Nparam) if (!is(typeof(fun): string) && (arity!(fun) == Nparam))
{
    alias fun naryFun;
}

/// ditto
template naryFun(alias fun) if (!is(typeof(fun): string))
{
    alias fun naryFun;
}

unittest
{
    alias naryFun!("a+b*c-d") test4;  // Creates a templated 4-args function test4(A, B, C, D)(A a, B b, C c, D d) { return a+b*c-d;}
    assert(test4(1,2,3,4) == 3);        // instantiate test4!(int, int, int, int)
    assert(test4(1.0,2.0,3,4) == 3.0);  // instantiate test4!(double, double, int, int)

    alias naryFun!("a+b",3) test3;      // You can create a fun with more args than necessary, if you wish
    assert(test3(1,2,100) == 3);        // without the 3, naryFun!"a+b" would create a binary function.
    assert(test3(1.0,2.0,100) == 3.0);

    alias naryFun!"sin(a)+cos(b)*c" testsincos; // functional2.d imports a lot of other D modules, to have their functions accessible.

    alias naryFun!"tuple(a,a,a)" toTuple;
    assert(toTuple(1) == tuple(1,1,1));

    alias naryFun!"a.expand[1]" tuple1; // tuple1 will be created, but can be used only on types defining a .expand field.
    assert(tuple1(toTuple(1)) == 1);

    alias naryFun!"[b,a,c]" arrayTwister; // will return a static array
    assert(arrayTwister(0,1,2) == [1,0,2]);

    alias naryFun!"f" projection6; // 'a' -> 1 arg, 'b' -> binary, ..., 'f' -> 6-args function. In this case, returning only its sixth argument.
    assert(projection6(0,1,2,3,4,5) == 5);

    alias naryFun!"3" test0;               // A 0-arg function. It's exactly: int test0() { return 3;}
    assert(test0 == 3);                    // Constant return
    assert(is(typeof(test0) == function)); // But it's a function, not a constant.

    int foo(int a, int b) { return a*b;}
    alias naryFun!(foo) nfoo;           // function test
    assert(nfoo(2,3) == 6);

    int bar() { return 1;}
    alias naryFun!bar nbar;             // 0-arg function test
    assert(nbar == 1);
}

/+ deprecated
/**
Fills a TypeTuple of T's (T,T,T, ...) from a T[] array of values. It's
the TypeTuple's length which drives the transfer: it
Used to convert the elements of a Segment (ie: T[]) into a TypeTuple to be used
in a function.
*/
void fillFromArray(Arr : T[], T, Tup...)(Arr arr, ref Tup tup) {
    static if (Tup.length > 0) {
        tup[0] = arr[0];
        fillFromArray(arr[1..$], tup[1..$]);
    }
}

unittest {
    double[] d = [0.0, 1.0, 2.0];
    TypeTuple!(double, double, double) td;
    fillFromArray(d, td);
    assert(td[0] == 0.0);
    assert(td[1] == 1.0);
    assert(td[2] == 2.0);
}
+/

/+
/**
For a function fun with arguments types (T, T, T, ...) calls the function
from a T[] array of arguments.
Example:
----
int foo(int a, int b, int c) {
    return a*b*c;
}

auto arr = [1,2,3];

// not possible:
// foo(arr);
// so we do:
arrayApply!(foo)(arr); // return 1*2*3 -> 6.
----
*/
auto arrayApply(alias fun, T : U[], U)(T args) if (CompatibilityFuncArgs!(fun, TypeNuple!(U, arity!fun))) {
    TypeNuple!(U, arity!fun) at;
    fillFromArray(args, at);
    return fun(at);
}

unittest {
    int foo(int a, int b, int c) {
        return a*b*c;
    }

    auto arr = [1,2,3];

    // foo(arr); // not possible
    // so we do:
    arrayApply!foo(arr); // return 1*2*3 -> 6.
}

/**
Transforms a function with parameters of same type: foo(T, T, T, ...) into an
array-accepting function afoo(T[]). Useful to map a function on a Segment range:
to map a binary or n-ary function on a range. See below.
*/
template arrayify(alias fun) {
    alias arrayifyImpl!(fun).result arrayify;
}

template arrayify(alias fun, T) {
    alias TypeNuple!(T, arity!fun) TN;
    alias fun!(TN) fun2;
    alias arrayifyImpl!(fun2).result arrayify;
}

template arrayifyImpl(alias fun) {
    alias ReturnType!fun R;
    alias ParameterTypeTuple!fun A;
    static if (A.length > 0) {
        R result(A[0][] arr) {
            return arrayApply!fun(arr);
        }
    }
    else {
        R result() {
            return fun();
        }
    }
}

unittest {
    int foo(int a, int b, int c) {
        return a*b*c;
    }

    auto arr = [1,2,3];
    alias arrayify!foo afoo; // afoo is now an int[3] or int[] accepting function
    assert(is(typeof(&afoo) == int delegate(int[])));
    assert(arity!afoo == 1); // afoo is indeed a unary function now.
    assert(afoo(arr) == 6); // We can apply afoo on arr.
    assert(afoo([2,3,4]) == 24); // Works on int[3] arrays also
    assert(!is(afoo([1,2]))); // But afoo rejects int[2] arrays.

    auto r1 = [1,2,3,4,5,6];

    double average(int a, int b, int c) {
        return (a+b+c)/3.0;
    }
    alias arrayify!average mean;
    assert(is(typeof(&mean) == double delegate(int[])));
//    auto s = segment!3(r1); // We cannot map 'average' on s
//    auto m = map!mean(s); // But we can map 'mean'
//    assert(asString(m, " ") == "2 3 4 5");
}
+/

/+ deprecated
/**
Fills a TypeTuple of different types from a std.typecons.Tuple of values.
Used to convert the result of a TupleRange into a TypeTuple to be used
in a function.
*/
void fillFromTuple(size_t n = 0, T : Tuple!(TT), TT...)(T tup, ref TT typetup) {
    static if (n < TT.length) {
        typetup[n] = tup.field[n];
        fillFromTuple!(n+1)(tup, typetup);
    }
}

unittest {
    auto tup = tuple(0, 'a', 1.23);
    TypeTuple!(int, char, double) tt;
    fillFromTuple(tup, tt);
    assert(tt[0] == 0);
    assert(tt[1] == 'a');
    assert(tt[2] == 1.23);
}

/**
Given a std.typecons.Tuple of values args, expand the Tuple and _apply fun to it.
It's useful to map a n-ary function on a Tuple-outputting range.
Note that apply will check that the Tuple can indeed be used
as parameters for the function. If args is longer than
ParameterTypeTuple!fun, any remaining values will be ignored.

Example:
----
string foo3(int a, string b, double c) {
    return to!string(a) ~ "+" ~ b ~ "+" ~ to!string(c);
}
auto t = tuple(1, "a", 3.0);
writeln(tupleApply!foo3(t)); // Write "1+a+3"
----
*/
auto tupleApply(alias fun, T : Tuple!(R), R...)(T args) if (CompatibilityFuncArgs!(fun, R)) {
    TypeTuple!R tt;
    fillFromTuple(args, tt);
    return fun!(R)(tt[0 .. R.length]);
}

unittest {
    string foo3(int a, string b, double c) {
        return to!string(a) ~ "+" ~ b ~ "+" ~ to!string(c);
    }
    auto t = tuple(1, "a", 3.0);
    assert(tupleApply!foo3(t) == "1+a+3"); // Applies foo3 to t
}
+/

/**
Transforms a function into a tuple-accepting function. Useful to map a standard function
on a tuple-producing range. A parameterless function (zero args) is left untouched.
See_Also: tmap, tfilter, comprehension, parallelComprehension in algorithm2.d
Example:
----
string foo3(int a, string b, double c) {
    return to!string(a) ~ "+" ~ b ~ "+" ~ to!string(c);
}

auto tfoo3 = tuplify!foo3;
auto t = tuple(1, "a", 3.0);
auto result = tfoo3(t);
assert(result == "1+a+3");

string foo() {
    return "aha";
}
auto tfoo = tuplify!foo;
assert(tfoo() == "aha");
----
*/
template tuplify(alias fun) {
    alias tuplifyImpl!(fun).result tuplify;
}

template tuplifyImpl(alias fun) {
    alias ReturnType!fun R;
    alias ParameterTypeTuple!fun A;
    static if (A.length > 0) {
        R result(Tuple!(A) tup) {
                return fun(tup.field);
        }
    }
    else {
        R result() {
            return fun();
        }
    }
}
//
//auto tuplify(R, A...)(R delegate(A) fun) {
//    static if (A.length == 0) {
//        return fun;
//    }
//    else {
//        R tuplified(Tuple!(A) tup) {
//            return tupleApply!fun(tup);
//        }
//        return &tuplified;
//    }
//}
//
unittest {
    string foo3(int a, string b, double c) {
        return to!string(a) ~ "+" ~ b ~ "+" ~ to!string(c);
    }

    alias tuplify!foo3 tfoo3;
    auto t = tuple(1, "a", 3.0);
    auto result = tfoo3(t);
    assert(result == "1+a+3");

    string foo() { return "aha";}
    alias tuplify!foo tfoo;
    assert(tfoo == "aha");
}

/**
Internal template to transform a function or a 'string' function
to be applied on a tuple. The R... part must contains the information
about the args types. It's used to instantiate the correct function
from the template function created by naryFun.

It's used internally by all the tuple-mapping functions: tmap, tfilter, etc.
*/
template Prepare(alias fun, R...)
{
    alias PrepareImpl!(fun, R).result Prepare;
}

template PrepareImpl(alias fun, R...)
{
    alias naryFun!(fun, R.length) nfun; // transforms string as n-args templated function.
    static if (__traits(compiles, nfun!R)) // Can I instantiate nfun!R?
        alias nfun!R infun;  // instantiates n-fun.
    else
        alias nfun infun;    // It's a function, do nothing.
    alias tuplify!infun result;
}
