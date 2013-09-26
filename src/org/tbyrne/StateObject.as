package org.tbyrne {
	import flash.events.Event;
	import flash.events.EventDispatcher;
	/**
	 * @author admin
	 */
	public class StateObject extends EventDispatcher implements IStateObject{
		
		private var _state : String;
		
		public function get state():String{
			return _state;
		}
		
		public function StateObject(){
			
		}
		
		protected function setState(state:String):void{
			if(_state==state)return;
			
			_state = state;
			dispatchEvent(new Event(Event.CHANGE));
		}
	}
}
