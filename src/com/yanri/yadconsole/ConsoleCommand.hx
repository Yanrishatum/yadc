package com.yanri.yadconsole;

/**
 * The console command for Console
 * @author Yanrishatum
 */
class ConsoleCommand
{
  
  public var name:String;
  public var args:Array<CommandArgumentType>;
  public var descr:String;
  public var handler:Dynamic;
  public var thisObj:Dynamic;
  
  public function new(name:String, ?args:Array<CommandArgumentType>, ?descr:String, handler:Dynamic, thisObj:Dynamic) 
  {
    this.name = name.toLowerCase();
    this.args = args;
    this.descr = descr;
    this.handler = handler;
    this.thisObj = thisObj;
    if (!Reflect.isFunction(handler)) throw "You can't define command with non-function handler!";
  }
  
  public function call(args:Array<String>):Dynamic
  {
    if (this.args == null || args.length == 0) return Reflect.callMethod(thisObj, handler, []);
    else
    {
      var callArgs:Array<Dynamic> = new Array();
      var min:Int = Std.int(Math.min(args.length, this.args.length));
      for (i in 0...min)
      {
        var cl:CommandArgumentType = this.args[i];
        var val:String = args[i];
        switch (cl)
        {
          case CommandArgumentType.TString: callArgs.push(val);
          case CommandArgumentType.TInt: callArgs.push(Std.parseInt(val));
          case CommandArgumentType.TFloat: callArgs.push(Std.parseFloat(val));
          case CommandArgumentType.TBool: callArgs.push(val.toLowerCase() == "true" || val == "1");
        }
      }
      return Reflect.callMethod(thisObj, handler, callArgs);
    }
  }
  
}