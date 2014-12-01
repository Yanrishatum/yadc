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
    #if yadc_scan
    scan = new ScanEntry(AutocompleteType.TPackage, "", "");
    Context.onGenerate(scanTypes);
    #end
  }
  
  #if macro
  
  private static var scan:ScanEntry;
  
  private static function scanTypes(types:Array<Type>):Void
  {
    for (type in types)
    {
      var name:String;
      var root:ScanEntry;
      switch (type)
      {
        case Type.TInst(c, params): // Class
          var t:ClassType = c.get();
          if (t.isInterface || StringTools.startsWith(t.name, "__ASSET_")) continue; // Don't include info about assets.
          name = t.name + paramsToStr(params);
          root = entry(AutocompleteType.TClass, t.name, name, getRoot(t.pack), t.doc);
          root.path = c.toString();
          for (field in t.fields.get())
          {
            switch(field.kind)
            {
              case FieldKind.FVar(read, write):
                if (read.match(VarAccess.AccNormal) && write.match(VarAccess.AccNormal)) // Typical variable
                {
                  entry(field.isPublic ? AutocompleteType.TVariable : AutocompleteType.TPrivateVariable, field.name, field.name + ":" + typeToStr(field.type), root, field.doc);
                }
                else // Property
                {
                  var name:String = field.name + ":" + typeToStr(field.type);
                  if (!read.match(VarAccess.AccNever))
                  {
                    if (write.match(VarAccess.AccNever)) name += " (read only)";
                  }
                  else if (write.match(VarAccess.AccNever)) name += " (no access)"; // Ha.
                  else name += " (write only)";
                  entry(field.isPublic ? AutocompleteType.TProperty : AutocompleteType.TPrivateProperty, field.name, name, root, field.doc);
                }
              case FieldKind.FMethod(kind):
                switch(field.type)
                {
                  case Type.TFun(args, ret):
                    entry(field.isPublic ? AutocompleteType.TMethod : AutocompleteType.TPrivateMethod, field.name, field.name + typeToStr(field.type) + (kind.match(MethodKind.MethDynamic) ? " (dynamic)" : "" ), root, field.doc);
                  default:
                }
            }
          }
          
          for (field in t.statics.get())
          {
            switch(field.kind)
            {
              case FieldKind.FVar(read, write):
                if (read.match(VarAccess.AccNormal) && write.match(VarAccess.AccNormal)) // Typical variable
                {
                  entry(field.isPublic ? AutocompleteType.TStaticVariable : AutocompleteType.TPrivateStaticVariable, field.name, field.name + ":" + typeToStr(field.type), root, field.doc);
                }
                else // Property
                {
                  var name:String = field.name + ":" + typeToStr(field.type);
                  if (!read.match(VarAccess.AccNever))
                  {
                    if (!write.match(VarAccess.AccNever)) name += " (read only)";
                  }
                  else if (write.match(VarAccess.AccNever)) name += " (no access)"; // Ha.
                  else name += " (write only)";
                  entry(field.isPublic ? AutocompleteType.TStaticProperty : AutocompleteType.TPrivateStaticProperty, field.name, name, root, field.doc);
                }
              case FieldKind.FMethod(kind):
                switch(field.type)
                {
                  case Type.TFun(args, ret):
                    entry(field.isPublic ? AutocompleteType.TStaticMehtod : AutocompleteType.TPrivateStaticMethod, field.name, field.name + typeToStr(field.type) + (kind.match(MethodKind.MethDynamic) ? " (dynamic)" : "" ), root, field.doc);
                  default:
                }
            }
          }
        case Type.TEnum(e, params):
          var t:EnumType = e.get();
          name = t.name + paramsToStr(params);
          root = entry(AutocompleteType.TEnum, t.name, name, getRoot(t.pack), t.doc);
          root.path = e.toString();
          for (constr in t.constructs)
          {
            switch(constr.type)
            {
              case Type.TFun(args, _):
                entry(AutocompleteType.TEnumMethod, constr.name, constr.name + "(" + functionArgsToStr(args) + ")", root, constr.doc);
              default:
                entry(AutocompleteType.TEnumValue, constr.name, constr.name, root, constr.doc);
            }
          }
        default: continue;
      }
    }
    Context.addResource("__YADC_SCAN__", Bytes.ofString(Serializer.run(scan)));
  }
  
  private static function paramsToStr(params:Array<Type>):String
  {
    if (params.length == 0) return "";
    else
    {
      var buf:StringBuf = new StringBuf();
      buf.addChar("<".code);
      buf.add(typeToStr(params[0]));
      for (i in 1...params.length)
      {
        buf.add(", ");
        buf.add(typeToStr(params[i]));
      }
      buf.addChar(">".code);
      return buf.toString();
    }
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
      case Type.TAbstract(a, params):
        return a.get().name + paramsToStr(params);
      case Type.TAnonymous(a):
        return "Anonymous"; // YADC: Anynomous types stringification
      case Type.TDynamic(a):
        return "Dynamic" + (a == null ? "" : "<" + typeToStr(a) + ">");
      case Type.TEnum(a, params):
        return a.get().name + paramsToStr(params);
      case Type.TFun(args, ret):
        return "(" + functionArgsToStr(args) + "):" + typeToStr(ret);
      case Type.TInst(t, params):
        return t.get().name + paramsToStr(params);
      case Type.TMono(r):
        var m:Type = r.get();
        if (m != null) return typeToStr(m);
        else return "TMono(Null)";
      case Type.TLazy(f):
        return "TLazy(Void->Type)";
      case Type.TType(r, params):
        return r.get().name + paramsToStr(params) + ":" + typeToStr(r.get().type);
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
    var path:String = null;
    for (pack in packs)
    {
      if (path == null) path = pack;
      else path += "." + pack;
      if (root.childs.exists(pack)) root = root.childs.get(pack);
      else
      {
        root = entry(AutocompleteType.TPackage, pack, pack, root);
        root.path = path;
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