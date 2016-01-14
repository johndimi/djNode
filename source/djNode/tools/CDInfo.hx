/****
 * CDInfo
 * -------
 * johndimi, <johndimi@outlook.com>, @jondmt
 * -------
 * @requires: none
 * @supportedplatforms: nodeJS
 * 
 * Very simple CD Descriptor file parser.
 * 
 * Supports: reading (.cue.ccd)
 * 			 writing (.cue)
 * 
 * @WARNING! Is not fully featured, as it was mostly
 * 			 designed to work with the cdcrush project
 * 
 * 			ONLY WORKS WITH 2352 sector cds
 * 
 * V0.91 - (working)
 *  . BUGFIX, support for CD's where first track is audio. ( fixes pc-engine games )
 * V0.9
 *  . Support for ccd and cue loading
 *  . Saving cue files
 * 
 * Notes.
 * 	Cue File Syntax: http://digitalx.org/cue-sheet/syntax/
 * ---------------------------------------*/

package djNode.tools;

import djNode.tools.FileTool;
import djNode.tools.LOG;
import haxe.Json;

import js.Node;
import js.node.Fs;
import js.node.Path;

class CDInfo
{
	//====================================================;
	// VARS
	//====================================================;
	
	// If loaded a descriptor file, store it's path here
	public var loadedFile:String;
	// Path to the actual image file
	public var image_path:String;
	// Size in bytes
	public var image_size:Int;
	// Title of the CD
	public var TITLE:String;
	// Working Sector Size of the CD
	public var SECTORSIZE:Int;
	// Type of CD mode, e.g. "Mode2/2352"
	public var TYPE:String;	
	// Hold the info for all the tracks
	public var tracks:Array<CueTrack>;
	// 
	public var tracks_total:Int;
	
	// --- HELPERS ---
	var openTrack:CueTrack;
	// The dir holding the loaded descriptor file
	var loadedFile_dir:String;
	// Type
	var loadedFile_ext:String;	//e.g. "cue","ccd"
	// Filename for single generated image files, used in the save cue procedure
	public var imageFilename:String;
	
	//====================================================;
	// FUNCTIONS
	//====================================================;
	
	
	public function new(?descriptorFile:String) {
		if (descriptorFile != null) load(descriptorFile);
	}//------------------------------------
	public function getSupportedFormats():Array<String> {
		return ['cue', 'cdd'];
	}//------------------------------------
	public function getSectorsByDataType(type:String):Int {
		switch(type)
		{
			case "AUDIO": 		return 2352;	// PCM Audio
			case "CDG" : 		return 2352;	// Karaoke cd+g
			case "MODE1/2048":	return 2048;	// CDROM Mode1 Data (cooked)
			case "MODE1/2352":	return 2352;	// CDROM Mode1 Data (raw)
			case "MODE2/2336":	return 2336;	// CDROM XA Mode2 Data
			case "MODE2/2352":	return 2352;	// CDROM XA Mode2 Data
			case "CDI/2336":	return 2336;	// CDI Mode2 Data
			case "CDI/2352":	return 2352;	// CDI Mode2 Data
			default: throw "Unsuported type " + type;
		}
	}//------------------------------------
	
	
	/**
	 * Load a cd descriptor file
	 * @ASSERT, the file is checked before loading
	 * @param input, file can be [cue|ccd]
	 * @THROWS ERRORS (string)
	 *--------------------------------------------*/
	public function load(input:String):Void
	{
		LOG.log("CDInfo, loading " + input);
		/** Check to see if file exists */
		if (FileTool.pathExists(input) == false) {
			throw 'Cue file "$input" does not exist.';
		}
		
		// Init Variables
		loadedFile = input;
		image_path = null; image_size = 0;
		tracks = new Array(); tracks_total = 0;
		TITLE = "untitled"; SECTORSIZE = 0; TYPE = null;
		openTrack = null;
		loadedFile_dir = Path.dirname(loadedFile);
		loadedFile_ext = Path.extname(input).toLowerCase().substr(1);
	
		// Auto Guess CD TITLE based on input filename
		var rtitle:EReg = ~/([^\/\\]*)\.(?:ccd|cue)$/i;
		if (rtitle.match(input)) TITLE = rtitle.matched(1);
		LOG.log('Guessed cd title = $TITLE');
		
		// Setup the parser
		var parser = new CDParser(input);
		
		parser.parseWith(switch(loadedFile_ext) {
			case "cue": parser_cue;
			case "ccd": parser_ccd;
			case _: throw 'Unsupported file type "$loadedFile_ext"';
		});
		
		parser = null;
		//Do stuff post parsing
		postParse_check(loadedFile_ext);
		
	}//-------------

