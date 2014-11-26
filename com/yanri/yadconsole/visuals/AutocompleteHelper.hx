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
  private var acScan:Map<ScanEntry, AutocompleteColumn>;
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
            for (field in fields)
            {
              if (StringTools.startsWith(field, last) && ignore.indexOf(field) == -1)
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
      case ValueType.TBool, ValueType.TFloat, ValueType.TFunction, ValueType.TEnum(_), ValueType.TInt, ValueType.TNull, ValueType.TUnknown: return [];
      case ValueType.TObject: return Reflect.fields(val);
      default: //TClass
        if (Std.is(val, Class)) return Type.getClassFields(val);
        else return Type.getInstanceFields(Type.getClass(val));
    }
  }
  
  private function getVarColumn(val:Dynamic, path:String, name:String, parent:Dynamic):AutocompleteColumn
  {
    if (acVars.exists(path)) return acVars.get(path);
    var c:AutocompleteColumn = null;
    var t:ValueType = Type.typeof(val);
    var parentScan:ScanEntry = getScanFromVal(parent);
    var childScan:ScanEntry = null;
    switch(t)
    {
      case ValueType.TFunction:
        if (parentScan != null && (childScan = parentScan.child(name)) != null) c = getScanColumn(childScan);
        else
        {
          c = new AutocompleteColumn(AutocompleteType.TMethod, name, null, null);
          c.typeof = t;
          acVars.set(path, c);
        }
      case ValueType.TClass(cl):
        c = getVarClassColumn(cl, Type.getClassName(cl), name);
      case ValueType.TEnum(e):
        c = new AutocompleteColumn(AutocompleteType.TEnum, name, null, null);
      default:
        if (parentScan != null && (childScan = parentScan.child(name)) != null) c = getScanColumn(childScan);
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
        default :
      }
    }
    return null;
  }
  
  private function getVarClassColumn(cl:Class<Dynamic>, path:String, name:String):AutocompleteColumn
  {
    for (scan in classes)
    {
      if (scan.type == AutocompleteType.TClass && scan.path == path) return getScanColumn(scan);
    }
    var c:AutocompleteColumn = new AutocompleteColumn(AutocompleteType.TClass, name, null, null);
    acVars.set(path, c);
    return c;
  }
  
  private function getVarEnumColumn(e:Enum<Dynamic>, path:String, name:String):AutocompleteColumn
  {
    for (scan in classes)
    {
      if (scan.type == AutocompleteType.TEnum && scan.path == path) return getScanColumn(scan);
    }
    var c:AutocompleteColumn = new AutocompleteColumn(AutocompleteType.TEnum, name, null, null);
    acVars.set(path, c);
    return c;
  }
  
  private function getScanColumn(val:ScanEntry):AutocompleteColumn
  {
    if (acScan.exists(val)) return acScan.get(val);
    var col:AutocompleteColumn = new AutocompleteColumn(val.type, val.name, val.descr, val);
    acScan.set(val, col);
    return col;
  }
  
  private function getCommandColumn(comm:ConsoleCommand):AutocompleteColumn
  {
    if (acComs.exists(comm)) return acComs.get(comm);
    var c:AutocompleteColumn = new AutocompleteColumn(AutocompleteType.TStaticMehtod, comm.name, comm.descr, null);
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
    var ico:BitmapData = null;
    switch (type)
    {
      case AutocompleteType.TClass: ico = Assets.getBitmapData("YADConsoleResources/Class.png");
      case AutocompleteType.TEnum: ico = Assets.getBitmapData("YADConsoleResources/Const.png");
      case AutocompleteType.TInterface: ico = Assets.getBitmapData("YADConsoleResources/Interface.png");
      case AutocompleteType.TPackage: ico = Assets.getBitmapData("YADConsoleResources/Package.png");
      
      case AutocompleteType.TStaticMehtod: ico = Assets.getBitmapData("YADConsoleResources/MethodStatic.png");
      case AutocompleteType.TStaticProperty: ico = Assets.getBitmapData("YADConsoleResources/PropertyStatic.png");
      case AutocompleteType.TStaticVariable: ico = Assets.getBitmapData("YADConsoleResources/VariableStatic.png");
      
      case AutocompleteType.TPrivateMethod: ico = Assets.getBitmapData("YADConsoleResources/MethodPrivate.png");
      case AutocompleteType.TPrivateProperty: ico = Assets.getBitmapData("YADConsoleResources/PropertyPrivate.png");
      case AutocompleteType.TPrivateVariable: ico = Assets.getBitmapData("YADConsoleResources/VariablePrivate.png");
      
      case AutocompleteType.TPrivateStaticMethod: ico = Assets.getBitmapData("YADConsoleResources/MethodStaticPrivate.png");
      case AutocompleteType.TPrivateStaticProperty: ico = Assets.getBitmapData("YADConsoleResources/PropertyStaticPrivate.png");
      case AutocompleteType.TPrivateStaticVariable: ico = Assets.getBitmapData("YADConsoleResources/VariableStaticPrivate.png");
      
      case AutocompleteType.TMethod: ico = Assets.getBitmapData("YADConsoleResources/Method.png");
      case AutocompleteType.TVariable: ico = Assets.getBitmapData("YADConsoleResources/Variable.png");
      case AutocompleteType.TProperty: ico = Assets.getBitmapData("YADConsoleResources/Property.png");
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