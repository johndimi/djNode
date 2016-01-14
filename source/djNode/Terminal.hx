/**----------------------------------------------
 * - Terminal.hx
 * ----------------------------------------------
 * - Useful Terminal functionality wrapper
 * ----------------------------------------------
 * @Author: johndimi, <johndimi@outlook.com>, @jondmt
 * 
 * Features:
 * ===========
 * . Supports NodeJS 
 * . CS Support is in development, doesn't work fully.
 * . Printing text,
 * . Manipulating the cursor,
 * . Colors in Windows and Linux terminals,
 * . Clearing portions of the terminal,
 * 
 * Notes:
 * ============
 * 	References: http://tldp.org/HOWTO/Bash-Prompt-HOWTO/,
 * 				http://ascii-table.com/ansi-escape-sequences.php
 *  			http://www.termsys.demon.co.uk/vtansi.htm
 *  			http://misc.flogisoft.com/bash/tip_colors_and_formatting
 *  
 *  # CS in developemnt
 *  # CPP in development
 * 
 * Important !
 * ============
 *    Cursor position (x:1,y:1) starts NOT from the top left of 
 *  the terminal window, but rather the next line of the prompt.
 *    If you want to have (x,y) start at (1,1) of the term window, 
 *  use the pageDown() function. It will guarantee an empty terminal.
 * 
 * Version History
 * ================
 * # Added support for light backgrounds
 * # Added support for printing formatted text, 
 *   you can now print colored text a lot easier than before,
 * 
 *   e.g. printf("~red~Color Red~bg_white~White BG~!~");
 * 		  is the equivalent of:
 * 	      fg(Color.red).print("Color Red").bg(Color.white).print("White BG").reset();
 * 
 ========================================================*/
package djNode;

import djNode.tools.LOG;
import StringTools;

#if debug
  //import dj.tools.LOG;
#end

#if cs 
  import cs.system.Console;
  import cs.system.ConsoleColor;
#elseif js
  import js.Node;
#elseif cpp
  import cpp.Lib;
#elseif neko
  import neko.Lib;
#end



/*
 * Supported Terminal colors
 **/
@:enum
abstract Color(String) from String to String
{
	var black = "black";	var white = "white";
	var gray = "gray"; 		var darkgray = "darkgray";
	var red = "red"; 		var darkred = "darkred";
	var green = "green"; 	var darkgreen = "darkgreen";
	var blue = "blue"; 		var darkblue = "darkblue";
	var yellow = "yellow"; 	var darkyellow = "darkyellow";
	var cyan = "cyan"; 		var darkcyan = "darkcyan";
	var magenta = "magenta"; var darkmagenta = "darkmagenta";	
}//---------------------------------------------------;


class Terminal
{
	
	//====================================================;
	// VARS
	//====================================================;

	#if (js || cpp || neko) //-- Color system with escape sequences
	// Map colors to escape codes
	private var colormap_fg:Map<Color,String>;
	private var colormap_bg:Map<Color,String>;	
	
	// The escape Sequence can also be '\033[', or even '\e[' in linux
	// I am not using the escape sequence as a reference anywhere, as hard typing is faster.
	private static inline var ESCAPE_SEQ 	= '\x1B['; 	
	private static inline var _BOLD 		= '\x1B[1m';
	private static inline var _DIM 			= '\x1B[2m';
	private static inline var _UNDERL		= '\x1B[4m';
	private static inline var _BLINK 		= '\x1B[5m';
	private static inline var _HIDDEN 		= '\x1B[8m';
	
	private static inline var _RESET_ALL 	= '\x1B[0m';	// All Attributes off
	private static inline var _RESET_FG	 	= '\x1B[39m';	// Foreground to default
	private static inline var _RESET_BG 	= '\x1B[49m';	// Background to default
	private static inline var _RESET_BOLD 	= '\x1B[21m';
	private static inline var _RESET_DIM 	= '\x1B[22m';
	private static inline var _RESET_UNDERL	= '\x1B[24m';
	private static inline var _RESET_BLINK	= '\x1B[25m';
	private static inline var _RESET_HIDDEN	= '\x1B[28m';
	
	// Hold all the available colors.
	private static var AVAIL_COLORS:Array<String> = [ 
		Color.black, Color.white, Color.gray, Color.darkgray,
		Color.red, Color.darkred, Color.green, Color.darkgreen,
		Color.blue, Color.darkblue, Color.cyan, Color.darkcyan,
		Color.magenta, Color.darkmagenta, Color.yellow, Color.darkyellow
	];
	
