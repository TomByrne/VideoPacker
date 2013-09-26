package org.tbyrne.project
{
	import flash.filesystem.File;
	import flash.net.registerClassAlias;
	
	import org.tbyrne.ProjectResourceTypes;

	public class ProjectResource
	{
		{
			registerClassAlias("ProjectResource", ProjectResource);
		}
		
		public var type:String;
		public var filepath:String;
		public var childResources:Vector.<ProjectResource>;
		
		public function ProjectResource(type:String=null, file:File=null, childResources:Vector.<ProjectResource>=null)
		{
			this.type = type;
			this.childResources = childResources;
			setFile(file);
		}
		
		public function get label():String{
			switch(type){
				case ProjectResourceTypes.IMAGE:
					return "IMG: "+filepath;
				case ProjectResourceTypes.IMAGE_SEQUENCE:
					return "SEQUENCE: "+filepath+" ("+childResources.length+")";
			}
			return null;
		}
		
		// will not be serialised
		private var _file:File;
		public function setFile(file:File):void{
			_file = file;
			if(file)filepath = file.nativePath;
		}
		public function getFile():File{
			return _file;
		}
	}
}