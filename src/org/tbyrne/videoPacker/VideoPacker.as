package org.tbyrne.videoPacker {
	import org.tbyrne.StateObject;
	import flash.display.BitmapData;
	
	
	
	public class VideoPacker extends StateObject {
		
		public static const STATE_PROCESSING:String = "processing";
		public static const STATE_DONE:String = "done";
		
		
		
		
		public var bitmaps:Vector.<BitmapData>;
		public var rootChunk:VideoPackerChunk;
		
		private var currentChunk:VideoPackerChunk;
		
		public function VideoPacker(){
			
		}
	
		public function begin(bitmaps:Vector.<BitmapData>):void{
			var firstImage:BitmapData = bitmaps[0];
			this.bitmaps = bitmaps;
			rootChunk = new VideoPackerChunk(0,0,firstImage.width, firstImage.height, bitmaps);
			currentChunk = rootChunk;
			setState(STATE_PROCESSING);
		}
		
		public function process(timeAlloc:int):void{
			if(!currentChunk)return;
			
			switch(currentChunk.state){
				case VideoPackerChunk.STATE_DIFF_CHECK:
					currentChunk.diffCheck(timeAlloc);
					break;
                    
                case VideoPackerChunk.STATE_BOX_CHECK:
					currentChunk.boxCheck(timeAlloc);
					break;
                    
                case VideoPackerChunk.STATE_BOX_COMBINING:
					currentChunk.boxCombine(timeAlloc);
					break;
                    
                case VideoPackerChunk.STATE_ADDING_CHILDREN:
					currentChunk.addChildren(timeAlloc);
					break;
					
				/*case VideoPackerChunk.STATE_PARTICLE_CHECK:
					currentChunk.particleCheck(timeAlloc);
					break;*/
			}
			if(currentChunk.state==VideoPackerChunk.STATE_DONE){
				if(currentChunk.children.length){
					currentChunk = currentChunk.children[0];
				}else if(currentChunk.parent){
					var siblings:Vector.<VideoPackerChunk> = currentChunk.parent.children;
					var index:int;
					while((index = siblings.indexOf(currentChunk))==siblings.length-1){
						currentChunk = currentChunk.parent;
						if(!currentChunk){
							currentChunk = null;
							siblings = null;
							break;
						}
						siblings = currentChunk.parent.children;
					}
					if(siblings){
						currentChunk = siblings[index+1];
					}
				}else{
					currentChunk = null;
				}
				setState(STATE_DONE);
			}
		}
	}
}