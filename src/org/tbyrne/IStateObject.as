package org.tbyrne
{
	import flash.events.IEventDispatcher;

	public interface IStateObject extends IEventDispatcher
	{
		function get state():String;
	}
}