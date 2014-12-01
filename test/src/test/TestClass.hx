package test;

/**
 * ...
 * @author Yanrishatum
 */
class TestClass
{

  public function new() 
  {
    
  }
  
  public static var publicStaticVar:Int;
  private static var privateStaticVar:Int;
  
  public var array:Array<Dynamic>;
  public var array2:Array<Int>;
  public var array3:Array<Array<TestClass>>;
  
  public static function publicStaticFunction():Void
  {
    
  }
  
  
  
  public var publicVar:Dynamic;
  private var privateVar:Dynamic;
  
  public var property(get, set):Int;
  private inline function get_property():Int { return 0; }
  private inline function set_property(v:Int):Int { return v; }
  
  public var readOnly(get, never):Int;
  private inline function get_readOnly():Int { return 1; }
  
  public var writeOnly(never, set):Int;
  private inline function set_writeOnly(v:Int):Int { return v; }
  
  public function publicFunction(arg0:Dynamic, arg1:Dynamic):Dynamic
  {
    return null;
  }
  
  public function privateFunction():Void
  {
    
  }
  
}