package com.yanri.yadconsole.visuals;
import com.yanri.yadconsole.ConsoleCommand;
import com.yanri.yadconsole.Initializer.ScanEntry;
import com.yanri.yadconsole.visuals.AutocompleteHelper.AutocompleteColumn;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import Type.ValueType;

/**
 * ...
 * @author Yanrishatum
 */
class AutocompleteHelper extends Sprite
{

  public var variables:Map<String, Dynamic>;
  public var commands:Array<ConsoleCommand>;
  public var scan:ScanEntry;
  private var acScan:Map<String, AutocompleteColumn>;
  private var acVars:Map<String, AutocompleteColumn>;
  private var acComs:Map<ConsoleCommand, AutocompleteColumn>;
  private var classes:Array<ScanEntry>;
  
  public function new(scanResults:ScanEntry, commands:Array<ConsoleCommand>) 
  {
    this.commands = commands;
    this.scan = scanResults;
    this.classes = new Array();
    acScan = new Map();
    acVars = new Map();
    acComs = new Map();
    if (scan != null) classScan(scan);
    for (cl in classes)
    {
      if (cl.parent == null)
      {
        var res:Class<Dynamic> = Type.resolveClass(cl.path);
        var superclass:Class<Dynamic> = Type.getSuperClass(res);
        if (superclass != null)
        {
          for (subCl in classes)
          {
            var subRes:Class<Dynamic> = Type.resolveClass(subCl.path);
            if (subRes == superclass)
            {
              cl.parent = subCl;
              break;
            }
          }
        }
      }
    }
    
    super();
  }
  
  private function classScan(root:ScanEntry):Void
  {
    for (child in root.childs)
    {
      if (child.type == AutocompleteType.TClass || child.type == AutocompleteType.TEnum)
      {
        classes.push(child);
      }
      else if (child.type == AutocompleteType.TPackage) classScan(child);
    }
  }
  
  public function getFirst():String
  {
    if (numChildren != 0) return cast(getChildAt(0), AutocompleteColumn).realName;
    return null;
  }
  
  public var incomplete:String;
  
  public function update(text:String, checkCommands:Bool, checkScanVars:Bool):Void
  {
    while (numChildren > 0) this.removeChildAt(0);
    this.graphics.clear();
    incomplete = "";
    var possible:Array<AutocompleteColumn> = new Array();
    if (text == "")
    {
      if (checkCommands)
      {
        for (comm in commands)
        {
          possible.push(getCommandColumn(comm));
        }
        checkCommands = false;
      }
      if (checkScanVars)
      {
        var ignore:Array<String> = new Array();
        if (scan != null)
        {
          for (val in scan.childs)
          {
            if (StringTools.startsWith(val.name, "__ASSET_")) continue; // Ignore assets
            ignore.push(val.name);
            possible.push(getScanColumn(val));
          }
        }
        
        if (variables != null)
        {
          for (key in variables.keys())
          {
            if (ignore.indexOf(key) != -1) continue; // Ignore scanned
            possible.push(getVarColumn(variables.get(key), key, key, null));
          }
        }
        
        checkScanVars = false;
      }
    }
    
    if (checkCommands)
    {
      for (command in commands)
      {
        if (StringTools.startsWith(text, command.name))
        {
          possible.push(getCommandColumn(command));
        }
      }
    }
    if (checkScanVars)
    {
      var r:EReg = ~/[ ()\[\];]/g;
      var full:String = r.split(text).pop();
      var split:Array<String> = full.split(".");
      var last:String = incomplete = split.pop();
      
      var ignore:Array<String> = new Array();
      
      if (scan != null)
      {
        var stack:Dynamic = null;
        var scan:ScanEntry = this.scan;
        for (val in split)
        {
          if (scan.childs.exists(val))
          {
            scan = scan.childs.get(val);
          }
          else
          {
            scan = null;
            break;
          }
        }
        if (scan != null)
        { 
          for (child in scan.childs)
          {
            ignore.push(child.realName);
            if (StringTools.startsWith(child.realName, "__ASSET_")) continue;
            if (isStatic(child.type) && StringTools.startsWith(child.name, last))
            {
              possible.push(getScanColumn(child));
            }
          }
        }
      }
      
      if (variables != null)
      {
        if (split.length == 0)
        {
          for (key in variables.keys())
          {
            if (StringTools.startsWith(key, last) && ignore.indexOf(key) == -1)
            {
              possible.push(getVarColumn(variables.get(key), key, key, null));
            }
          }
        }
        else
        {
          var name:String = split.join(".") + ".";
          var stack:Dynamic = null;
          for (val in split)
          {
            if (stack == null)
            {
              if (variables.exists(val)) stack = variables.get(val);
              else break;
            }
            else
            {
              if (Reflect.hasField(stack, val)) stack = Reflect.field(stack, val);
              else
              {
                stack = null;
                break;
              }
            }
          }
          if (stack != null)
          {
            var fields:Array<String> = getVarFields(stack);
            var existingProps:Array<String> = new Array();
            for (field in fields)
            {
              var propKey:String = 
              if (StringTools.startsWith(field, "get_") || StringTools.startsWith(field, "set_")) field.substr(4);
              else field;
              if (propKey != field && existingProps.indexOf(propKey) == -1 && StringTools.startsWith(propKey, last) && ignore.indexOf(propKey) == -1)
              {
                existingProps.push(propKey);
                possible.push(getVarColumn(Reflect.getProperty(stack, propKey), name + propKey, propKey, stack));
              }
              if ((propKey == field || last != "") && StringTools.startsWith(field, last) && ignore.indexOf(field) == -1)
              {
                possible.push(getVarColumn(Reflect.field(stack, field), name + field, field, stack));
              }
            }
          }
        }
      }
    }
    
    possible.sort(sortColumns);
    
    for (col in possible)
    {
      col.y = numChildren * 16;
      addChild(col);
    }
    
    this.graphics.beginFill(0x808080, 0.75);
    this.graphics.drawRect(0, 0, this.width, this.height);
    this.graphics.endFill();
  }
  