	/* Parsing is complete, check the parsed data
	 * and set some variables
	 */ 
	private function postParse_check(ext:String)
	{
		if (tracks_total == 0) {
			throw "No Tracks in the cue file";
		}
		
		_getCDTypeFromTracks();
		
		LOG.log('CD Type = ' + TYPE);
		LOG.log('Number of tracks = ' + tracks.length);
		LOG.log('Image file = ' + image_path);
		
		// Format specific checks
		// ASSERT the cd image exists
		switch(ext) {
		
			
			case "cue":
			if (image_path == null) throw "Image file is not set";
			//check to see if image is fullpath
			if (!FileTool.pathExists(image_path)) {
				image_path = Path.join(loadedFile_dir, image_path);
				if (FileTool.pathExists(image_path) == false) 
					throw "Image file does not exist - " + image_path;
			}
				
			case "ccd":
			// Try to find the image along the inputFile	
			var tryToFind:Array<String> = [".bin", ".img"];
			for (i in tryToFind) {
				//trace("Searching : " + Node.path.join(loadedFile_dir, TITLE + i));
				if (FileTool.pathExists(Path.join(loadedFile_dir, TITLE + i))) {
					image_path = Path.join(loadedFile_dir, TITLE + i);
					break; 
				}
			}
			if (image_path == null) throw "Can't find image";
		
		}//--
		
		if (~/(\.bin|\.img|\.iso)$/i.match(image_path) == false) {
			throw "Image Filename is not a .bin/.img/.iso";
		}
		
		//Calculate the tracks sector size
		var imageStats = Fs.statSync(image_path);
		var imageSectorSize = Math.ceil(imageStats.size / SECTORSIZE);
		image_size = Std.int(imageStats.size);
		
		//Calculate tracks, starting from the end backwards to 0
		var c = tracks_total - 1; 
		//calculate last track manually, out of the loop
		tracks[c].calculateStart();
		tracks[c].sectorSize = imageSectorSize - tracks[c].sectorStart;
		while (--c >= 0) {	//and all the others in a loop
			tracks[c].calculateStart();
			tracks[c].sectorSize = tracks[c + 1].sectorStart - tracks[c].sectorStart;
		}			
	}//------------------------------------------
	
	
	/* CUE file parser
	 */ 
	private function parser_cue(line:String):Void
	{
		//skip comments
		if ( ~/^REM/i.match(line) ) return;
		
		// Get FILE image name
		if ( ~/^FILE/i.match(line) ) {
			//might want to change this to  matched regexpr
			image_path = ~/["']+/g.split(line)[1];
			return;
		}//--
		
		// Get Track NO and track TYPE
		var regTrack:EReg = ~/^\s*TRACK\s+(\d+)\s+(\S+)/i;
		if (regTrack.match(line)) {
			// [SAFEGUARD] Check to see if the trackNO is already defined in the tracks
			for (i in tracks) {
				if (i.trackNo == Std.parseInt(regTrack.matched(1))) {
					throw 'Parse Error, Track-${i.trackNo} is already defined';
				}
			}
			var track = new CueTrack(regTrack.matched(1), regTrack.matched(2));
			tracks.push(track);
			tracks_total++;
			openTrack = tracks[tracks_total - 1];	//point to the last track
			return;
		}//--
		
		// Get Index
		var regIndex:EReg = ~/^\s*INDEX\s+(\d+)\s+(\d{1,2}):(\d{1,2}):(\d{1,2})/i;
		if (regIndex.match(line)) {
			if (openTrack == null) throw "Parse error, Track is not yet defined";
			var indexno = Std.parseInt(regIndex.matched(1));
			if (openTrack.indexExists(indexno)) {
				throw 'Parse Error, track-{$openTrack.trackNo} ' + 
					  ', Duplicate Index entry. Index[$indexno]';
			}
			
			openTrack.addIndex( indexno,
								Std.parseInt(regIndex.matched(2)), 
								Std.parseInt(regIndex.matched(3)), 
								Std.parseInt(regIndex.matched(4)) );
			return;
		}//--
		
		// Get PREGAP
		var regPregap:EReg = ~/^\s*PREGAP\s+(\d{1,2}):(\d{1,2}):(\d{1,2})/i;
		if (regPregap.match(line)) {
			if (openTrack == null) throw 'Track is not yet defined';
			openTrack.setGap(regPregap.matched(1), regPregap.matched(2), regPregap.matched(3));
			return;
		}

	}//----------------------------
	

	/* Clone cd. CCD file parser
	 */
	private function parser_ccd(line:String):Void {
		
		var regGetTrackNo = ~/\[TRACK\s*(\d*)\]/;
		if ( regGetTrackNo.match(line) ) {
			var tr = new CueTrack(regGetTrackNo.matched(1));
			tracks.push(tr);
			openTrack = tr;
			LOG.log('discovered Track - $tr');
			tracks_total++;
			return;
		}

		var regGetMode = ~/\n*\s*MODE\s*=\s*(\d)/;
		if ( regGetMode.match(line) ) {
			if (openTrack == null) { throw "Illegal MODE, No track is defined yet."; }
			switch(regGetMode.matched(1)) {
				case "0": openTrack.type = "AUDIO"; openTrack.isData = false; LOG.log('AUDIO - ');
				case "2": openTrack.type = "MODE2/2352"; LOG.log('discovered Track - MODE2/2352');
			}
			return;
		}

		var regGetIndex = ~/\s*INDEX\s*(\d)\s*=\s*(\d*)/;
		if ( regGetIndex.match(line)) {
			if (openTrack == null) { throw "Illegal INDEX, No track is defined yet."; }
			var ino = Std.parseInt(regGetIndex.matched(1));	//index no
			var sst = Std.parseInt(regGetIndex.matched(2)); //sector start
			openTrack.addIndexBySector(ino, sst);
			return;
		}
		
		// TODO COMPLETE THE CCD PARSER? might be incomplete
	}
	
	
	
	/**
	 * Save the current cd info as a cue file
	 * @param	output File to save
	 * @param	multiFileCue Set true to save as a multitrack/compressed cue, False for a single BIN.
	 * @param	comment
	 */
	public function saveAs_Cue(output:String, ?multiFileCue:Bool, ?comment:String):Void
	{
		var data = "";
		var i = 0;	//Start with the second track.
		var tr:CueTrack;
		if (multiFileCue == null) multiFileCue = false;
		if (tracks_total == 0) throw "No Tracks to write";
		
		if (TITLE == null) {
			LOG.log("Title is null, autoset to 'untitled'", 2);
			TITLE = "untitled";
		}
		
		imageFilename = TITLE + '.bin';
		
		while (i < tracks_total) {
			tr = tracks[i];
			
			if (multiFileCue == false) {
				if (i == 0)
				data += 'FILE "' + imageFilename + '" BINARY\n';
			}else
			{
				data += 'FILE "' + tr.filename + '" ' + 
							FileTool.getFileExt(tr.filename).toUpperCase() + '\n';
			}
			
			data += "\tTRACK " + tr.getTrackNoSTR() + ' ${tr.type}\n';
			
			//--Check pregap
			if (tracks[i].hasPregap()) 
			data += "\t\tPREGAP " + tracks[i].getPregapString() + "\n";
			
			if(multiFileCue) {
				// Add just one index because it's multiple files
				// and no multiple indexes are needed.
				data += "\t\tINDEX 01 00:00:00\n";
			} else {
				//-- Add all the indexes
				var t=0;
				while(t<tracks[i].indexTotal){
					var ind = tracks[i].indexAr[t];
					data += "\t\tINDEX ";
					if (ind.no < 10) data += "0";
					data += ind.no + " ";
					data += tracks[i].getIndexTimeString(t) + "\n";
					t++;
				}//--while
			}//--endif
			
			i++;
			
		}//--while
		
		// Comment at the end
		if (comment != null) {
			data += "REM " + comment;
		}
		
		Fs.writeFileSync(output, data, 'utf8');
	}//-------------------
	

	// Special occation.
	// Create info data based on a single track image
	// This does not rename the filename!!! It must be done elsewhere
	public function createFromImage(filename:String):Void
	{
		tracks = new Array(); tracks_total = 0;
		
		var rtitle:EReg = ~/([^\/\\]*)\.(?:bin|iso|img)$/i;
		if (rtitle.match(filename)) TITLE = rtitle.matched(1);
		LOG.log('createFromImage() - Guessed cd title = $TITLE');
		
		image_path = filename;
		var imext = FileTool.getFileExt(image_path);
		if (["bin", "img", "iso"].indexOf(imext) < 0) throw "createFromImage, unsupported Image Extension";
		if (!FileTool.pathExists(image_path)) throw "createFromImage(), " + image_path + " - does not exist";
		
		var size = Fs.statSync(image_path).size;
		var sectors = size / SECTORSIZE;	
		if (sectors % SECTORSIZE > 0) 
			throw 'Size mismatch error, "$image_path" should be of size multiple of $SECTORSIZE';
		
		var tr = new CueTrack(1, "MODE2/2352");
			tr.filename = tr.getFilenameRaw();
			tr.addIndex(1, 0, 0, 0);
			tracks.push(tr);
			tracks_total++;
			
		_getCDTypeFromTracks();

	}//--------
	
	
	//-- SYNC --
	// Save the object info to a file for future restoration
	public function self_save(filename:String):Void
	{
		if (tracks_total == 0) throw "Warning , No tracks to save";
		
		// Filenames are in compressed form by default? is this ok?
		for (i in tracks) {
			if (i.filename == null) throw 'Track ${i.trackNo} should have a filename set';
		}

		// What will be written on the file
		var o = { 	cdTitle:TITLE,
					sectorSize:SECTORSIZE,
					imageSize:image_size,
					tracks:tracks };
					
		// !!CHANGED!!
		//  Fs.writeFileSync(filename, Node.json.stringify(o, null, 4) );
		//  to
			Fs.writeFileSync(filename, Json.stringify(o, null, "\t"), "utf8");
	}//------
	
	
	// Restore the object info from file
	// # SYNC EXEC
	// # THROWS String errors!
	public function loadSettingsFile(filename:String):Void
	{
		if (FileTool.pathExists(filename) == false) {
			throw 'CDInfo file "$filename" does not exist';
		}
		
		LOG.log('CDInfo restoring data - $filename');
			
		var obj = Json.parse( Fs.readFileSync(filename, { encoding:"utf8" } ));
		
		tracks = new Array();
		tracks_total = Reflect.fields(obj.tracks).length;
		
		var i = 0;
		while (i < tracks_total ) {
			var tr = new CueTrack();
			// Copy all the fields from the json to instantiated object
			for (a in Reflect.fields(obj.tracks[i])) {
				Reflect.setField(tr, a, Reflect.getProperty(obj.tracks[i], a)); 
			}
			tracks.push(tr);
			i++;
		}//--
		
		// Set isData property
		for (i in tracks) {
			if (i.type != "AUDIO") i.isData = true; else i.isData = false;
		}
		
		TITLE = obj.cdTitle;
		imageFilename = TITLE + '.bin';
		image_size = obj.imageSize;
		_getCDTypeFromTracks();
		
		LOG.log("Title = " + TITLE);
		LOG.log("Tracks Total = " + Std.string(tracks_total));
		LOG.log("SectorSize = " + Std.string(SECTORSIZE));
	
	}//-------
	
	private function _getCDTypeFromTracks():Void
	{
		TYPE = null;
		// Get CD type
		for (i in tracks){
			if (i.isData) {
				TYPE = i.type;
				break;// no need to check other data tracks
			}
		}
		if (TYPE == null) //This must be a AUDIO only CD
			TYPE = "AUDIO";
			
		SECTORSIZE = getSectorsByDataType(TYPE);
	}//---------------------------------------------------;
	

}//-- end class --//


// -- Helper class
// Parses a cuesheet line by line, by calling the apropriate parser
class CDParser {
	
