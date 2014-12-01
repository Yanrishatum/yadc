## Yet Another Debug Console.
Provides basic console capabilities.  

### Quick start
#### Installation
The library currently only available on github, no lib.haxe release yet.
`haxelib git yadc https://github.com/Yanrishatum/yadc.git`
#### Enabling console
Call `com.yanri.yadconsole.Console.enable();` from any place of your program.  
Method will return Console instance and will add it to Lib.current.  
`Console.enable` method takes 2 arguments - ConsoleMode and trace capture boolean. If trace capture set to true, all trace calls will be shown in console (yet original trace still will be called).  
If you'll need to access Console instance later, you can found it at `com.yanri.yadconsole.Console.c`.  
To define new commands, use the `addCommand(name:String, ?args:Array<CommandArgumentType>, ?descr:String, handler:Dynamic, thisObj:Dynamic)` method in Console instance.  
To add new variable in scripts, use the `addVariable(name:String, value:Dynamic)` method.  

### Autocomplete
Console provides autocomplete for commands and scripts. It will show possible completions, while user writes text.  
To insert first autocomplete suggestion, you can press `tab` key.  
Note, that basic autocomplete provides only names of variables.
#### The `yadc_scan` define
You can set define `yadc_scan` to perform advanced typing for autocomplete types. If that define set, all compiled classes will be available from scripts, and even types of the variables and functions will be available.  
Note: The application may freeze, while unserializing types info.  

Images used in autocomplete component taken from FlashDevelop.  

### Console modes
#### Commands
Restricted mode, that allows to use only predefined commands. May be used for in-game console, which not gives full control over application.  
Console commands can take only 4 types of arguments - String, Bool, Float, Int.  
Format of commands use:  
`<command name> [arg0] [arg1] '[argument that contains spaces]' "[argument that contains spaces]"`  
Example:  
`bind z pause` - will trigger command `bind` and will send to it 2 String arguments "z" and "pause".  
It's highly recommended to make all arguments in command handler function optional.  
#### Scripts
Mode, that allows to use HScript library in console. Note, that you must manually include HScript library, it's not automatically imports by YADC. If HScript not available, console mode will be changed to "Commands".  
Main feature of console is autocomplete for scripts.  
#### Hybrid
Combined mode. At first, console will try to execute input as Command, and if no such command found (or if there's error while parsing input for command), input will be executed as script.  
It's a default console mode.  
  
  
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