	#end

	
	//---------------------------------------------------;
	// -- User overridable
	//---------------------------------------------------;
	
	// Used in the sprintf() and printLine() , User can modify these.
	public static var DEFAULT_LINE_WIDTH:Int     = 50;
	public static var DEFAULT_LINE_SYMBOL:String = "-";
	
	// Used in H1...3() and list()
	public static var LIST_SYMBOL:String	=	"*";
	public static var H1_SYMBOL:String		=	"#";
	public static var H2_SYMBOL:String		=	"+";
	public static var H3_SYMBOL:String		=	"=";
	
	//====================================================;
	// FUNCTIONS
	//====================================================;
	
	public function new() 
	{ 
		#if (js || cpp || neko)
		// Set the foregrounds
		colormap_fg = new Map();		
		colormap_fg.set(Color.darkgray, 	'\x1B[90m');
		colormap_fg.set(Color.red, 			'\x1B[91m');
		colormap_fg.set(Color.green,		'\x1B[92m');
		colormap_fg.set(Color.yellow,		'\x1B[93m');
		colormap_fg.set(Color.blue,			'\x1B[94m');
		colormap_fg.set(Color.magenta,		'\x1B[95m');
		colormap_fg.set(Color.cyan,			'\x1B[96m');
		colormap_fg.set(Color.white, 		'\x1B[97m');
		colormap_fg.set(Color.black,		'\x1B[30m');
		colormap_fg.set(Color.darkred, 		'\x1B[31m');
		colormap_fg.set(Color.darkgreen,	'\x1B[32m');
		colormap_fg.set(Color.darkyellow,	'\x1B[33m');
		colormap_fg.set(Color.darkblue, 	'\x1B[34m');
		colormap_fg.set(Color.darkmagenta, 	'\x1B[35m');
		colormap_fg.set(Color.darkcyan, 	'\x1B[36m');
		colormap_fg.set(Color.gray, 		'\x1B[37m');
		//- Set the backgrounds
		colormap_bg = new Map();
		colormap_bg.set(Color.darkgray, 	'\x1B[100m');
		colormap_bg.set(Color.red,			'\x1B[101m');
		colormap_bg.set(Color.green,		'\x1B[102m');
		colormap_bg.set(Color.yellow,		'\x1B[103m');
		colormap_bg.set(Color.blue,			'\x1B[104m');
		colormap_bg.set(Color.magenta,		'\x1B[105m');
		colormap_bg.set(Color.cyan,			'\x1B[106m');
		colormap_bg.set(Color.white, 		'\x1B[107m');
		colormap_bg.set(Color.black,		'\x1B[40m');
		colormap_bg.set(Color.darkred, 		'\x1B[41m');
		colormap_bg.set(Color.darkgreen,	'\x1B[42m');
		colormap_bg.set(Color.darkyellow, 	'\x1B[43m');
		colormap_bg.set(Color.darkblue, 	'\x1B[44m');
		colormap_bg.set(Color.darkmagenta, 	'\x1B[45m');
		colormap_bg.set(Color.darkcyan, 	'\x1B[46m');
		colormap_bg.set(Color.gray, 		'\x1B[47m');
		#end 
	
	}//---------------------------------------------------;
	

	/**
	 * Demo all available colors on the stdout.
	 * WARNING: Will erase the terminal
	 */
	public function demoPrintColors():Void
	{
		#if cs
			H1("Color Demo not supported in CS.");
			return;
		#end
		
		var startingY = 3;
		var startingX = 5;
		var distanceBetweenColumns = 15;
		var cc = startingY;
		
		clearScreen();
		move(1, 1);
		printLine().println("Color Demonstration").printLine();
		
		//-- Draw the foreground colors
		for (i in AVAIL_COLORS) {
			move(startingX, ++cc);
			if (i == Color.black) bg(Color.gray); else bg(Color.black);
			fg(i).print(i).endl().resetFg();
		}
		
		cc = startingY; 
		reset();
		//-- Draw the background colors:
		for (i in AVAIL_COLORS) {
			move(startingX + distanceBetweenColumns, ++cc);
			if (i == Color.white || i == Color.yellow) fg(Color.darkgray); else fg(Color.white);
			bg(i).print(i).endl().resetBg();
		}
		printLine();
	}//---------------------------------------------------;
	
	
	/**
	 * Get Maximum Terminal window width
	 */
	public function getWidth():Int
	{
		#if js
			return untyped(Node.process.stdout.columns);
		#elseif cs
			return Console.WindowWidth;
		#else
			return 80;	//Failsafe default
		#end
	}//---------------------------------------------------;
	