  private function sortColumns(a:AutocompleteColumn, b:AutocompleteColumn):Int
  {
    var la:String = a.name.toLowerCase();
    var lb:String = b.name.toLowerCase();
    if (a.type == b.type) return nameSort(la, lb);
    else
    {
      if (a.type == AutocompleteType.TPackage) return -1;
      else if (b.type == AutocompleteType.TPackage) return 1;
      else return nameSort(la, lb);
    }
  }
  
  private inline function nameSort(a:String, b:String):Int
  {
    if (a > b) return 1;
    else if (a < b) return -1;
    else return 0;
  }
  
  private function isStatic(t:AutocompleteType):Bool
  {
    return t == AutocompleteType.TStaticProperty || t == AutocompleteType.TClass || 
           t == AutocompleteType.TEnum || t == AutocompleteType.TPackage || 
           t == AutocompleteType.TStaticMehtod || t == AutocompleteType.TStaticVariable ||
           t == AutocompleteType.TPrivateStaticMethod || t == AutocompleteType.TPrivateStaticProperty ||
           t == AutocompleteType.TPrivateStaticVariable;
  }
  
  private function getVarFields(val:Dynamic):Array<String>
  {
    switch (Type.typeof(val))
    {
      case ValueType.TBool, ValueType.TFloat, ValueType.TFunction, ValueType.TEnum(_), ValueType.TInt, ValueType.TNull, ValueType.TUnknown: return []; // Types don't have any fields
      case ValueType.TObject:
        #if flash // on flash target Enums is classes
        if (Std.is(val, Class)) return Type.getClassFields(val);
        #else
        if (Std.is(val, Enum)) return Type.getEnumConstructs(val);
        else if (Std.is(val, Class)) return Type.getClassFields(val);
        #end
        return Reflect.fields(val);
      case ValueType.TClass(cl):
        return Type.getInstanceFields(cl);
    }
  }
  
