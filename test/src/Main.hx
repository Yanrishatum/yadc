package ;

import com.yanri.yadconsole.Console;
import com.yanri.yadconsole.ConsoleMode;
import openfl.display.Sprite;
import openfl.Lib;
import test.TestClass;
import test.TestEnum;

/**
 * ...
 * @author Yanrishatum
 */

class Main extends Sprite 
{
  
  public static var t:TestClass;

	public function new() 
	{
		super();
    t = new TestClass();
		Console.enable(ConsoleMode.Scripts).visible = true;
    //var t:TestEnum = TestEnum.ParametrizedValue(2);
    //trace(t);
		// Assets:
		// openfl.Assets.getBitmapData("img/assetname.jpg");
	}
}
