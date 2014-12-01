/**
  This work is licensed under MIT License.
  
  Copyright (c) 2014 Pavel Alexandrov / Yanrishatum
  
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
 */
package com.yanri.yadconsole;
import com.yanri.yadconsole.Initializer.ScanEntry;
import com.yanri.yadconsole.visuals.AutocompleteHelper;
import com.yanri.yadconsole.visuals.AutocompleteType;
import haxe.Log;
import haxe.PosInfos;
import haxe.Resource;
import haxe.Unserializer;
import openfl.display.InteractiveObject;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.TextEvent;
import openfl.Lib;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;

#if hscript
import hscript.Parser;
import hscript.Expr;
#end

/**
 * ...
 * @author Yanrishatum
 */
class Console extends Sprite
{
  // YADC: Make UI separate from core
  // YADC: UI: More configurable.
  // YADC: Better commands mode.
  // YADC: Multiline script mode.
  // YADC: Configurable keys.
  // YADC: Help command
  // YADC: Show documentation
  // YADC: Properties support (requires modding of HScript, because it's uses setField instead of setProperty)
  // YADC: Normal ConsoleCommand description for autocomplete.
  // YADC: Anonymous types variable type descriptions for helper.
  // YADC: <T> support. (Array<T>, etc, partially done)
  // YADC: Constructor info
  
  private static inline var VERSION:String = "0.0.5";
  
  /**
   * The consle instance
   */
  public static var c:Console;
  
  /**
   * Enables console.
   * By default, console is hidden.
   * @param mode Mode of the console. Default: Hybrid.
   * @param traceCapture Capture the trace calls and log them into console? Default: false
   * @return The Console instance.
   */
  public static function enable(?mode:ConsoleMode, traceCapture:Bool = false):Console
  {
    if (c != null)
    {
      if (mode != null) c.mode = mode;
      // YADC: Apply traceCapture
      return c; // Disable multi-instancing
    }
    if (mode == null) mode = ConsoleMode.Hybrid;
    c = new Console(mode, traceCapture);
    Lib.current.addChild(c);
    return c;
  }
  
  private var prevTarget:InteractiveObject;
  
  private var output:TextField;
  private var command:TextField;

  /**
   * Active mode of the console.
   */
  public var mode:ConsoleMode;
  
  private var defaultTrace:Dynamic->?PosInfos->Void;
  
  private var commandsList:Array<ConsoleCommand>;
  
  #if hscript
  
  private var interp:PropInterp;
  private var parser:Parser;
  
  #end
  
  private var commandSuccess:Bool = false;
  
  private var autocomplete:AutocompleteHelper;
  
  private var selectionToEnd:Bool;
  
  private var prevCommands:Array<String>;
  private var storedCommand:String;
  private var commandCaret:Int = -1;
  
  private function new(mode:ConsoleMode, traceCapture:Bool) 
  {
    this.mode = mode;
    
    super();
    
    if (traceCapture)
    {
      defaultTrace = Log.trace;
      Log.trace = consoleTrace;
    }
    
    var format:TextFormat = new TextFormat("Courier New", 12, 0xFFFFFF);
    
    output = new TextField();
    output.defaultTextFormat = format;
    output.multiline = true;
    output.wordWrap = true;
    output.text = "Yet Another Debug Console v " + VERSION;
    addChild(output);
    command = new TextField();
    command.defaultTextFormat = format;
    command.type = TextFieldType.INPUT;
    command.height = 20;
    command.restrict = "^`~";
    command.addEventListener(Event.CHANGE, onChange);
    addChild(command);
    addEventListener(Event.ADDED_TO_STAGE, onAdded);
    this.visible = false;
    
    var scan:ScanEntry = null;
    
    #if !hscript
    if (mode == ConsoleMode.Scripts)
    {
      mode = ConsoleMode.Commands;
      log("Using Scripts console mode not available without HScript library!");
    }
    else if (mode == ConsoleMode.Hybrid)
    {
      mode = ConsoleMode.Commands;
    }
    #else
    
    interp = new PropInterp();
    parser = new Parser();
    
    interp.variables.set("clear", clear);
    interp.variables.set("mode", changeMode);
    
    #if yadc_scan
    scan = Unserializer.run(Resource.getString("__YADC_SCAN__"));
    for (pack in scan.childs)
    {
      if (StringTools.startsWith(pack.realName, "__ASSET_")) continue; // Ignore assets.
      if (pack.type == AutocompleteType.TPackage)
      {
        var val:Dynamic = { };
        addScanVars(val, pack, pack.name);
        interp.variables.set(pack.name, val);
      }
      else if (pack.type == AutocompleteType.TClass)
      {
        interp.variables.set(pack.name, Type.resolveClass(pack.name));
      }
      else if (pack.type == AutocompleteType.TEnum)
      {
        interp.variables.set(pack.name, Type.resolveEnum(pack.name));
      }
    }
    #end
    
    #end
    
    prevCommands = new Array();
    commandsList = new Array();
    commandsList.push(new ConsoleCommand("clear", null, "Clears console log", clear, this));
    commandsList.push(new ConsoleCommand("mode", [CommandArgumentType.TString], "Switches console mode possible modes: hybrid, commands, scripts", changeMode, this));
    
    autocomplete = new AutocompleteHelper(scan, commandsList);
    #if hscript
    autocomplete.variables = interp.variables;
    #end
    addChild(autocomplete);
    
  }
  
