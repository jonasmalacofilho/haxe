package unit;

class TestSerialize extends Test {

	function id<T>( v : T ) : T {
		return haxe.Unserializer.run(haxe.Serializer.run(v));
	}

	function test() {
		// basic types
		var values : Array<Dynamic> = [null, true, false, 0, 1, 1506, -0xABCDEF, 12.3, -1e10, "hello", "éé", "\r\n", "\n", "   ", ""];
		for( v in values )
			eq( id(v), v );

		t( Math.isNaN(id(Math.NaN)) );
		t( id(Math.POSITIVE_INFINITY) > 0 );
		f( id(Math.NEGATIVE_INFINITY) > 0 );
		f( Math.isFinite(id(Math.POSITIVE_INFINITY)) );
		f( Math.isFinite(id(Math.NEGATIVE_INFINITY)) );

		// array/list
		doTestCollection([]);
		doTestCollection([1,2,4,5]);
		doTestCollection([1,2,null,null,null,null,null,4,5]);

		// date
		var d = Date.now();
		var d2 = id(d);
		t( Std.is(d2,Date) );
		eq( d2.toString(), d.toString() );

		// object
		var o = { x : "a", y : -1.56, z : "hello" };
		var o2 = id(o);
		eq(o.x,o2.x);
		eq(o.y,o2.y);
		eq(o.z,o2.z);

		// class instance
		var c = new MyClass(999);
		c.intValue = 33;
		c.stringValue = "Hello";
		var c2 = id(c);
		t( Std.is(c2,MyClass) );
		f( c == c2 );
		eq( c2.intValue, c.intValue );
		eq( c2.stringValue, c.stringValue );
		eq( c2.get(), 999 );
		// Class value
		eq( id(MyClass), MyClass );

		// enums
		haxe.Serializer.USE_ENUM_INDEX = false;
		doTestEnums();
		haxe.Serializer.USE_ENUM_INDEX = true;
		doTestEnums();
		// Enum value
		eq( id(MyEnum), MyEnum );

		// StringMap
		var h = new haxe.ds.StringMap();
		h.set("keya",2);
		h.set("kéyb",-465);
		var h2 = id(h);
		t( Std.is(h2,haxe.ds.StringMap) );
		eq( h2.get("keya"), 2 );
		eq( h2.get("kéyb"), -465 );
		eq( Lambda.count(h2), 2 );

		// IntMap
		var h = new haxe.ds.IntMap();
		h.set(55,2);
		h.set(-101,-465);
		var h2 = id(h);
		t( Std.is(h2,haxe.ds.IntMap) );
		eq( h2.get(55), 2 );
		eq( h2.get(-101), -465 );
		eq( Lambda.count(h2), 2 );

		// ObjectMap
		var h = new haxe.ds.ObjectMap();
		var a = new unit.MyAbstract.ClassWithoutHashCode(9);
		var b = new unit.MyAbstract.ClassWithoutHashCode(8);
		h.set(a, b);
		h.set(b, a);
		var h2 = id(h);
		t(Std.is(h2, haxe.ds.ObjectMap));
		// these are NOT the same objects
		f(h2.exists(a));
		f(h2.exists(b));
		// all these should still work
		t(h.exists(a));
		t(h.exists(b));
		eq(h.get(a), b);
		eq(h.get(b), a);
		var nothing = true;
		for (k in h2.keys()) {
			nothing = false;
			t(k.i == 8 || k.i == 9);
			t(h2.exists(k));
			var v = h2.get(k);
			t(v.i == 8 || v.i == 9);
		}
		f(nothing);

		// bytes
		doTestBytes(haxe.io.Bytes.alloc(0));
		doTestBytes(haxe.io.Bytes.ofString("A"));
		doTestBytes(haxe.io.Bytes.ofString("AB"));
		doTestBytes(haxe.io.Bytes.ofString("ABC"));
		doTestBytes(haxe.io.Bytes.ofString("ABCD"));
		doTestBytes(haxe.io.Bytes.ofString("héllé"));
		var b = haxe.io.Bytes.alloc(100);
		for( i in 0...b.length )
			b.set(i,i%10);
		doTestBytes(b);

		// recursivity
		c.ref = c;
		haxe.Serializer.USE_CACHE = true;
		var c2 = id(c);
		haxe.Serializer.USE_CACHE = false;
		eq( c2.ref, c2 );

		// errors
		#if !cpp
		exc(function() haxe.Unserializer.run(null));
		#end

		exc(function() haxe.Unserializer.run(""));

	}

	function doTestEnums() {
		eq( id(MyEnum.A), MyEnum.A );
		eq( id(MyEnum.B), MyEnum.B );
		var c = MyEnum.C(0,"hello");
		t( Type.enumEq( id(c), c ) );
		t( Type.enumEq( id(MyEnum.D(MyEnum.D(c))), MyEnum.D(MyEnum.D(c)) ) );
		t( Std.is(id(c),MyEnum) );
		t(switch( id(c) ) {
			case C(_,_): true;
			default: false;
		});

		eq( id(SimpleEnum.SE_A), SimpleEnum.SE_A );
		eq( id(SimpleEnum.SE_B), SimpleEnum.SE_B );
		eq( id(SimpleEnum.SE_C), SimpleEnum.SE_C );
		eq( id(SimpleEnum.SE_D), SimpleEnum.SE_D );
		t( id(SimpleEnum.SE_A) == SimpleEnum.SE_A );
	}

