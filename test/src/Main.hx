package ;

import com.yanri.yadconsole.Console;
import com.yanri.yadconsole.ConsoleMode;
import openfl.display.Sprite;
import openfl.Lib;
import test.TestEnum;

/**
 * ...
 * @author Yanrishatum
 */

class Main extends Sprite 
{

	public function new() 
	{
		super();
		Console.enable(ConsoleMode.Scripts).visible = true;
    var t:TestEnum = TestEnum.ParametrizedValue(2);
    trace(t);
		// Assets:
		// openfl.Assets.getBitmapData("img/assetname.jpg");
	}
}
