// Field accesses carry the alignment the field's offset guarantees within its
// aggregate, instead of the field type's ABI alignment.
// RUN: %ldc -c -output-ll -of=%t.ll %s && FileCheck %s < %t.ll

align(1) struct Packed { ubyte tag; uint u; S8 s; }
struct S8 { long a; int b; }
align(1) struct Unaligned(T) { T value; }
struct Outer { int pad; Inner inner; }
struct Inner { int a; long b; }
class C { int i; S8 s; }

// CHECK-LABEL: define {{.*}}_D{{.*}}packedLoad
uint packedLoad(ref Packed p)
{
    // CHECK: load i32, ptr %{{.*}}, align 1
    return p.u;
}

// CHECK-LABEL: define {{.*}}_D{{.*}}packedStore
void packedStore(ref Packed p, uint v)
{
    // CHECK: store i32 %{{.*}}, ptr %{{.*}}, align 1
    p.u = v;
}

// CHECK-LABEL: define {{.*}}_D{{.*}}packedCopy
void packedCopy(ref Packed dst, ref S8 src)
{
    // CHECK: call void @llvm.memcpy.{{.*}}(ptr align 1 %{{.*}}, ptr align 8 %{{.*}}, i{{32|64}} 16
    dst.s = src;
}

// CHECK-LABEL: define {{.*}}_D{{.*}}unalignedStore
void unalignedStore(Unaligned!long* p)
{
    // CHECK: store i64 1, ptr %{{.*}}, align 1
    p.value = 1;
}

// CHECK-LABEL: define {{.*}}_D{{.*}}nestedField
long nestedField(ref Outer o)
{
    // CHECK: load i64, ptr %{{.*}}, align 8
    return o.inner.b;
}

// CHECK-LABEL: define {{.*}}_D{{.*}}classField
void classField(C c, ref S8 src)
{
    // CHECK: call void @llvm.memcpy.{{.*}}(ptr align 8 %{{.*}}, ptr align 8 %{{.*}}, i{{32|64}} 16
    c.s = src;
}

// CHECK-LABEL: define {{.*}}_D{{.*}}staticArrayElement
void staticArrayElement(ref S8[4] a, ref S8 src, size_t i)
{
    // CHECK: call void @llvm.memcpy.{{.*}}(ptr align 8 %{{.*}}, ptr align 8 %{{.*}}, i{{32|64}} 16
    a[i] = src;
}

// CHECK-LABEL: define {{.*}}_D{{.*}}packedArrayElement
uint packedArrayElement(ref Unaligned!(uint[2]) a)
{
    // CHECK: load i32, ptr %{{.*}}, align 1
    return a.value[1];
}

// CHECK-LABEL: define {{.*}}_D{{.*}}packedSlice
size_t packedSlice(ref Unaligned!(int[]) a)
{
    // CHECK: load {{i32|i64}}, ptr %{{.*}}, align 1
    return a.value.length;
}

// CHECK-LABEL: define {{.*}}_D{{.*}}packedIncrement
void packedIncrement(ref Packed p)
{
    // CHECK: load i32, ptr %{{.*}}, align 1
    // CHECK: store i32 %{{.*}}, ptr %{{.*}}, align 1
    p.u++;
}

struct Big { long[4] a; }
align(1) struct PackedBig { ubyte tag; Big b; }
Big makeBig();

// A misaligned field isn't handed to a callee as its sret pointer.
// CHECK-LABEL: define {{.*}}_D{{.*}}packedSret
PackedBig packedSret()
{
    // CHECK: %[[TMP:.*]] = alloca %field_alignment.Big, align 8
    // CHECK: call {{.*}}makeBig{{.*}}(ptr {{.*}}sret{{.*}} %[[TMP]])
    // CHECK: call void @llvm.memcpy.{{.*}}(ptr align 1 %{{.*}}, ptr align 8 %[[TMP]], i{{32|64}} 32
    return PackedBig(1, makeBig());
}

// CHECK-LABEL: define {{.*}}_D{{.*}}refLocalCopy
void refLocalCopy(ref Packed dst, ref S8 src)
{
    ref S8 r = dst.s;
    // CHECK: call void @llvm.memcpy.{{.*}}(ptr align 1 %{{.*}}, ptr align 8 %{{.*}}, i{{32|64}} 16
    r = src;
}

struct U2 { uint a, b; }
align(1) struct PackedArray { ubyte tag; uint[2] a; }

// CHECK-LABEL: define {{.*}}_D{{.*}}castCopy
void castCopy(ref PackedArray p, ref U2 dst)
{
    // CHECK: call void @llvm.memcpy.{{.*}}(ptr align 4 %{{.*}}, ptr align 1 %{{.*}}, i{{32|64}} 8
    dst = cast(U2) p.a;
}

// An NRVO variable lives in the caller's sret buffer, which is only aligned for
// the variable's type.
// CHECK-LABEL: define {{.*}}_D{{.*}}nrvoOverAligned
Big nrvoOverAligned(ref Big src)
{
    align(64) Big b = void;
    // CHECK: call void @llvm.memcpy.{{.*}}(ptr align 8 %{{.*}}, ptr align 8 %{{.*}}, i{{32|64}} 32
    b = src;
    return b;
}

S8 globalS8;

// CHECK-LABEL: define {{.*}}_D{{.*}}globalCopy
void globalCopy(ref S8 src)
{
    // CHECK: call void @llvm.memcpy.{{.*}}(ptr align 8 @{{.*}}globalS8{{.*}}, ptr align 8 %{{.*}}, i{{32|64}} 16
    globalS8 = src;
}

int globalInt;

// CHECK-LABEL: define {{.*}}_D{{.*}}readGlobal
int readGlobal()
{
    // CHECK: load i32, ptr @{{.*}}globalInt{{.*}}, align 4
    return globalInt;
}

// CHECK-LABEL: define {{.*}}_D{{.*}}castLoad
uint castLoad(ref PackedArray p)
{
    // CHECK: load i32, ptr %{{.*}}, align 1
    return (cast(U2) p.a).a;
}