	// Store the descriptor file here as an array
	var file:Array<String>;
	// How mane lines in the cuesheet.
	var maxLines:Int;
	// Generic counter
	var c:Int;

	public function new(input:String) {
		// File exists, it was checked before in the CDInfo Class
		var fileContent = Fs.readFileSync(input, { encoding:"utf8" } );
		// file is now an array of lines
		file = fileContent.split("\n");
		c = 0; maxLines = file.length;
	}//---------------------------------------------------;
	
	public function parseWith(fn:String->Void):Void
	{
		// Traverse every line in file array
		do { 
			if (file[c] == null) continue;			// should not happen, right?
			file[c] = ~/^\s+/.replace(file[c], ""); // remove leading whitespaces from line
			file[c] = ~/\s+$/.replace(file[c], ""); // remove ending whitespaces from line
			if (file[c].length == 0) continue;  	// skip blank lines
		
			try{
				fn(file[c]);
			}catch (e:String) {
				throw 'Parse Error - Line $c \n - $e';
			}
		}while (++c < maxLines);
		
	}//-----
}//-- end class CDInfo --//



class CueIndex {
	public var no:Int;
	public var minutes:Int;
	public var seconds:Int;
	public var millisecs:Int;
	public function new(){}
}//--------------------------

class CueTrack
{
	public var trackNo:Int;
	public var isData:Bool; //
	public var type:String; // STRING ID, e.g. "mode2/2352"