  private function getVarColumn(val:Dynamic, path:String, name:String, parent:Dynamic):AutocompleteColumn
  {
    if (acVars.exists(path)) return acVars.get(path);
    var c:AutocompleteColumn = null;
    var t:ValueType = Type.typeof(val);
    var parentScan:ScanEntry = getScanFromVal(parent);
    var childScan:ScanEntry = null;
    if (parentScan != null && (childScan = parentScan.child(name)) != null) return getScanColumn(childScan);
    switch(t)
    {
      case ValueType.TFunction:
        c = new AutocompleteColumn(AutocompleteType.TMethod, name, null, null);
        c.typeof = t;
        acVars.set(path, c);
      case ValueType.TClass(cl):
        c = getVarClassColumn(Type.getClassName(cl), name);
      case ValueType.TEnum(e):
        c = getVarEnumColumn(Type.getEnumName(e), name);
      default:
        #if flash
        if (Std.is(val, Class)) c = getVarClassColumn(Type.getClassName(val), name);
        #else
        if (Std.is(val, Enum)) c = getVarEnumColumn(Type.getEnumName(val), name);
        else if (Std.is(val, Class)) c = getVarClassColumn(Type.getClassName(val), name);
        #end
        else
        {
          c = new AutocompleteColumn(AutocompleteType.TVariable, name, null, null);
          c.typeof = t;
          acVars.set(path, c);
        }
    }
    return c;
  }
  
  private function getScanFromVal(val:Dynamic):ScanEntry
  {
    if (val != null)
    {
      switch (Type.typeof(val))
      {
        case ValueType.TClass(cl):
          var name:String = Type.getClassName(cl);
          for (sc in classes)
          {
            if (sc.path == name) return sc;
          }
        case ValueType.TEnum(e):
          var name:String = Type.getEnumName(e);
          for (sc in classes)
          {
            if (sc.path == name) return sc;
          }
        case ValueType.TObject:
          #if flash
          var name:String =
          if (Std.is(val, Class)) Type.getClassName(val);
          else null;
          #else
          var name:String = 
          if (Std.is(val, Class)) Type.getClassName(val);
          else if (Std.is(val, Enum)) Type.getEnumName(val);
          else null;
          #end
          if (name != null)
          {
            for (sc in classes)
            {
              if (sc.path == name) return sc;
            }
          }
        default :
      }
    }
    return null;
  }
  
  private function getVarEnumColumn(path:String, name:String):AutocompleteColumn
  {
    var acVarsName:String = path + ":" + name;
    if (acVars.exists(acVarsName)) return acVars.get(acVarsName);
    for (scan in classes)
    {
      if (scan.path == path) return getScanColumn(scan, name);
    }
    var c:AutocompleteColumn = new AutocompleteColumn(AutocompleteType.TEnum, name, null, null);
    acVars.set(acVarsName, c);
    return c;
  }
  
  private function getVarClassColumn(path:String, name:String):AutocompleteColumn
  {
    var acVarsName:String = path + ":" + name;
    if (acVars.exists(acVarsName)) return acVars.get(acVarsName);
    for (scan in classes)
    {
      if (scan.path == path) return getScanColumn(scan, name);
    }
    var c:AutocompleteColumn = new AutocompleteColumn(AutocompleteType.TClass, name, null, null);
    acVars.set(acVarsName, c);
    return c;
  }
  
  private function getScanColumn(val:ScanEntry, customName:String = null):AutocompleteColumn
  {
    var name:String = val.path == null ? val.name : val.path;
    if (customName != null) name += ":" + customName;
    if (acScan.exists(name)) return acScan.get(name);
    
    if (customName != null)
    {
      switch(val.type)
      {
        case AutocompleteType.TClass, AutocompleteType.TEnum:
          customName += ":" + val.name;
        case AutocompleteType.TPrivateVariable, AutocompleteType.TPrivateStaticVariable, AutocompleteType.TVariable, AutocompleteType.TStaticVariable,
             AutocompleteType.TPrivateProperty, AutocompleteType.TPrivateStaticProperty, AutocompleteType.TProperty, AutocompleteType.TStaticProperty:
          customName += val.name.substr(val.name.indexOf(":"));
        case AutocompleteType.TPrivateMethod, AutocompleteType.TPrivateStaticMethod, AutocompleteType.TMethod, AutocompleteType.TStaticMehtod, AutocompleteType.TEnumMethod:
          customName += val.name.substr(val.name.indexOf("("));
        default:
      }
    }
    else customName = val.name;
    
    var col:AutocompleteColumn = new AutocompleteColumn(val.type, customName, val.descr, val);
    acScan.set(name, col);
    return col;
  }
  
