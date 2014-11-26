package com.yanri.yadconsole;
import com.yanri.yadconsole.Initializer.ScanEntry;
import com.yanri.yadconsole.visuals.AutocompleteType;
import haxe.io.Bytes;
import haxe.Json;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type.BaseType;
import haxe.macro.Type;
import haxe.Resource;
import haxe.Serializer;

/**
 * ...
 * @author Yanrishatum
 */
class Initializer
{
  
  public static macro function init():Void
  {
    scan = new ScanEntry(AutocompleteType.TPackage, "", "");
    Context.onGenerate(scanTypes);
  }
  
  #if macro
  
  private static var scan:ScanEntry;
  
  private static function scanTypes(types:Array<Type>):Void
  {
    for (type in types)
    {
      var b:BaseType, name:String;
      var root:ScanEntry;
      switch (type)
      {
        case Type.TInst(c, _): // Class
          var t:ClassType = c.get();
          if (t.isInterface) continue;
          name = t.name;
          root = entry(t.isInterface ? AutocompleteType.TInterface : AutocompleteType.TClass, name, name, getRoot(t.pack), t.doc);
          root.path = c.toString();
          for (field in t.fields.get())
          {
            switch(field.type)
            {
              case Type.TFun(args, ret):
                entry(field.isPublic ? AutocompleteType.TMethod : AutocompleteType.TPrivateMethod, field.name, field.name + typeToStr(field.type), root, field.doc);
              default:
                entry(field.isPublic ? AutocompleteType.TVariable : AutocompleteType.TPrivateVariable, field.name, field.name + ":" + typeToStr(field.type), root, field.doc);
            }
          }
          
          for (field in t.statics.get())
          {
            switch(field.type)
            {
              case Type.TFun(args, ret):
                entry(field.isPublic ? AutocompleteType.TStaticMehtod : AutocompleteType.TPrivateStaticMethod, field.name, field.name + typeToStr(field.type), root, field.doc);
              default:
                entry(field.isPublic ? AutocompleteType.TStaticVariable : AutocompleteType.TPrivateStaticVariable, field.name, field.name + ":" + typeToStr(field.type), root, field.doc);
            }
          }
          
          b = c.get();
        case Type.TEnum(e, _):
          var t:EnumType = e.get();
          name = t.name;
          root = entry(AutocompleteType.TEnum, name, name, getRoot(t.pack), t.doc);
          root.path = e.toString();
          for (constr in t.constructs)
          {
            switch(constr.type)
            {
              case Type.TFun(args, _):
                // YADC: TEnumFunc icon
                entry(AutocompleteType.TEnum, constr.name, constr.name + "(" + functionArgsToStr(args), root, constr.doc) + ")";
              default:
                entry(AutocompleteType.TEnum, constr.name, constr.name, root, constr.doc);
            }
          }
          b = e.get();
        default: continue;
      }
      //var p:String = b.pack.join(".") + "." + name;
      //trace(p);
    }
    Context.addResource("__YADC_SCAN__", Bytes.ofString(Serializer.run(scan)));
  }
  
  private static function functionArgsToStr(args:Array<{ name : String, opt : Bool, t : Type }>, sep:String = ", "):String
  {
    var arr:Array<String> = new Array();
    for (arg in args)
    {
      var str:String = (arg.opt ? "?" : "") + arg.name + ":";
      switch(arg.t)
      {
        case Type.TFun(args, t):
          if (sep == " -> ")
            str += "(" + functionArgsToStr(args, " -> ") + " -> " + typeToStr(t) + ")";
          else
            str += functionArgsToStr(args, " -> ") + " -> " + typeToStr(t);
        default: str += typeToStr(arg.t);
      }
      arr.push(str);
    }
    return arr.join(sep);
  }
  
  private static function typeToStr(t:Type):String
  {
    switch (t)
    {
      case Type.TAbstract(a, _):
        return a.get().name;
      case Type.TAnonymous(a):
        return "Anonymous";
      case Type.TDynamic(a):
        return "Dynamic" + (a == null ? "" : "<" + typeToStr(a) + ">");
      case Type.TEnum(a, _):
        return a.get().name;
      case Type.TFun(args, ret):
        return "(" + functionArgsToStr(args) + "):" + typeToStr(ret);
      case Type.TInst(t, _):
        return t.get().name;
      case Type.TMono(r):
        var m:Type = r.get();
        if (m != null) return typeToStr(m);
        else return "TMono(Null)";
      case Type.TLazy(f):
        return "TLazy(Void->Type)";
      case Type.TType(r, _):
        return r.get().name;
    }
    return "";
  }
  
  private static function entry(type:AutocompleteType, realName:String , name:String, root:ScanEntry, doc:Null<String> = null):ScanEntry
  {
    var e:ScanEntry = new ScanEntry(type, realName, name);
    if (doc != null) e.descr = doc;
    root.childs.set(realName, e);
    return e;
  }
  
  private static function getRoot(packs:Array<String>):ScanEntry
  {
    var root:ScanEntry = scan;
    for (pack in packs)
    {
      if (root.childs.exists(pack)) root = root.childs.get(pack);
      else
      {
        root = entry(AutocompleteType.TPackage, pack, pack, root);
      }
    }
    return root;
  }
  
  #end
  
}

class ScanEntry
{
  public var type:AutocompleteType;
  public var realName:String;
  public var name:String;
  public var descr:String;
  public var childs:Map<String, ScanEntry>;
  public var path:String;
  public var parent:ScanEntry;
  
  public function new(type:AutocompleteType, realName:String, name:String)
  {
    this.type = type;
    this.name = name;
    this.realName = realName;
    this.childs = new Map();
  }
  
  public function child(name:String):ScanEntry
  {
    if (childs.exists(name)) return childs.get(name);
    else if (parent != null) return parent.child(name);
    return null;
  }
  
  private inline function childCount():Int
  {
    var i:Int = 0;
    for (k in childs) i++;
    return i;
  }
  
  public function toString():String
  {
    return "[" + type.getName() + " " + name + "; Childs count: " + childCount() + "]";
  }
  
}