package org.tbyrne
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.net.URLRequest;
	
	import org.tbyrne.project.ProjResourceEvent;
	import org.tbyrne.project.ProjectResource;
	import org.tbyrne.videoPacker.VideoPacker;

	public class ResourceLoader extends StateObject
	{
		public static const STATE_WAITING:String = "waiting";
		public static const STATE_LOADING:String = "loading";
		public static const STATE_LOADED:String = "loaded";
		
		
		public function get bitmaps():Vector.<BitmapData>{
			return Vector.<BitmapData>(_bitmaps);
		}
		
		private var _loaded:int = 0;
		private var _resources:Vector.<ProjectResource>;
		private var _loading:Vector.<Loader>;
		private var _bitmaps:Array; // is array so it can have gaps
		
		
		public function ResourceLoader()
		{
			super();
			setState(STATE_WAITING);
		}
		
		public function setResources(resources:Vector.<ProjectResource>):void{
			_resources = resources;
			_bitmaps = null;
			setState(STATE_WAITING);
		}
		public function beginLoad():void{
			_loading = new Vector.<Loader>();
			_bitmaps = [];
			loadFrom(_resources);
		}
		
		private function loadFrom(resources:Vector.<ProjectResource>):void
		{
			for(var i:int=0; i<resources.length; ++i){
				var resource:ProjectResource = resources[i];
				
				if(resource.filepath && resource.type!=ProjectResourceTypes.IMAGE_SEQUENCE){
					var loader : Loader = new Loader();
					loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadComplete);
					_loading.push(loader);
				
					loader.load(new URLRequest(resource.filepath));
				}
				
				if(resource.childResources)loadFrom(resource.childResources);
			}
		}
		
		private function onLoadComplete(event : Event) : void {
			++_loaded;
			var loader:Loader = (event.target as LoaderInfo).loader;
			loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onLoadComplete);
			
			var index:int = _loading.indexOf(loader);
			_bitmaps[index] = (loader.content as Bitmap).bitmapData;
			
			if(_loaded==_loading.length){
				_loading = null;
				dispatchEvent(new ProjResourceEvent(ProjResourceEvent.PROJECT_RESOURCES_LOADED));
			}
		}
	}
}