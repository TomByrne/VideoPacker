package org.tbyrne.utils
{
	public function vectorToArray(v:Object): Array
	{
		var len:int = v.length;
		var ret:Array = new Array(len);
		for (var i:int = 0; i < len; ++i)
		{
			ret[i] = v[i];
		}
		return ret;
	}
}