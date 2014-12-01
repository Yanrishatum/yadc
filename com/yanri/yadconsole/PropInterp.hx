package com.yanri.yadconsole;

#if hscript
import hscript.Interp;

/**
 * ...
 * @author Yanrishatum
 */
class PropInterp extends Interp
{

  public function new() 
  {
    super();
  }
  
  override function get(o:Dynamic, f:String):Dynamic 
  {
		if( o == null ) error(EInvalidAccess(f));
		return Reflect.getProperty(o,f);
  }
  
  override function set(o:Dynamic, f:String, v:Dynamic):Dynamic 
  {
		if( o == null ) error(EInvalidAccess(f));
		Reflect.setProperty(o,f,v);
		return v;
  }
  
  override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic 
  {
		return call(o, Reflect.getProperty(o, f), args);
  }
  
}

#end