	function doTestCollection( a : Array<Dynamic> ) {
		var a2 = id(a);
		eq( a2.length, a.length );
		for( i in 0...a.length )
			eq( a2[i], a[i] );
		var l = Lambda.list(a);
		var l2 = id(l);
		t( Std.is(l2,List) );
		eq( l2.length, l.length );
		var it = l.iterator();
		for( x in l2 )
			eq( x, it.next() );
		f( it.hasNext() );
	}

	function doTestBytes( b : haxe.io.Bytes ) {
		var b2 = id(b);
		t( Std.is(b2,haxe.io.Bytes) );
		eq( b2.length, b.length );
		for( i in 0...b.length )
			eq( b2.get(i), b.get(i) );
		infos(null);
	}

	// mostly decoding tests only, ensuring previously serialized data will
	// still be readable; they can also sometimes catch incompatibilities
	// between implementation and spec
        function testSpec() {
		var unserialize = haxe.Unserializer.run;
		var serialize = haxe.Serializer.run;

		var nil = unserialize("n");
		eq( null, nil );

		var zero = unserialize("z");
		eq( 0, zero );
		var int = unserialize("i456");
		eq( 456, int );

		var nan = unserialize("k");
		t( Math.isNaN(nan) );
		var negInf = unserialize("m");
		f( Math.isFinite(negInf) );
		t( negInf < 0 );
		var posInf = unserialize("p");
		f( Math.isFinite(posInf) );
		t( posInf > 0 );
		var float = unserialize("d1.45e-8");
		eq( 1.45e-8, float );

		t( unserialize("t") );
		f( unserialize("f") );

		var string = unserialize("y10:hi%20there");
		t( Std.is(string, String) );
		eq( "hi there", string );

		var struct = unserialize("oy1:xi2y1:kng");
		eq( 2, struct.x );
		t( Reflect.hasField(struct, "k") );

		var list = unserialize("lnnh");
		t( Std.is(list, List) );
		aeq( [null, null], Lambda.array(list) );

		var array = unserialize("ai1i2u4i7ni9h");
		t( Std.is(array, Array) );
		aeq( [1, 2, null, null, null, null, 7, null, 9], array );

		var date = unserialize("v2010-01-01 12:45:10");
		t( Std.is(date, Date) );
		eq( new Date(2010, 0, 1, 12, 45, 10).getTime(), date.getTime() );

		var smap:Dynamic = unserialize("by1:xi2y1:knh");
		t( Std.is(smap, haxe.ds.StringMap) );
		eq( 2, Lambda.count( (smap:Iterable<Dynamic>) ) );
		eq( 2, smap.get("x") );
		eq( null, smap.get("k") );

		var imap:Dynamic = unserialize("q:4n:5i45:6i7h");
		t( Std.is(imap, haxe.ds.IntMap) );
		eq( 3, Lambda.count( (imap:Iterable<Dynamic>) ) );
		eq( null, imap.get(4) );
		eq( 45, imap.get(5) );
		eq( 7, imap.get(6) );

		// TODO ObjectMap

		var bytes:Dynamic = unserialize("s10:SGVsbG8gIQ");
		t( Std.is(bytes, haxe.io.Bytes) );
		eq( "Hello !", (bytes:haxe.io.Bytes).toString() );

		exc(unserialize.bind("xz"));

		var cl = unserialize("cy12:unit.MyClassy3:vali999y8:intValuei33y11:stringValuey5:Hellog");
		t( Std.is(cl, MyClass) );
		eq( 33, cl.intValue );
		eq( "Hello", cl.stringValue );
		eq( 999, cl.get() );

		var enum1 = unserialize("wy11:unit.MyEnumy1:B:0");
		t( Std.is(enum1, MyEnum) );
		t( Type.enumEq(enum1, MyEnum.B) );
		var enum2 = unserialize("wy11:unit.MyEnumy1:C:2zy2:Hi");
		t( Std.is(enum2, MyEnum) );
		t( Type.enumEq(enum2, MyEnum.C(0, "Hi")) );
		var enum3 = unserialize("jy11:unit.MyEnum:1:0");
		t( Std.is(enum3, MyEnum) );
		t( Type.enumEq(enum3, MyEnum.B) );
		var enum4 = unserialize("jy11:unit.MyEnum:2:2zy2:Hi");
		t( Std.is(enum4, MyEnum) );
		t( Type.enumEq(enum4, MyEnum.C(0, "Hi")) );

		var strings = ["foo", "bar", "foo", "bar", "foo"];
		var _strings = serialize(strings);
		eq( "ay3:fooy3:barR0R1R0h", _strings);
		aeq( strings, unserialize(_strings) );

		var clr:MyClass = unserialize("cy12:unit.MyClassy3:refr0g");
		eq( clr.ref, clr );

		// missing: custom c
	}

}

