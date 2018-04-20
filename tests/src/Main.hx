package;

import djNode.BaseApp;
import djNode.utils.UserAsk;
import djNode.tools.LOG;
import djNode.utils.ActionInfo;

class Main extends BaseApp

{	
	override function init():Void 
	{
		PROGRAM_INFO = {
			name : "djNode Examples",
			desc : "Use cases and demos",
			version : "0.1"
		}
		
		// Arguments example
		ARGS.inputRule = "opt";	// Inputs are optional
		ARGS.outputRule = "no";	// No output is needed
		ARGS.Actions.push(['d', 'Terminal Demo', 'Proceed Directly to the Terminal Demo']);
		ARGS.Options.push(['-f', 'Fake parameter', 'Test getting an options parameter', 'yes']); // yes=require value
		
		super.init();
	}//---------------------------------------------------;
	
	// --
	override function onStart() 
	{
		printBanner();
		
		// Read Arguments Test/Example
		if (argsOptions.f != null)
		{
			T.println("~~ Option [-f] was set, with a parameter of (" + argsOptions.f + ") ~~");
		}
		
		if (argsAction == 'd')
		{
			T.println("~~ Action [d] was set, Jumping to the Terminal Demo ~~");
			doTest(0);
			return;
		}
		
		T.H2("Component examples/tests :");
		
		// Read Other Input Arguments
		if (argsInput[0] != null) 
		{
			doTest(Std.parseInt(argsInput[0]) - 1);
		}else{
			UserAsk.multipleChoice([
				"Terminal Test",
				"Keyboard Test",
				"Task/Job Test",
				"Job Report Test/Example",
				"ActionInfo.hx Example",
				"Quit"], doTest );
		}
		
	}//---------------------------------------------------;
	
	
	function doTest(s:Int)
	{
		switch(s){
			case 0: new TestTerminal();
			case 1: new TestKeyboard();
			case 2: new TestJobSystem();
			case 3: new TestJobReport();
			case 4: quickTest_ActionInfo();
			case 5: Sys.exit(0);
		}
	}//---------------------------------------------------;
	
	function quickTest_ActionInfo()
	{
		var a = new ActionInfo();
		a.printPair("One", "info");
		a.printPair("Two", "info");
		a.printPair("Three", "info");
		T.drawLine();
		
		a.quickAction("Doing a thing", true,"it did ok");
		a.quickAction("Doing another thing", false, "it failed");
		
		a.actionStart("Action One");
		a.actionProgress("Doing a thing", "and other");
		a.actionEnd(true, "it did it.");
	}//---------------------------------------------------;
	
	// --
	static function main()  {
		new Main();
	}//---------------------------------------------------;
	
}// --