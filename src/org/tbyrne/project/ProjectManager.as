package org.tbyrne.project
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.filesystem.File;
	import flash.net.FileFilter;
	import flash.net.SharedObject;

	public class ProjectManager extends EventDispatcher
	{
		public static const PROJECT_FILE_TYPE:FileFilter = new FileFilter("Video Packer Project (*.vpp)", "*.vpp");
		
		
		public function get openProjects():Vector.<Project>{
			return _openProjects;
		}
		public function get openProjectsArr():Array{
			return _openProjectsArr;
		}
		public function get currentProject():Project{
			return _currentProject;
		}
		public function get currentIndex():int{
			return _openProjects.indexOf(_currentProject);
		}
		
		private var _openProjects:Vector.<Project>;
		private var _openProjectsArr:Array;
		private var _currentProject:Project;
		private var _settings:SharedObject;
		
		public function ProjectManager()
		{
			_openProjects = new Vector.<Project>();
			_openProjectsArr = [];
			_settings = SharedObject.getLocal("project");
			
			if(_settings.data.openProjects){
				var refs = _settings.data.openProjects;
				for(var i:int=0; i<refs.length; ++i){
					var projectRef:String = refs[i];
					var file:File = new File(projectRef);
					if(file.exists)doOpenProject(file, _settings.data.currentIndex==i);
				}
			}else{
				_settings.data.openProjects = [];
			}
		}
		
		public function createNew(setCurrent:Boolean=true):Project{
			var newProject:Project = new Project();
			_openProjects.push(newProject);
			_openProjectsArr.push(newProject);
			dispatchEvent(new ProjManagerEvent(ProjManagerEvent.OPEN_PROJECTS_CHANGED));
			
			newProject.addEventListener(Event.CHANGE, onProjStateChange);
			
			if(setCurrent)setCurrentProject(newProject);
			
			return newProject;
		}
		
		private function setCurrentProject(newProject:Project):void
		{
			if(_currentProject==newProject)return;
			
			if(_currentProject){
				_currentProject.removeEventListener(Event.CHANGE, onForwardEvent);
				_currentProject.removeEventListener(ProjectEvent.EXPORT_SETTINGS_CHANGED, onForwardEvent);
				_currentProject.removeEventListener(ProjectEvent.EXPORT_TYPE_CHANGED, onForwardEvent);
				_currentProject.removeEventListener(ProjectEvent.PROJECT_RESOURCES_CHANGED, onForwardEvent);
				
				_currentProject.loader.removeEventListener(ProjResourceEvent.PROJECT_RESOURCES_LOADED, onForwardEvent);
			}
			_currentProject = newProject;
			if(_currentProject){
				_currentProject.addEventListener(Event.CHANGE, onForwardEvent);
				_currentProject.addEventListener(ProjectEvent.EXPORT_SETTINGS_CHANGED, onForwardEvent);
				_currentProject.addEventListener(ProjectEvent.EXPORT_TYPE_CHANGED, onForwardEvent);
				_currentProject.addEventListener(ProjectEvent.PROJECT_RESOURCES_CHANGED, onForwardEvent);
				
				_currentProject.loader.addEventListener(ProjResourceEvent.PROJECT_RESOURCES_LOADED, onForwardEvent);
				
				// dispatch change events for project
				dispatchEvent(new Event(Event.CHANGE));
				dispatchEvent(new ProjectEvent(ProjectEvent.EXPORT_SETTINGS_CHANGED));
				dispatchEvent(new ProjectEvent(ProjectEvent.EXPORT_TYPE_CHANGED));
				dispatchEvent(new ProjectEvent(ProjectEvent.PROJECT_RESOURCES_CHANGED));
				
				_settings.data.currentIndex = _openProjects.indexOf(_currentProject);
			}else{
				_settings.data.currentIndex = -1;
			}
			dispatchEvent(new ProjManagerEvent(ProjManagerEvent.CURRENT_PROJECT_CHANGED));
		}
		
		protected function onForwardEvent(event:Event):void
		{
			dispatchEvent(event);
		}
		
		public function openProject():void{
			var file:File = new File();
			file.addEventListener(Event.SELECT, onOpenComplete);
			file.addEventListener(Event.CANCEL, onOpenCancel);
			file.browseForOpen("Open Project", [ProjectManager.PROJECT_FILE_TYPE]);
			
		}
		
		protected function onOpenComplete(event:Event):void
		{
			var file:File = event.target as File;
			file.removeEventListener(Event.SELECT, onOpenComplete);
			file.removeEventListener(Event.CANCEL, onOpenCancel);
			
			var project:Project;
			for each(project in _openProjects){
				if(project.saveFile && project.saveFile.nativePath==file.nativePath){
					setCurrentProject(project);
					return;
				}
			}
			
			doOpenProject(file, true);
		}
		
		private function doOpenProject(file:File, setCurrent:Boolean=false):Project
		{
			var project:Project = createNew(false);
			project.open(file);
			if(setCurrent)setCurrentProject(project);
			return project;
		}
		protected function onOpenCancel(event:Event):void
		{
			var file:File = event.target as File;
			file.removeEventListener(Event.SELECT, onOpenComplete);
			file.removeEventListener(Event.CANCEL, onOpenCancel);
		}
		
		public function saveCurrent():void{
			if(!_currentProject)return;
			
			_currentProject.save();
		}
		
		public function saveCurrentAs():void
		{
			if(!_currentProject)return;
			
			_currentProject.saveAs();
		}
		
		public function closeCurrent():void{
			if(!_openProjects.length)return;
			
			_currentProject.removeEventListener(Event.CHANGE, onProjStateChange);
			
			var index:int = _openProjects.indexOf(_currentProject);
			_openProjects.splice(index, 1);
			_openProjectsArr.splice(index, 1);
			dispatchEvent(new ProjManagerEvent(ProjManagerEvent.OPEN_PROJECTS_CHANGED));
			selectProject(index==0?0:index-1);
			
			saveOpenProjects();
		}
		
		protected function onProjStateChange(event:Event):void
		{
			var proj:Project = event.target as Project;
			if(proj.state==Project.STATE_SAVED)saveOpenProjects();
		}
		
		private function saveOpenProjects():void{
			var openRefs:Array = [];
			for each(var proj:Project in _openProjects){
				if(proj.saveFile)openRefs.push(proj.saveFile.nativePath);
			}
			_settings.data.openProjects = openRefs;
		}
		
		public function selectNext():Project{
			var index:int = _openProjects.indexOf(_currentProject);
			return selectProject(index+1);
		}
		
		public function selectPrev():Project{
			var index:int = _openProjects.indexOf(_currentProject);
			return selectProject(index-1);
		}
		
		public function selectProject(index:int):Project
		{
			if(_openProjects.length){
				while(index<0)index += _openProjects.length;
				index %= _openProjects.length;
				
				setCurrentProject(_openProjects[index]);
			}else{
				setCurrentProject(null);
			}
			return _currentProject;
		}
		
		public function loadResources():void
		{
			_currentProject.loader.beginLoad();
		}
	}
}