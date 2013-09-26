package org.tbyrne.project
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	import mx.events.FileEvent;
	
	import org.tbyrne.ProjectResourceTypes;
	import org.tbyrne.ResourceLoader;
	import org.tbyrne.StateObject;

	public class Project extends StateObject
	{
		public static const STATE_UNSAVED:String = "unsaved";
		public static const STATE_SAVED:String = "saved";
		public static const STATE_LOADING:String = "loading";
		public static const STATE_SAVING:String = "saving";
		public static const STATE_CHANGES_PENDING:String = "changesPending";
		
		public var saveFile:File;
		
		private var _data:ProjectData;
		private var _loader:ResourceLoader;
		
		public function get label():String{
			return saveFile?saveFile.name+(state==STATE_CHANGES_PENDING?"*":""):"<Unsaved>";
		}
		public function get exportType():String{
			return _data.exportType;
		}
		public function set exportType(value:String):void{
			if(_data.exportType==value)return;
			
			_data.exportType = value;
			if(saveFile)setState(STATE_CHANGES_PENDING);
		}
		public function get loader():ResourceLoader{
			return _loader;
		}
		public function get resources():Vector.<ProjectResource>{
			return _data.resources;
		}
		
		public function Project()
		{
			_data = new ProjectData();
			_loader = new ResourceLoader();
			_loader.setResources(_data.resources);
			setState(STATE_UNSAVED);
		}
		
		public function getExportSetting(name:String):*{
			return _data.exportVariables[name];
		}
		public function setExportSetting(name:String, value:*):void{
			var existing:* = _data.exportVariables[name];
			if(existing==value)return;
			
			_data.exportVariables[name] = value;
			if(saveFile)setState(STATE_CHANGES_PENDING);
			dispatchEvent(new ProjectEvent(ProjectEvent.EXPORT_SETTINGS_CHANGED));
		}
		
		public function addResource(resource:ProjectResource):void{
			if(_data.resources.indexOf(resource)!=-1)return;
			
			removeByPath(resource.filepath);
			_data.resources.push(resource);
			if(saveFile)setState(STATE_CHANGES_PENDING);
			dispatchEvent(new ProjectEvent(ProjectEvent.PROJECT_RESOURCES_CHANGED));
		}
		
		private function removeByPath(filepath:String):void
		{
			for(var i:int=0; i<_data.resources.length; ++i){
				var existing:ProjectResource = _data.resources[i];
				if(existing.filepath==filepath){
					_data.resources.splice(i,1);
				}
			}
		}
		
		public function addResources(resources:Vector.<ProjectResource>):void
		{
			for each(var resource:ProjectResource in resources){
				if(_data.resources.indexOf(resource)!=-1)continue;
				removeByPath(resource.filepath);
				_data.resources.push(resource);
			}
			if(saveFile)setState(STATE_CHANGES_PENDING);
			dispatchEvent(new ProjectEvent(ProjectEvent.PROJECT_RESOURCES_CHANGED));
		}
		
		public function removeResource(resource:ProjectResource):void{
			var index:int = _data.resources.indexOf(resource);
			if(index==-1)return;
			
			_data.resources.splice(index, 1);
			if(saveFile)setState(STATE_CHANGES_PENDING);
			dispatchEvent(new ProjectEvent(ProjectEvent.PROJECT_RESOURCES_CHANGED));
		}
		
		public function save():void
		{
			if(state==Project.STATE_SAVED)return;
			if(!saveFile){
				throw new Error("No save file set, use saveAs");
			}
			doSave();
		}
		
		public function saveAs():void
		{
			var byteArray:ByteArray = new ByteArray();
			byteArray.writeObject(_data);
			
			var file:File = new File();
			file.addEventListener(Event.COMPLETE, onSaveComplete);
			file.addEventListener(Event.CANCEL, onSaveCancel);
			file.save(byteArray, saveFile?saveFile.name:"Project.vpp");
		}
		
		protected function onSaveComplete(event:Event):void
		{
			var file:File = event.target as File;
			file.removeEventListener(Event.COMPLETE, onSaveComplete);
			file.removeEventListener(Event.CANCEL, onSaveCancel);
			
			saveFile = file;
			setState(STATE_SAVED);
		}
		protected function onSaveCancel(event:Event):void
		{
			var file:File = event.target as File;
			file.removeEventListener(Event.COMPLETE, onSaveComplete);
			file.removeEventListener(Event.CANCEL, onSaveCancel);
		}
		
		private function doSave():void
		{
			setState(STATE_SAVING);
			var fs:FileStream = new FileStream();
			fs.openAsync(saveFile, FileMode.WRITE);
			fs.addEventListener(Event.COMPLETE, onFileWritten);
			fs.addEventListener(IOErrorEvent.IO_ERROR, onWriteError);
			fs.writeObject(_data);
		}
		
		protected function onWriteError(event:IOErrorEvent):void
		{
			var fs:FileStream = (event.target as FileStream);
			fs.removeEventListener(Event.COMPLETE, onFileWritten);
			fs.removeEventListener(IOErrorEvent.IO_ERROR, onWriteError);
			throw new Error("Error saving file");
		}
		
		protected function onFileWritten(event:Event):void
		{
			var fs:FileStream = (event.target as FileStream);
			fs.removeEventListener(Event.COMPLETE, onFileWritten);
			fs.removeEventListener(IOErrorEvent.IO_ERROR, onWriteError);
			setState(STATE_SAVED);
		}
		
		public function revert():void
		{
			if(!saveFile){
				throw new Error("Cannot revert unsaved file");
			}
			open(saveFile);
		}
		public function open(file:File):void
		{
			saveFile = file;
			setState(STATE_LOADING);
			
			var fs:FileStream = new FileStream();
			fs.addEventListener(Event.COMPLETE, onFileRead);
			fs.addEventListener(IOErrorEvent.IO_ERROR, onReadError);
			var bytes:ByteArray = new ByteArray();
			
			fs.openAsync(file, FileMode.READ);
		}
		
		protected function onFileRead(event:Event):void
		{
			var fs:FileStream = (event.target as FileStream);
			fs.removeEventListener(Event.COMPLETE, onFileRead);
			fs.removeEventListener(IOErrorEvent.IO_ERROR, onReadError);
			var data:ProjectData = fs.readObject() as ProjectData;
			if(data){
				_data = data;
				_loader.setResources(_data.resources);
				linkResources(data.resources);
				dispatchEvent(new ProjectEvent(ProjectEvent.EXPORT_SETTINGS_CHANGED));
				dispatchEvent(new ProjectEvent(ProjectEvent.PROJECT_RESOURCES_CHANGED));
				setState(STATE_SAVED);
			}
		}
		
		private function linkResources(resources:Vector.<ProjectResource>):void
		{
			var i:int=0;
			while(i<resources.length){
				var resource:ProjectResource = resources[i];
				if(resource.filepath){
					resource.setFile(new File(resource.filepath));
					if(resource.childResources)linkResources(resource.childResources);
					++i;
				}else if(resource.type!=ProjectResourceTypes.IMAGE_SEQUENCE){
					resources.splice(i,1);
				}
			}
		}
		
		protected function onReadError(event:IOErrorEvent):void
		{
			var fs:FileStream = (event.target as FileStream);
			fs.removeEventListener(Event.COMPLETE, onFileRead);
			fs.removeEventListener(IOErrorEvent.IO_ERROR, onReadError);
		}
	}
}