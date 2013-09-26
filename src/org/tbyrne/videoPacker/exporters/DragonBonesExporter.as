package org.tbyrne.videoPacker.exporters
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;
	import flash.utils.getTimer;
	
	import control.ExportDataCommand;
	
	import model.XMLDataProxy;
	import model.ImportDataProxy;
	
	import org.tbyrne.StateObject;
	import org.tbyrne.videoPacker.VideoPacker;
	import org.tbyrne.videoPacker.VideoPackerChunk;

	public class DragonBonesExporter extends StateObject implements IVideoExporter
	{
		
		private static var DUMMY_RECT:Rectangle = new Rectangle();
		private static var DUMMY_POINT:Point = new Point();
		
		public static const STATE_FRAME_CHECK:String = "frameCheck";
		public static const STATE_TEXTURE_BUILD:String = "textureBuild";
		public static const STATE_XML_BUILD:String = "xmlBuild";
		public static const STATE_DONE:String = "done";
		
		public static const DEFAULT_DIFF_TOLERANCE:Number = 0.1;
		public static const DEFAULT_TEXTURE_PADDING:Number = 1;
		
		private var _videoPacker:VideoPacker;
		
		private var _dbXml:XML;
		private var _textureXml:XML;
		public var lastCompareImage:BitmapData;
		public var textureImage:BitmapData;
		
		public var diffTolerance:Number = DEFAULT_DIFF_TOLERANCE;
		public var texturePadding:Number = DEFAULT_TEXTURE_PADDING;
		
		private var _xmlDataProxy:XMLDataProxy;
		private var _exportCommand:ExportDataCommand;
		
		public function DragonBonesExporter()
		{
			_exportCommand = new ExportDataCommand();
			_xmlDataProxy = new XMLDataProxy();
		}
		public function setVideoPacker(videoPacker:VideoPacker):void{
			_videoPacker = videoPacker;
		}
		
		public function process(timeAlloc:int):void{
			if(!state || state==STATE_DONE){
				_dbXml = <dragonBones name="EngineDB" frameRate="60" version="2.3"/>;
				setState(STATE_FRAME_CHECK);
				_currentChunk = _videoPacker.rootChunk;
				_currentFrame = 0;
				_chunkToBundle = new Dictionary();
				_allFrames = new Vector.<BitmapData>();
				_allFrameNames = new Vector.<String>();
				_textureGraph = new Dictionary();
				_baselineMap = new Dictionary();
				_baseLines = new Vector.<int>();
				_baseLines.push(0);
				_baselineMap[0] = new Vector.<Rectangle>();
				textureImage = null;
				lastCompareImage = null;
				_allBundles = new Vector.<ChunkBundle>();
				_textureWidth = 0;
				_textureHeight = 0;
			}
			
			switch(state){
				case STATE_FRAME_CHECK:
					frameCheck(timeAlloc);
					break;
				
				case STATE_TEXTURE_BUILD:
					textureBuild(timeAlloc);
					break;
				
				case STATE_XML_BUILD:
					xmlBuild(timeAlloc);
					break;
			}
		}
		
		private var _chunkToBundle:Dictionary;
		
		private var _currentChunk:VideoPackerChunk;
		private var _currentBundle:ChunkBundle;
		private var _currentFrame:int = 0;
		private var _allFrames:Vector.<BitmapData>;
		private var _allFrameNames:Vector.<String>;
		private var _allBundles:Vector.<ChunkBundle>;
		
		public function frameCheck(timeAlloc:int):void{
			var start:int = getTimer();
			do{
				if(!_currentBundle){
					_currentBundle = new ChunkBundle();
					_currentBundle.chunk = _currentChunk;
					_currentBundle.id = createId(_currentChunk);
					_chunkToBundle[_currentChunk] = _currentBundle;
					_allBundles.push(_currentBundle);
				}
				var mainFrame:BitmapData = _videoPacker.bitmaps[_currentFrame];
				var frame:BitmapData = new BitmapData(_currentChunk.width, _currentChunk.height, true, 0);
				
				DUMMY_RECT.x = _currentChunk.x;
				DUMMY_RECT.y = _currentChunk.y;
				DUMMY_RECT.width = _currentChunk.width;
				DUMMY_RECT.height = _currentChunk.height;
				
				frame.copyPixels(mainFrame, DUMMY_RECT, DUMMY_POINT);
				
				for(var j:int=0; j<_currentChunk.children.length; ++j){
					var child:VideoPackerChunk = _currentChunk.children[j];
					DUMMY_RECT.x = child.x;
					DUMMY_RECT.y = child.y;
					DUMMY_RECT.width = child.width;
					DUMMY_RECT.height = child.height;
					
					frame.fillRect(DUMMY_RECT, 0);
				}
				
				var found:Boolean = false;
				for(var i:int=_currentBundle.frames.length-1; i>=0; --i){
					var othFrame:BitmapData = _currentBundle.frames[i];
					var compare:BitmapData = othFrame.compare(frame) as BitmapData;
					var dif:Number = getColorAverageFract(compare);
					lastCompareImage = compare;
					
					if(dif<diffTolerance){
						found = true;
						_currentBundle.frameRefs.push(i);
						break;
					}
				}
				if(!found){
					var frameName:String = _currentBundle.id+"-"+_currentFrame;
					_allFrames.push(frame);
					_allFrameNames.push(frameName);
					_currentBundle.frames.push(frame);
					_currentBundle.frameNames.push(frameName);
					_currentBundle.frameRefs.push(_currentBundle.frames.length-1);
				}
				
				++_currentFrame;
				
				if(_currentFrame==_videoPacker.bitmaps.length){
					
					_currentFrame = 0;
					_currentBundle = null;
					
					if(_currentChunk.children.length){
						_currentChunk = _currentChunk.children[0];
					}else{
						
						var siblings:Vector.<VideoPackerChunk> = _currentChunk.parent.children;
						var index:int;
						while((index = siblings.indexOf(_currentChunk))==siblings.length-1){
							_currentChunk = _currentChunk.parent;
							if(!_currentChunk.parent){
								siblings = null;
								break;
							}
							siblings = _currentChunk.parent.children;
						}
						if(siblings){
							_currentChunk = siblings[index+1];
						}else{
							_currentChunk = null;
							_currentBundle = null;
							_textureIndex = -1;
							setState(STATE_TEXTURE_BUILD);
							return;
						}
					}
				}
			}while(getTimer() < start + timeAlloc);
		}
		
		private var _textureIndex:int = -1;
		private var _textureGraph:Dictionary;
		private var _baselineMap:Dictionary;
		private var _baseLines:Vector.<int>;
		private var _textureIndices:Array;
		private var _textureWidth:int;
		private var _textureHeight:int;
		private var _lastPos:Rectangle;
		
		public function textureBuild(timeAlloc:int):void{
			var start:int = getTimer();
			do{
				var frame:BitmapData;
				var rect:Rectangle;
				if(_textureIndex==_allFrames.length){
					textureImage = new BitmapData(_textureWidth, _textureHeight);
					_textureXml = <TextureAtlas name="EngineDB"/>;
					
					trace("TOTAL FRAMES: "+_allFrames.length);
					for(i=0; i<_allFrames.length; ++i){
						frame = _allFrames[i];
						var id:String = _allFrameNames[i];
						rect = _textureGraph[id];
						
						textureImage.copyPixels(frame, frame.rect, rect.topLeft);
						
						_textureXml.appendChild(<SubTexture name={id} x={rect.x} y={rect.y} width={rect.width} height={rect.height}/>);
					}
					_bundleIndex = 0;
					setState(STATE_XML_BUILD);
					return;
				}
				var i:int;
				if(_textureIndex==-1){
					// sort textures by area
					var areas:Array = [];
					for(i=0; i<_allFrames.length; ++i){
						frame = _allFrames[i];
						areas.push(frame.width*frame.height);
					}
					_textureIndices = areas.sort(Array.RETURNINDEXEDARRAY);
				}else{
					var texture:BitmapData = _allFrames[_textureIndices[_textureIndex]];
					var textureName:String = _allFrameNames[_textureIndices[_textureIndex]];
					var w2n:int = getNearest2N(texture.width);
					var h2n:int = getNearest2N(texture.height);
					
					if(_textureWidth<w2n){
						_textureWidth = w2n;
					}
					if(_textureHeight<h2n){
						_textureHeight = h2n;
					}
					do{
						if(_textureIndex==0){
							// is first texture, position at 0,0
							rect = new Rectangle(0,0,texture.width, texture.height);
						}else{
							rect = null;
							for(i=0; i<_baseLines.length; ++i){
								var baseline:int = _baseLines[i];
								var list:Vector.<Rectangle> = _baselineMap[baseline];
								var minX:int = list.length?list[list.length-1].right+texturePadding:0;
								if(minX+texture.width>_textureWidth)continue;
								if(baseline+texture.height>_textureHeight)break;
								
								//var maxY:int = _textureHeight;
								for(var j:int = 0; j<_baseLines.length; ++j){
									if(j==i)continue;
									
									var othBaseline:int = _baseLines[j];
									if(othBaseline > baseline+texture.height)break;
									
									var othList:Vector.<Rectangle> = _baselineMap[othBaseline];
									if(!othList.length)continue;
									
									
									for(var k:int = 0; k<othList.length; ++k){
										var othRect:Rectangle = othList[k];
										if(othRect.top<baseline+texture.height && othRect.bottom>baseline){
											if(othRect.right>minX)minX = othRect.right+texturePadding;
										}
									}
								}
								if(minX+texture.width>_textureWidth)continue;
								
								rect = new Rectangle(minX, baseline, texture.width, texture.height);
								break;
							}
						}
						if(rect){
							//trace("rect: "+_textureIndex+" "+rect,_textureWidth,_textureHeight);
							
							// sanity check
							for each(list in _baselineMap){
								for each(othRect in list){
									if(othRect.intersects(rect)){
										trace("OOPS, texture overlap");
									}
								}
							}
							
							_textureGraph[textureName] = rect;
							var newBaseline:Number = rect.bottom+texturePadding;
							if(_baseLines.indexOf(newBaseline)==-1){
								_baseLines.push(newBaseline);
								_baseLines = _baseLines.sort(Array.NUMERIC);
								_baselineMap[newBaseline] = new Vector.<Rectangle>();
							}
							_baselineMap[rect.top].push(rect);
						}else{
							if(_textureWidth<=_textureHeight){
								_textureWidth = getNearest2N(_textureWidth+1);
							}else{
								_textureHeight = getNearest2N(_textureHeight+1);
							}
							//trace("expand: ",_textureWidth,_textureHeight);
						}
					}while(!rect)
				}
				
				
				++_textureIndex;
			}while(getTimer() < start + timeAlloc);
		}
		
		private var _bundleIndex:int = 0;
		public function xmlBuild(timeAlloc:int):void{
			var start:int = getTimer();
			do{
				if(_bundleIndex==_allBundles.length){
					_xmlDataProxy.textureAtlasXML = _textureXml;
					_xmlDataProxy.xml = _dbXml;
					ImportDataProxy.getInstance().setData(_xmlDataProxy,null,textureImage,false);
					_exportCommand.export(1, 1, 0);
					setState(STATE_DONE);
					return;
				}
				
				var bundle:ChunkBundle = _allBundles[_bundleIndex];
				
				var parentBundle:ChunkBundle = _chunkToBundle[bundle.chunk.parent];
				if(bundle.chunk.children.length){
					var name:String = bundle.id+"_back";
					var armXml:XML = <armature name={bundle.id}><skin name=""/><animation name="loop" fadeInTime="0" duration={_videoPacker.bitmaps.length} scale="1" loop="0" tweenEasing="0"/></armature>;
					addFramesToArm(name, bundle.frameNames, bundle.frames, bundle.frameRefs, armXml, 0, 0);
					bundle.armatureXml = armXml;
					
					if(parentBundle){
						var instXml:XML = 	<slot name={bundle.id} parent={bundle.id} z="1">
												<display name={name} type="armature">
													<transform x="0" y="0" skX="0" skY="0" scX="1" scY="1"/>
												</display>
											</slot>
						parentBundle.armatureXml.appendChild(instXml);
					}
					_dbXml.appendChild(armXml);
				}else{
					addFramesToArm(bundle.id, bundle.frameNames, bundle.frames, bundle.frameRefs, armXml, bundle.chunk.x, bundle.chunk.y);
					
				}
				
				
				++_bundleIndex;
			}while(getTimer() < start + timeAlloc);
		}
		
		private function createId(chunk:VideoPackerChunk):String
		{
			var parent:VideoPackerChunk = chunk.parent;
			if(parent){
				return createId(parent)+"."+parent.children.indexOf(chunk);
			}else{
				return "Video";
			}
		}
		
		private function addFramesToArm(name:String, frameNames:Vector.<String>, frames:Vector.<BitmapData>, frameRefs:Vector.<int>, armXml:XML, x:Number, y:Number):void
		{
			var width:int = frames[0].width;
			var height:int = frames[0].height;
			var boneXml:XML = <bone name={name}>
							   	<transform x={x + width/2} y={y + height/2} skX="0" skY="0" scX="1" scY="1"/>
							  </bone>;
			
			var i:int;
			var slotXml:XML = <slot name={name} parent={name} z="0"/>;
			for(i=0; i<frameNames.length; ++i){
				var frameName:String = frameNames[i];
				var frame:BitmapData = frames[i];
				var displayXml:XML = <display name={frameName} type="image">
									 <transform x={-frame.width/2} y={-frame.height/2} skX="0" skY="0" scX="1" scY="1" pX="0" pY="0"/>
									</display>;
				slotXml.appendChild(displayXml);
			}
			
			var timelineXml:XML = <timeline name={name} scale="1" offset="0"/>;
			var lastRef:int = -1;
			var lastFrameNode:XML
			for(i=0; i<frameRefs.length; ++i){
				var frameRef:int = frameRefs[i];
				if(frameRef==lastRef){
					lastFrameNode.@duration = parseInt(lastFrameNode.@duration) +1;
				}else{
					lastFrameNode = <frame z="0" duration="1">
								     	<transform x={x + width/2} y={y + height/2} skX="0" skY="0" scX="1" scY="1" pX="0" pY="0"/>
									</frame>;
					timelineXml.appendChild(lastFrameNode);
					lastRef = frameRef;
					if(frameRef){
						lastFrameNode.@displayIndex = frameRef; // defaults to 0
					}
				}
			}
			
			armXml.appendChild(boneXml);
			armXml.skin.appendChild(slotXml);
			armXml.animation.appendChild(timelineXml);
		}
		
		private function getColorAverageFract(data:BitmapData):Number {
			var color:uint;
			var alpha:uint = 0;
			var red:uint = 0;
			var green:uint = 0;
			var blue:uint = 0;
			var div:uint = data.width * data.height * 0xff;
			
			for (var i:uint = 0; i < data.width; i++) {
				for (var j:uint = 0; j < data.height; j++) {
					color = data.getPixel32(i, j);
					if(color==0)continue;
					
					var a:uint = (color >> 24) & 0xff;
					var r:uint = (color >> 16) & 0xff;
					var g:uint = (color >>  8) & 0xff;
					var b:uint = (color      ) & 0xff;
					if(a==0xff){
						a += (r + g + b) / 3;
					}else{
						alpha += a;
					}
					red += (color >> 16) & 0xff;
					green += (color >> 8) & 0xff;
					blue += color & 0xff;
				}
			}
			return ((alpha/div) + (red/div) + (green/div) + (blue/div)) / 4;
		}
		private function getNearest2N(_n:uint):uint
		{
			return _n & _n - 1?1 << _n.toString(2).length:_n;
		}
	}
}
import flash.display.BitmapData;

import org.tbyrne.videoPacker.VideoPackerChunk;

class ChunkBundle{
	public var id:String;
	public var armatureXml:XML;
	public var frames:Vector.<BitmapData>;
	public var frameNames:Vector.<String>;
	public var frameRefs:Vector.<int>;
	public var chunk:VideoPackerChunk;
	
	public function ChunkBundle(){
		frames = new Vector.<BitmapData>();
		frameNames = new Vector.<String>();
		frameRefs = new Vector.<int>();
	}
}