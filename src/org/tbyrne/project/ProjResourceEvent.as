package org.tbyrne.project
{
	import flash.events.Event;
	
	public class ProjResourceEvent extends Event
	{
		public static const PROJECT_RESOURCES_LOADED:String = "projectResourcesLoaded";
		
		public function ProjResourceEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		override public function clone():Event{
			return new ProjResourceEvent(type, bubbles, cancelable);
		}
	}
}