  private function onChange(e:Event):Void 
  {
    autocomplete.update(command.text, mode != ConsoleMode.Scripts, mode != ConsoleMode.Commands);
  }
  
  #if yadc_scan
  
  private function addScanVars(to:Dynamic, entry:ScanEntry, path:String):Void
  {
    var outStr:StringBuf = new StringBuf();
    outStr.add("Package: ");
    outStr.add(path);
    outStr.add("\nContents:");
    for (child in entry.childs)
    {
      outStr.addChar("\n".code);
      outStr.add(child.name);
      var newPath:String = path + "." + child.name;
      if (child.type == AutocompleteType.TPackage)
      {
        var pack:Dynamic = { };
        addScanVars(pack, child, newPath);
        Reflect.setField(to, child.name, pack);
        outStr.add(" (package)");
      }
      else
      {
        if (child.type == AutocompleteType.TClass)
        {
          Reflect.setField(to, child.name, Type.resolveClass(newPath));
          outStr.add(" (class)");
        }
        else if (child.type == AutocompleteType.TEnum)
        {
          Reflect.setField(to, child.name, Type.resolveEnum(newPath));
          outStr.add(" (enum)");
        }
      }
    }
    var str:String = outStr.toString();
    Reflect.setField(to, "toString", function():String { return str; } );
  }
  
  #end
  
  private function consoleTrace(v:Dynamic, ?infos:PosInfos):Void
  {
    if (infos == null)
    {
      if (v == null) log("null");
      else log(Std.string(v));
    }
    else
    {
      var buf:StringBuf = new StringBuf();
      buf.add(infos.fileName);
      buf.addChar(":".code);
      buf.add(infos.lineNumber);
      buf.add(": ");
      buf.add(v == null ? "null" : Std.string(v));
      if (infos.customParams != null) for (val in infos.customParams)
      {
        buf.addChar(",".code);
        buf.add(val == null ? "null" : Std.string(val));
      }
      log(buf.toString());
    }
    defaultTrace(v, infos);
  }
  
  private function onAdded(e:Event):Void
  {
    removeEventListener(Event.ADDED_TO_STAGE, onAdded);
    stage.addEventListener(Event.RESIZE, resize);
    stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
    stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
    resize(null);
  }
  
  private function onEnterFrame(e:Event):Void 
  {
    if (visible && stage.focus != command) stage.focus = command;
    if (selectionToEnd)
    {
      selectionToEnd = false;
      selectToEnd();
    }
  }
  
  private inline function selectToEnd():Void
  {
    command.setSelection(command.text.length, command.text.length);
  }
  
  private function onKeyDown(e:KeyboardEvent):Void 
  {
    switch(e.keyCode)
    {
      case Keyboard.UP:
        prevCommand();
      case Keyboard.DOWN:
        nextCommand();
    }
  }
  
  private function prevCommand():Void
  {
    if (commandCaret == prevCommands.length - 1) return;
    if (commandCaret == -1)
    {
      storedCommand = command.text;
    }
    commandCaret++;
    command.text = prevCommands[prevCommands.length - commandCaret - 1];
    selectionToEnd = true;
    selectToEnd();
  }
  
