package it.soloict
{
	import com.demonsters.debugger.MonsterDebugger;
	
	import flash.events.ContextMenuEvent;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.utils.Dictionary;
	
	import mx.resources.ResourceBundle;
	import mx.resources.IResourceBundle;
	import mx.resources.ResourceManager;
	
	import spark.components.Application;
	
	[ResourceBundle("VersionControl")]
	public class VersionControl
	{
		private var _app:Application = null;
		private var _rbi:Dictionary;
		
		public function VersionControl(lock:Class)
		{
			if(lock != SingletonLock) throw new Error("This class cannot be instantiated, it is a singleton!");
		}
		
		private function _doWork():void
		{
			var rb:IResourceBundle  = ResourceManager.getInstance().getResourceBundle("en_US", "VersionControl");
			
			_rbi = new Dictionary( );
			var rbi:Object = rb.content;
			var cm : ContextMenu = new ContextMenu( );
			for( var i : String in rbi )
			{
				var properties     : Array = String( rbi[ i ] ).split( '&' );
				var value         : String = properties[ 0 ];
				var separator     : Boolean = properties[ 1 ] ? properties[ 1 ] == 'false' ? false : true : true;
				var enabled        : Boolean = properties[ 2 ] ? properties[ 2 ] == 'false' ? false : true : true;
				var visible        : Boolean = properties[ 3 ] ? properties[ 3 ] == 'false' ? false : true : true;
				var open        : Boolean = properties[ 4 ] ? properties[ 4 ] == 'false' ? false : true : true;
				var cmi : ContextMenuItem = new ContextMenuItem( value, separator, enabled, visible );
				cm.customItems.push( cmi ); 
				cm.hideBuiltInItems( );            
				if( open )
				{
					cmi.addEventListener( ContextMenuEvent.MENU_ITEM_SELECT, openWindow );
					_rbi[ value ] = properties[ 4 ] ? properties[ 4 ] : '';            
				}
			}
			_app.contextMenu = cm;
		}
		
		private function openWindow( e : ContextMenuEvent ) : void
		{
			navigateToURL( new URLRequest( _rbi[ e.target.caption ] ), "_blank" );
		}
		
		private static var _instance:VersionControl;
		
		public static function getInstance(app:Application):VersionControl{
			if(app == null) throw new Error("Application parameter must be not null");
			if(_instance == null) _instance = new VersionControl(SingletonLock);
			_instance._app = app;
			_instance._doWork();
			return _instance;
		}
	}
}
class SingletonLock{}
