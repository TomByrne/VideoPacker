package org.tbyrne.adaptors
{
	import mx.collections.ArrayCollection;
	import mx.collections.ICollectionView;
	import mx.controls.treeClasses.ITreeDataDescriptor;
	
	import org.tbyrne.ProjectResourceTypes;
	import org.tbyrne.project.ProjectResource;
	
	import org.tbyrne.utils.vectorToArray;
	
	public class ResourceTreeDescriptor implements ITreeDataDescriptor
	{
		public function ResourceTreeDescriptor()
		{
		}
		
		public function getChildren(node:Object, model:Object=null):ICollectionView
		{
			var resource:ProjectResource = (node as ProjectResource);
			return new ArrayCollection(vectorToArray(resource.childResources));
		}
		
		public function hasChildren(node:Object, model:Object=null):Boolean
		{
			var resource:ProjectResource = (node as ProjectResource);
			return resource.childResources && resource.childResources.length;
		}
		
		public function isBranch(node:Object, model:Object=null):Boolean
		{
			var resource:ProjectResource = (node as ProjectResource);
			return resource.childResources || resource.type==ProjectResourceTypes.IMAGE_SEQUENCE;
		}
		
		public function getData(node:Object, model:Object=null):Object
		{
			var resource:ProjectResource = (node as ProjectResource);
			return {label:node.label, active:(resource.type!=ProjectResourceTypes.IMAGE)};
		}
		
		public function addChildAt(parent:Object, newChild:Object, index:int, model:Object=null):Boolean
		{
			return false;
		}
		
		public function removeChildAt(parent:Object, child:Object, index:int, model:Object=null):Boolean
		{
			return false;
		}
	}
}