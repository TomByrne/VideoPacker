package org.tbyrne.project
{
	import flash.net.registerClassAlias;
	import flash.utils.Dictionary;

	public class ProjectData
	{
		{
			registerClassAlias("ProjectData", ProjectData);
		}
		
		public var exportType:String;
		public var resources:Vector.<ProjectResource>;
		public var exportVariables:Dictionary;
		
		public function ProjectData()
		{
			resources = new Vector.<ProjectResource>();
			exportVariables = new Dictionary();
		}
	}
}