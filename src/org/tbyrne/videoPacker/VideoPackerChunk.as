package org.tbyrne.videoPacker {
	/**
	 * @author admin
	 */
	import flash.filters.BlurFilter;
	import flash.geom.Rectangle;
	import flash.filters.ColorMatrixFilter;
	import flash.display.BlendMode;
	import org.tbyrne.StateObject;
	import flash.utils.getTimer;
	import flash.display.BitmapData;
	import flash.utils.Dictionary;
	import flash.geom.Point;
	import com.hangunsworld.util.BMPFunctions;
	
	
	public class VideoPackerChunk extends StateObject{
		public static const STATE_DIFF_CHECK:String = "diffCheck";
		//public static const STATE_PARTICLE_CHECK:String = "particleCheck";;
		public static const STATE_BOX_CHECK:String = "boxCheck";
		public static const STATE_BOX_COMBINING:String = "boxCombining";
		public static const STATE_ADDING_CHILDREN:String = "addingChildren";
		public static const STATE_DONE:String = "done";
		
		public static const DEFAULT_PADDING:int = 2;
		public static const DEFAULT_COMBINE_THRESHOLD:Number = 0.2;
		
		public var x : Number;
		public var y : Number;
		public var width:Number;
		public var height:Number;
		
		private var _contrastFilter:ColorMatrixFilter;
		private var _bitmaps:Vector.<BitmapData>;
		public var diffFrames:Vector.<BitmapData>;
		public var particleData:Dictionary;
		public var firstImage:BitmapData;
		public var sameImage:BitmapData;
		public var darkDiff:BitmapData;
		public var lightDiff:BitmapData;
		public var initialBlobs:Vector.<Rectangle>;
		public var blobs:Vector.<Rectangle>;
		
		public var children:Vector.<VideoPackerChunk>;
		
		public var padding:int = DEFAULT_PADDING;
		public var combineThreshold:Number = DEFAULT_COMBINE_THRESHOLD;
		
		public var parent:VideoPackerChunk;
		
		private var _rect : Rectangle;
		
		
		public function VideoPackerChunk(x:Number, y:Number, width:Number, height:Number, bitmaps:Vector.<BitmapData>){
			this.x = x;
			this.y = y;
			this.width = width;
			this.height = height;
			_bitmaps = bitmaps;
			
			initialBlobs = new Vector.<Rectangle>();
			children = new Vector.<VideoPackerChunk>();
			
			_rect = new Rectangle(0,0,width, height);
			
			firstImage = _bitmaps[0];
			sameImage = new BitmapData(width, height, false, 0);
	        
	        darkDiff = new BitmapData(width, height, false, 0);
	        darkDiff.draw(firstImage);
	        
	        lightDiff = new BitmapData(width, height, false, 0xffffff);
	        lightDiff.draw(firstImage);
			
			diffFrames = new Vector.<BitmapData>();
			
			setState(STATE_DIFF_CHECK);
			
			_contrastFilter = new ColorMatrixFilter();
			_contrastFilter.matrix = [1,1,1,0,-0xf0, 1,1,1,0,-0xf0, 1,1,1,0,-0xf0, 0,0,0,1,0];
		}
		
		
		private var progF:int = 1;
		
		public function diffCheck(timeAlloc:int):void{
			var start:int = getTimer();
			do{
	            var image:BitmapData = _bitmaps[progF];
	        
		        var darkImage:BitmapData = new BitmapData(darkDiff.width, darkDiff.height, false, 0);
		        darkImage.draw(image);
				var darkDiffImage:BitmapData = darkDiff.clone();
				darkDiffImage.draw(darkImage, null, null, BlendMode.DIFFERENCE);
	        
		        var lightImage:BitmapData = new BitmapData(lightDiff.width, lightDiff.height, false, 0xffffff);
		        lightImage.draw(image);
				var lightDiffImage:BitmapData = lightDiff.clone();
				lightDiffImage.draw(lightImage, null, null, BlendMode.DIFFERENCE);
	            
	            // combine dark and light to get real diff
				lightDiffImage.draw(darkDiffImage, null, null, BlendMode.ADD);
				var realDiffImage:BitmapData = lightDiffImage;
	            
				diffFrames[progF-1] = realDiffImage;
				sameImage.draw(realDiffImage, null, null, BlendMode.ADD);
				
				++progF;
				if(progF==_bitmaps.length){
					sameImage.applyFilter(sameImage, _rect, new Point(), new BlurFilter(2,2,3));
					sameImage.applyFilter(sameImage, _rect, new Point(), _contrastFilter);
					progF = 0;
					particleData = new Dictionary();
					setState(STATE_BOX_CHECK);
					break;
				}
			}while(getTimer() < start + timeAlloc);
		}
		
	    private var progX:int = 0;
		private var progY:int = 0;
		public function boxCheck(timeAlloc:int):void{
			var start:int = getTimer();
			do{
	            var pixel:int = sameImage.getPixel(progX, progY);
	            
	            if((pixel & 0xFF) >= 0x50){
					sameImage.setPixel(progX, progY, 0xffffff);
					BMPFunctions.floodFill(sameImage, progX, progY, 0xff0000, 200, true);
					var bounds:Rectangle = sameImage.getColorBoundsRect(0xffffffff, 0xffff0000);
					
					bounds.left -= padding;
					bounds.right += padding;
					bounds.top -= padding;
					bounds.bottom += padding;
					
					var i:int=0;
					var doAdd:Boolean = true;
					while(i< initialBlobs.length){
						var otherBlob:Rectangle = initialBlobs[i];
						if(otherBlob.containsRect(bounds)){
							doAdd = false;
							break;
						}else if(otherBlob.intersects(bounds)){
							bounds.left = Math.min(otherBlob.left, bounds.left);
							bounds.right = Math.max(otherBlob.right, bounds.right);
							bounds.top = Math.min(otherBlob.top, bounds.top);
							bounds.bottom = Math.max(otherBlob.bottom, bounds.bottom);
							initialBlobs.splice(i,1);
						}else if(bounds.containsRect(otherBlob)){
							initialBlobs.splice(i,1);
						}else{
							++i;
						}
					}
					if(doAdd)initialBlobs.push(bounds);
					BMPFunctions.floodFill(sameImage, progX, progY, 0x000000, 0, true);
	            }
	            
	            if(progX==sameImage.width-1){
	                if(progY==sameImage.height-1){
						this.blobs = this.initialBlobs.concat();
	                    setState(STATE_BOX_COMBINING);
	                    break;
	                }else{
						++progY;
		                progX = 0;
	                }
	            }else{
					++progX;
	            }
			}while(getTimer() < start + timeAlloc);
		}
		
		private var progBox1:int = 0;
		private var progBox2:int = 1;
		public function boxCombine(timeAlloc:int):void{
			var start:int = getTimer();
			do{
				var mainBlob:Rectangle = blobs[progBox1];
				var compareBlob:Rectangle = blobs[progBox2];
				var oldArea:Number = (mainBlob.width*mainBlob.height)+(compareBlob.width*compareBlob.height);
				
				var newBox:Rectangle = mainBlob.union(compareBlob);
				var newArea:Number = (newBox.width*newBox.height);
				var dif:Number = newArea-oldArea;
				if(dif/oldArea<combineThreshold){
					blobs[progBox1] = newBox;
					blobs.splice(progBox2, 1);
					progBox2 = -1; // recompare to already checked
				}
	            
				++progBox2;
				if(progBox2==progBox1)++progBox2;
				
	            if(progBox2==blobs.length){
	                if(progBox1==blobs.length-1){
	                    setState(STATE_ADDING_CHILDREN);
	                    break;
	                }else{
						++progBox1;
		                progBox2 = 0;
	                }
	            }
			}while(getTimer() < start + timeAlloc);
		}
		
		private var _childIndex:int=0;
		public function addChildren(timeAlloc:int):void{
			var start:int = getTimer();
			do{
				if(_childIndex==blobs.length){
					setState(STATE_DONE);
					break;
				}
				var childBlob:Rectangle = blobs[_childIndex];
				var child:VideoPackerChunk = new VideoPackerChunk(childBlob.x, childBlob.y, childBlob.width, childBlob.height, _bitmaps);
				child.skipProcessing(); // temporary?
				children.push(child);
				child.parent = this;
				++_childIndex;
				
			}while(getTimer() < start + timeAlloc);
		}
		
		public function skipProcessing():void{
			setState(STATE_DONE);
		}
		
		/*private var progX:int = 0;
		private var progY:int = 0;
		public function particleCheck(timeAlloc:int):void{
			var start:int = getTimer();
			do{
				var frame:BitmapData = _bitmaps[progF];
				var mask:BitmapData = diffFrames[progF==0?0:progF-1];
				var offset:Point = (_movementData?_movementData[progF]:new Point());
				for(var i:int=0; i<PARTICLE_SIZE; ++i){
					for(var j:int=0; j<PARTICLE_SIZE; ++j){
						var particleKey:String = getParticleKey(offset.x + progX+i, offset.y + progY+j, PARTICLE_SIZE, PARTICLE_SIZE, frame, mask, 0x03);
						if(particleKey){
							var timePoint:TimePoint = new TimePoint(progX+i, progY+j, progF);
							var list:Vector.<TimePoint> = particleData[particleKey];
							if(!list){
								list = new Vector.<TimePoint>();
								particleData[particleKey] = list;
							}
							list.push(timePoint);
							if(list.length>1)trace("list: "+list.length);
						}
					}
				}
				
				progX += PARTICLE_SIZE;
				if(progX<=width-PARTICLE_SIZE)continue;
				
				progX = 0;
				progY += PARTICLE_SIZE;
				if(progY<=height-PARTICLE_SIZE)continue;
				
				++progF;
				if(progF==_bitmaps.length){
					
					setState(STATE_DONE);
					break;
				}
			}while(getTimer() < start + timeAlloc);
		}
		
		private function getParticleKey(x:Number, y:Number, w:Number, h:Number, bitmap:BitmapData, mask:BitmapData, tolerance:int):String{
			var ret:String = "";
			for(var i:int=0; i<w; ++i){
				for(var j:int=0; j<h; ++j){
					var maskVal:int = mask.getPixel(x, y) & 0xFF;
					if(maskVal<0x03){
						// pixel is in static area
						return null;
					}
					
					var color:uint = bitmap.getPixel32(x+i, y+j);
					var a:int = roundTo(( color >> 24 ) & 0xFF, tolerance);
					var r:int = roundTo(( color >> 16 ) & 0xFF, tolerance);
					var g:int = roundTo(( color >> 8 ) & 0xFF, tolerance);
					var b:int = roundTo(color & 0xFF, tolerance);
					
					ret += a.toString(16)+""+r.toString(16)+""+g.toString(16)+""+b.toString(16);
				}
			}
			return ret;
		}
		
		private function roundTo(val:Number, round:Number):Number{
			return int(val / round + 0.5) * round;
		}*/
	}
}


/*class TimePoint{
	
	public var x:int;
	public var y:int;
	public var frame:int;
	
	public function TimePoint(x:int, y:int, frame:int){
		this.x = x;
		this.y = y;
		this.frame = frame;
	}
}*/
