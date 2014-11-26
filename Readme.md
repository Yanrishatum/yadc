## Yet Another Debug Console.

Provides basic console capabilities.  
Commands can be used for simple or in-game restricted use. They can take only 4 types - String, Bool, Float, Int.  
Format of commands:  
`<command name> [arg] [arg] '[arg that contains spaces]' "[args that cotains spaces]"`  
It's recommended to make all command handler arguments optional.  

But mainly console designed for using HScript library. (It's not in dependency list, you must include it manualy)  
Main feature of console is autocomplete, which can be used to speed up writing. The console will show available variables for objects.  
Also you can define "yadc_scan" for advanced class scan. Console will scan all classes in compiled project and will generate an advanced information about methods and variables, and also automatically defines all classes to access inside of scripts.  
Images used in autocomplete component taken from FlashDevelop.  

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
