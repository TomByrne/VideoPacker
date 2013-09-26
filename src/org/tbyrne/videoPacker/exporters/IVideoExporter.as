package org.tbyrne.videoPacker.exporters
{
	import org.tbyrne.videoPacker.VideoPacker;

	public interface IVideoExporter
	{
		function setVideoPacker(videoPacker:VideoPacker):void;
		function process(timeAlloc:int):void;
	}
}