  private function getCommandColumn(comm:ConsoleCommand):AutocompleteColumn
  {
    if (acComs.exists(comm)) return acComs.get(comm);
    var name:String = comm.name;
    for (type in comm.args)
    {
      switch(type)
      {
        case CommandArgumentType.TBool: name += " [Boolean]";
        case CommandArgumentType.TFloat: name += " [Float]";
        case CommandArgumentType.TInt: name += " [Int]";
        case CommandArgumentType.TString: name += " [String]";
      }
    }
    var c:AutocompleteColumn = new AutocompleteColumn(AutocompleteType.TStaticMehtod, name, comm.descr, null);
    acComs.set(comm, c);
    return c;
  }
  
}

class AutocompleteColumn extends Sprite
{
  
  private static var FORMAT:TextFormat;
  
  //public var name:String;
  public var descr:String;
  public var scan:ScanEntry;
  public var type:AutocompleteType;
  public var typeof:ValueType;
  
  public function new(type:AutocompleteType, name:String, descr:String = null, scanInfo:ScanEntry)
  {
    super(); // TODO: Function advanced description
    this.scan = scanInfo;
    this.name = name;
    this.descr = descr;
    this.type = type;
    var ico:BitmapData = 
    switch (type)
    {
      case AutocompleteType.TClass: Assets.getBitmapData("YADConsoleResources/Class.png");
      case AutocompleteType.TInterface: Assets.getBitmapData("YADConsoleResources/Interface.png");
      case AutocompleteType.TPackage: Assets.getBitmapData("YADConsoleResources/Package.png");
      
      case AutocompleteType.TEnum: Assets.getBitmapData("YADConsoleResources/Enum.png");
      case AutocompleteType.TEnumMethod: Assets.getBitmapData("YADConsoleResources/EnumMethod.png");
      case AutocompleteType.TEnumValue: Assets.getBitmapData("YADConsoleResources/EnumValue.png");
      
      case AutocompleteType.TStaticMehtod: Assets.getBitmapData("YADConsoleResources/MethodStatic.png");
      case AutocompleteType.TStaticProperty: Assets.getBitmapData("YADConsoleResources/PropertyStatic.png");
      case AutocompleteType.TStaticVariable: Assets.getBitmapData("YADConsoleResources/VariableStatic.png");
      
      case AutocompleteType.TPrivateMethod: Assets.getBitmapData("YADConsoleResources/MethodPrivate.png");
      case AutocompleteType.TPrivateProperty: Assets.getBitmapData("YADConsoleResources/PropertyPrivate.png");
      case AutocompleteType.TPrivateVariable: Assets.getBitmapData("YADConsoleResources/VariablePrivate.png");
      
      case AutocompleteType.TPrivateStaticMethod: Assets.getBitmapData("YADConsoleResources/MethodStaticPrivate.png");
      case AutocompleteType.TPrivateStaticProperty: Assets.getBitmapData("YADConsoleResources/PropertyStaticPrivate.png");
      case AutocompleteType.TPrivateStaticVariable: Assets.getBitmapData("YADConsoleResources/VariableStaticPrivate.png");
      
      case AutocompleteType.TMethod: Assets.getBitmapData("YADConsoleResources/Method.png");
      case AutocompleteType.TVariable: Assets.getBitmapData("YADConsoleResources/Variable.png");
      case AutocompleteType.TProperty: Assets.getBitmapData("YADConsoleResources/Property.png");
      
      default: null;
    }
    var offset:Float = 0;
    if (ico != null)
    {
      var btm:Bitmap = new Bitmap(ico);
      #if !flash
      btm.mouseEnabled = false;
      btm.mouseChildren = false;
      #end
      this.addChild(btm);
      offset = ico.width;
    }
    if (FORMAT == null)
    {
      FORMAT = new TextFormat("Courier New", 12, 0xFFFFFF);
    }
    
    var field:TextField = new TextField();
    field.defaultTextFormat = FORMAT;
    field.selectable = false;
    field.mouseEnabled = false;
    field.text = name;
    field.height = field.textHeight;
    field.autoSize = TextFieldAutoSize.LEFT;
    field.x = offset;
    this.addChild(field);
  }
  
  public var realName(get, never):String;
  private inline function get_realName():String
  {
    if (scan != null) return scan.realName;
    else return name;
  }
  
}