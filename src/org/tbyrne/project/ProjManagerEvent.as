package org.tbyrne.project
{
	import flash.events.Event;
	
	public class ProjManagerEvent extends Event
	{
		public static const CURRENT_PROJECT_CHANGED:String = "currentProjectChanged";
		public static const OPEN_PROJECTS_CHANGED:String = "openProjectsChanged";
		
		public function ProjManagerEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
		override public function clone():Event{
			return new ProjManagerEvent(type, bubbles, cancelable);
		}
	}
}