  private function nextCommand():Void
  {
    if (commandCaret == -1) return;
    commandCaret--;
    if (commandCaret == -1)
    {
      command.text = storedCommand;
    }
    else
    {
      command.text = prevCommands[prevCommands.length - commandCaret - 1];
    }
    selectionToEnd = true;
    selectToEnd();
  }
  
  private function onKeyUp(e:KeyboardEvent):Void 
  {
    if (!e.shiftKey && !e.ctrlKey && !e.altKey)
    {
      switch(e.keyCode)
      {
        case Keyboard.ENTER, Keyboard.NUMPAD_ENTER:
          send();
        case Keyboard.BACKQUOTE:
          visible = !visible;
          if (visible)
          {
            prevTarget = stage.focus;
          }
          else
          {
            stage.focus = prevTarget;
          }
        case Keyboard.TAB:
          applyAutocomplete();
      }
    }
  }
  
  private function applyAutocomplete():Void
  {
    var full:String = autocomplete.getFirst();
    if (full != null)
    {
      var text:String = command.text;
      if (autocomplete.incomplete.length != 0) text = text.substr(0, -autocomplete.incomplete.length);
      text += full;
      command.text = text;
      selectionToEnd = true;
    }
    autocomplete.update(command.text, mode != ConsoleMode.Scripts, mode != ConsoleMode.Commands);
  }
  
  private function resize(e:Event):Void
  {
    var w:Float = stage.stageWidth;
    var hh:Float = stage.stageHeight / 2;
    
    command.width = w;
    output.width = w;
    command.y = hh - command.height;
    output.height = hh - command.height;
    autocomplete.y = hh;
    redrawUI();
  }
  
  private function redrawUI():Void
  {
    var g:Graphics = this.graphics;
    g.clear();
    g.beginFill(0x808080, 0.75);
    g.drawRect(0, 0, this.width, stage.stageHeight / 2);
    g.endFill();
    g.lineStyle(0.1, 0xCCCCCC);
    g.moveTo(0, command.y);
    g.lineTo(width, command.y);
  }
  
  /**
   * Logs given text into console.
   * @param str
   */
  public function log(str:String):Void
  {
    output.appendText("\n" + str);
    output.scrollV = output.maxScrollV;
  }
  
  /**
   * Sends current command in the input text field.
   * @return Result of the execution
   */
  public function send():Dynamic
  {
    var val:String = StringTools.trim(command.text);
    if (val == "") return null;
    command.text = "";
    autocomplete.update("", false, false);
    // Move command to last
    prevCommands.remove(val);
    prevCommands.push(val);
    switch (mode)
    {
      case ConsoleMode.Commands:
        return runCommand(val);
      case ConsoleMode.Hybrid:
        log("> " + val);
        commandSuccess = false;
        var out:Dynamic = _runCommand(val, false);
        if (!commandSuccess) out = _runScript(val, true);
        if (out != null) log(Std.string(out));
        return out;
      case ConsoleMode.Scripts:
        return runScript(val);
    }
  }
  
  /**
   * Clears the console log.
   * This function also available from console as command/function
   */
  public function clear():Void
  {
    output.text = "Yet Another Debug Console v " + VERSION;
  }
  
  /**
   * Function for change mode via console.
   * @param mode
   * @return
   */
  private function changeMode(?mode:String):String
  {
    #if !hscript
    return "Mode switching not allowed without HScript library";
    #end
    if (mode == null) return "Possible modes: hybrid, commands, scripts";
    mode = mode.toLowerCase();
    switch(mode)
    {
      case "hybrid":
        this.mode = ConsoleMode.Hybrid;
        return "Switched console mode to Hybrid";
      case "commands":
        this.mode = ConsoleMode.Commands;
        return "Switched console mode to Commands";
      case "scripts":
        this.mode = ConsoleMode.Scripts;
        return "Switched console mode to Scripts";
    }
    return "Possible modes: hybrid, commands, scripts";
  }
  
  /**
   * Runs the given command and returns the result (also prints in console).
   * @param command 
   * @return
   */
  public function runCommand(command:String):Dynamic
  {
    log("> " + command);
    var val:Dynamic = _runCommand(command, true);
    if (val != null) log(Std.string(val));
    return null;
  }
  