	//There can be more than 1 indexes
	public var indexTotal:Int = 0;
	public var indexAr:Array<CueIndex>;

	public var sectorSize:Int = 0;		//Real sector count
	public var sectorStart:Int = 0;		//Starting Sector on the IMAGE!

	public var pregapMinutes:Int = 0;
	public var pregapSeconds:Int = 0;
	public var pregapMillisecs:Int = 0;

	public var filename:String = "";
	
	public function new(?trackNo:Dynamic,?type:String) {
		this.trackNo = Std.parseInt(trackNo);
		if(type!=null) this.type = type.toUpperCase();
		indexAr = new Array();
		if (type != "AUDIO") isData = true; else isData = false;
	}//--------------------------------
	public function indexExists(indexNo:Int):Bool {
		for(i in indexAr) {
			if(i.no == indexNo) return true;
		}
		return false;
	}//--------------------------------
	public function calculateStart():Void {
		if(indexTotal==0) {
			throw 'Track-$trackNo has no index defined';
		}
		sectorStart  = indexAr[0].minutes * 4500;
		sectorStart += indexAr[0].seconds * 75;
		sectorStart += indexAr[0].millisecs;
	}//--------------------------------
	public function addIndex(index:Int, minutes:Int, seconds:Int, millisecs:Int):Void {
		var i = new CDInfo.CueIndex();
		i.no = index;
		i.minutes   = minutes;
		i.seconds   = seconds;
		i.millisecs = millisecs;
		indexAr[indexTotal++] = i;
		//trace('Track[$trackNo] , Added index ${i.no}');
	}//---------------------------------
	public function addIndexBySector(index:Int, size:Int):Void {
		var mm = Math.floor(size / 4500);
		var ss = Math.floor( (size % 4500) / 75);
		var ms = (size % 4500) % 75;
		addIndex(index, mm, ss, ms);	
	}//---------------------------------
	public function setGap(mm:Dynamic, ss:Dynamic, ms:Dynamic):Void {		
		pregapMinutes   =  Std.parseInt(mm);
		pregapSeconds   =  Std.parseInt(ss);
		pregapMillisecs =  Std.parseInt(ms);
	}//---------------------------------
	public function getTrackName():String {
		return "Track" + getTrackNoSTR();
	}//---------------------------------
	public function getTrackNoSTR():String {
		return ((trackNo > 9)?Std.string(trackNo):("0" + trackNo));
	}//---------------------------------------------------;
	public function getFilenameRaw():String{
		var r = getTrackName() + ".";
		if (isData) r += "bin"; else r += "pcm";
		return r;
	}//--------------------------------
	public function getIndexTimeString(ind:Int):String {
		var i:CueIndex = indexAr[ind];
		return __timedString([i.minutes, i.seconds, i.millisecs]);
	}//--------------------------------
	public function getPregapString():String  {
		return __timedString([pregapMinutes, pregapSeconds, pregapMillisecs]);
	}//--------------------------------	
	public function hasPregap():Bool {
		return (pregapMillisecs > 0 || pregapSeconds > 0 || pregapMinutes > 0);
	}//--------------------------------
	/* Take a bunch of numbers and convert them to a TIME STRING.
	 *  e.g. [1,10,9] ==> "01:10:09" */
   private function __timedString(ar:Array<Int>) {
	   var o = ""; var i = 0;
	   while (i < ar.length) {
		   if (ar[i] < 10) o += "0";
		   o += Std.string(ar[i]) + ":";
		   i++;
	   }
	   return o.substr(0, -1);//remove the last ":"
   }//--------------------------------
		
}//-- CueTrack--//