	/**
	 * Get Maximum Terminal window height
	 */	
	public function getHeight():Int
	{
		#if js
			return untyped(Node.process.stdout.rows);
		#elseif cs
			return Console.WindowHeight;
		#else
			return 25; //Failsafe default
		#end
	}//---------------------------------------------------;
	
	/**
	 * Writes to the terminal, unformatted
	 */
	public inline function print(str:String):Terminal
	{
		#if js
			Node.process.stdout.write(str);
		#elseif cpp
			Lib.print(str);
		#else
			Sys.print(str);
		#end
		
		return this;
	}//---------------------------------------------------;
	
	/**
	 * Writes to the terminal, then changes line, unformatted
	 * todo: Do I really need this?
	 */
	public inline function println(str:String):Terminal
	{
		#if js
			Node.process.stdout.write(str + "\n");
		#else
			Sys.println(str);
		#end
		
		return this;
	}//---------------------------------------------------;
	
	/**
	 * Sets the color of the cursor (Foreground color)
	 * @param col, If this is null, the FG is being reset.
	 */
	public function fg(?col:Color):Terminal
	{
		#if (js || cpp || neko)
			if (col == null) return resetFg();
			return print(colormap_fg.get(col));
		#elseif cs
			Console.ForegroundColor = ConsoleColor.Red;
			return this;
		#else
			return this;
		#end
	}//---------------------------------------------------;
	
	/**
	 * Sets the color of the background
	 * @param col, If this is null, the BG is being reset.
	 */
	public function bg(?col:Color):Terminal
	{
		#if (js || cpp || neko)
			if (col == null) return resetBg();
			return print(colormap_bg.get(col));
		#else
			return this;
		#end
	}//---------------------------------------------------;

	// This is mostly unused.
	public function bold():Terminal
	{
		#if (js || cpp || neko)
			return print(_BOLD);
		#else
			return this;
		#end
	}//---------------------------------------------------;

	//--- Resets ---//
	public inline function resetFg():Terminal	{ return print(_RESET_FG); }
	public inline function resetBg():Terminal 	{ return print(_RESET_BG); }
	public inline function resetBold():Terminal	{ return print(_RESET_BOLD); }
	
	/**
	 * Reset all colors and styles to default.
	 */ 
	public inline function reset():Terminal			
	{ 
		#if (js || cpp || neko)
			return print(_RESET_ALL);
		#elseif cs
			Console.ResetColor();
			Console.ForegroundColor = ConsoleColor.White;
			return this;
		#else
			return this;
		#end
	}//---------------------------------------------------;
	
	/**
	 * Moves the curson to the next line of the Terminal
	 */
	public inline function endl():Terminal
	{
		return print("\n");
	}//---------------------------------------------------;
	
	
	/** 
	 * Cursor Control Functions 
	 **/
	public inline function up(x:Int = 1):Terminal 		{ return print('\x1B[${x}A'); }
	public inline function down(x:Int = 1):Terminal 	{ return print('\x1B[${x}B'); }
	public inline function forward(x:Int = 1):Terminal  { return print('\x1B[${x}C'); }
	public inline function back(x:Int = 1):Terminal 	{ return print('\x1B[${x}D'); }
	
	//----------------------------------------------------;
	
	/**
	 * Moves the cursor to a specific X and Y position on the Terminal
	 */
	public inline function move(x:Int, y:Int):Terminal
	{
		#if (js || cpp || neko)
			return print('\x1B[${y};${x}f');
		#elseif cs
			Console.SetCursorPosition(x, y); 
			return this;
		#else
			return this;
		#end
	}//---------------------------------------------------;
	
	/**
	 * Stores the position of the cursor, for later use
	 * with restorePos()
	 */
	public inline function savePos():Terminal
	{
		return print('\033[s');
	}//---------------------------------------------------;

	/**
	 * Restores the cursor to the position it was stored
	 * by savePos()
	 */
	public inline function restorePos():Terminal
	{
		return print('\033[u');
	}//---------------------------------------------------;
	
	/**
	 * Scrolls the Terminal down, it doesn't erase anything.
	 * -- it just scrolls down to window height --
	 */
	public function pageDown():Terminal
	{
		print(StringTools.lpad("", "\n", getHeight() + 1));
		return move(1, 1);
	}//---------------------------------------------------;

	/**
	 * Clears the next X characters from the current stored cursor rosition
	 * @param num Number of Characters to clear
	 */
	public function clearFromHere(num:Int):Terminal
	{
		savePos().print(StringTools.lpad("", " ", num));
		return restorePos();
	}//---------------------------------------------------;
	
