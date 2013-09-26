package org.tbyrne.project
{
	import flash.events.Event;
	
	public class ProjectEvent extends Event
	{
		public static const EXPORT_TYPE_CHANGED:String = "exportTypeChanged";
		public static const EXPORT_SETTINGS_CHANGED:String = "exportSettingsChanged";
		public static const PROJECT_RESOURCES_CHANGED:String = "projectResourcesChanged";
		
		public function ProjectEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		override public function clone():Event{
			return new ProjectEvent(type, bubbles, cancelable);
		}
	}
}