  private function _runCommand(val:String, logError:Bool):Dynamic
  {
    var args:Array<String> = splitCommand(val, logError);
    if (args == null || args.length == 0) return null;
    val = args.shift().toLowerCase();
    
    for (command in commandsList)
    {
      if (command.name == val)
      {
        // TODO: Error handling
        commandSuccess = true;
        return command.call(args);
      }
    }
    if (logError)
    {
      log("Command with name \"" + val + "\" not found!");
    }
    return null;
  }
  
  private function splitCommand(input:String, logError:Bool):Array<String>
  {
    input = StringTools.trim(input);
    var out:Array<String> = new Array();
    var offset:Int = 0;
    var inQuotes:Bool = false;
    var inDoubleQuotes:Bool = false;
    var unescape:Bool = false;
    var char:Int;
    var awaitsSpace:Bool = false;
    for (i in 0...input.length)
    {
      char = StringTools.fastCodeAt(input, i);
      if (char == "\\".code && !unescape)
      {
        unescape = true;
        continue;
      }
      if (inQuotes)
      {
        if (char == "'".code && !unescape)
        {
          inQuotes = false;
          awaitsSpace = true;
          out.push(input.substring(offset + 1, i));
          offset = i + 2;
        }
        continue;
      }
      if (inDoubleQuotes)
      {
        if (char == '"'.code && !unescape)
        {
          inDoubleQuotes = false;
          awaitsSpace = true;
          out.push(input.substring(offset + 1, i));
          offset = i + 2;
        }
        continue;
      }
      if (char == " ".code)
      {
        if (awaitsSpace) awaitsSpace = false;
        else
        {
          out.push(input.substring(offset, i));
          offset = i + 1;
        }
      }
      else if (awaitsSpace)
      {
        if (logError) log("Command parsing error! Awaited \" \", got \"" + String.fromCharCode(char) + "\" @ " + i + ".");
        return null;
      }
      else if (char == "'".code && !unescape) inQuotes = true;
      else if (char == '"'.code && !unescape) inDoubleQuotes = true;
      unescape = false;
    }
    if (!awaitsSpace) out.push(input.substr(offset));
    return out;
  }
  
  /**
   * Runs the given script and returns the result (also prints in console).
   * Available only with HScript library.
   * @param script
   * @return
   */
  public function runScript(script:String):Dynamic
  {
    log("> " + script);
    var out:Dynamic = _runScript(script, true);
    if (out != null) log(Std.string(out));
    return out;
  }
  
  private function _runScript(script:String, logError:Bool):Dynamic
  {
    #if hscript
    try
    {
      var expr:Expr = parser.parseString(script);
      return interp.execute(expr);
    }
    catch (e:Dynamic)
    {
      if (logError)
      {
        log(Std.string(e));
      }
    }
    #end
    return null;
  }
  
  /**
   * Adds new command.
   * @param name Name of the command.
   * @param args List or arguments, that takes command.
   * @param descr Description of the command (will be used in later version)
   * @param handler Handler of the command. It must be functions
   * @param thisObj `this` object, that will be used for handler, while command execution.
   */
  public function addCommand(name:String, ?args:Array<CommandArgumentType>, ?descr:String, handler:Dynamic, thisObj:Dynamic):Void
  {
    commandsList.unshift(new ConsoleCommand(name, args, descr, handler, thisObj));
  }
  
  /**
   * Removes command with the given name.
   * @param name
   * @return
   */
  public function removeCommand(name:String):Bool
  {
    name = name.toLowerCase();
    for (comm in commandsList)
    {
      if (comm.name == name)
      {
        commandsList.remove(comm);
        return true;
      }
    }
    return false;
  }
  
  /**
   * Adds new variable for scripts.
   * @param name Variable name.
   * @param value Variable value.
   */
  public function addVariable(name:String, value:Dynamic):Void
  {
    #if hscript
    interp.variables.set(name, value);
    #end
  }
  
  /**
   * Removes scripts variable with the given name.
   * @param name
   * @return
   */
  public function removeVariable(name:String):Bool
  {
    #if hscript
    return interp.variables.remove(name) == true;
    #else
    return false;
    #end
  }
  
}