	/**
	 * Clears the line the cursor is at.
	 * @param ?type 0-Clear all forward, 1-Clear all back, 2-Clear entire line(default)
	 */
	public function clearLine(?type:Int):Terminal
	{
		return print('\x1B[' + Std.string((type != null) ? type : 2) + 'K');
	}//---------------------------------------------------;
	
	//====================================================;
	// STYLING
	//====================================================;
	
	/**
	 * Prints a horizontal line in current place
	 * The line has a default width of 40 chars
	 * @param symbol optional custom symbol
	 * @param length optional custom length
	 */
	public function printLine(?symbol:String,?length:Int):Terminal 
	{
		if (symbol == null) symbol = DEFAULT_LINE_SYMBOL;
		if (length == null) length = DEFAULT_LINE_WIDTH;
		return print(StringTools.lpad("", symbol, length)).endl();
	}//---------------------------------------------------;
	
	/**
	 * Write a text with Header 1 formatting
	 * @param text
	 */
	public function H1(text:String, color:String = "darkgreen")
	{		
		printf('~$color~ $H1_SYMBOL~!~ ~white~~bg_$color~$text~!~\n ~line~');
	}//---------------------------------------------------;
	
	/**
	 * Write a text with Header 2 styling
	 * @param text
	 */
	public function H2(text:String, color:String = "cyan")
	{
		printf(' ~bg_$color~~black~$H2_SYMBOL~!~ ~$color~$text~!~\n ~line2~');
	}//---------------------------------------------------;
	
	/**
	 * Write a text with Header 2 styling
	 * @param text
	 */
	public function H3(text:String, color:String = "blue")
	{
		printf('~$color~ $H3_SYMBOL ~!~$text\n ~line2~');
	}//---------------------------------------------------;
	
	/**
	 * Add a list styled element
	 * @param text The label to add
	 */
	public function list(text:String, color:String = "green")
	{
		printf('~$color~  $LIST_SYMBOL ~!~$text\n');
	}//---------------------------------------------------;
	
	/**
	 * Print formatted text,
	 * Check sprintf() for rules
	 */
	public inline function printf(str:String):Terminal
	{
		return print(sprintf(str));
	}//---------------------------------------------------;
	

	/**
	 * Convert markup text to ready to a terminal-ready
	 * escaped sequence text.
	 * 
	 * Examples:
	 * "~yellow~This is yellow. ~red~And this is red~!~"
	 * "~line~~Text~~line~"
	 * 
	 */
	public function sprintf(str:String):String
	{
		// Match anything between ~ ~, (including the ~ symbols)
		return(~/(~\S[^~]*~)/g.map(str, function(reg) {
			// Remove the leading and trailing '~' symbol
			var s = reg.matched(0).substring(1).substr(0, -1);
			switch(s) {
			case "!"	: return _RESET_ALL;
			case "!fg"	: return _RESET_FG;
			case "!bg"	: return _RESET_BG;
			case "line":  return StringTools.lpad("", DEFAULT_LINE_SYMBOL, DEFAULT_LINE_WIDTH) + "\n";
			case "line2": return StringTools.lpad("", DEFAULT_LINE_SYMBOL, Math.ceil(DEFAULT_LINE_WIDTH / 2)) + "\n";
			
			case "!line": trace("Error: Deprecated"); return "--deprecated--";
			case "!line2": trace("Error: Deprecated"); return "--deprecated--";

			// Proceed checking for colors or bg colors:
			default :
			try{
			 if(s.substr(0, 3)=="bg_")
				return colormap_bg.get(s.substr(3));
			 else 
				return colormap_fg.get(s);
			 }catch (e:Dynamic) {
				// Error getting the color, user must have typoed.
				return "";
				#if debug
				LOG.log("Parse error, check for typos, str=" + str, 2);
				#end
			 }
			}//end switch
		}));
	}//---------------------------------------------------;
	
	
	/**
	 * Clears the screen and positions the cursor to (1,1)
	 * @param ?type 0-Clear all forward, 1-Clear all back, 2-Clear entire screen(default)
	 */
	public function clearScreen(?type:Int):Terminal
	{
		#if (js || cpp || neko)
			return print('\x1B[' + Std.string((type != null) ? type : 2) + 'J');
			// if (type == null || type == 2) move(1, 1); return this; // whole line might be redundant
		#elseif cs
			Console.Clear();
			return this;
		#end
			return this;
	}//---------------------------------------------------;
	
}//-- end class--//