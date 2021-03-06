			/*
				
			Written by:
			Dustin Andrew
			dustin@flash-dev.com
			www.flash-dev.com
			
			FileUpload
			
			Panel component for uploading files.
			(Icons from http://www.famfamfam.com)
			
			LAST UPDATED:
			12/15/06
			
			*/
			
			import com.demonsters.debugger.MonsterDebugger;
			
			import flash.events.*;
			import flash.external.*;
			import flash.net.*;
			
			import mx.controls.*;
			import mx.events.*;
			import mx.managers.*;
			import mx.resources.ResourceManager;
			import mx.utils.StringUtil;
			
			private var _strUploadUrl:String;
			private var _refAddFiles:FileReferenceList;	
			private var _refUploadFile:FileReference;
			private var _arrUploadFiles:Array;
			private var _numCurrentUpload:Number = 0;
			private var _uploadFieldName:String = 'file';	// Setting for the upload field name within a $_FILE request
			private var _uploadCompleteJSCallback:String = null;	// ExternalInterface JavaScript callback on upload complete
			
			[Bindable]
			public var skinClass:Class;
			
			// Getter & setter: _uploadCompleteJSCallback
			public function set uploadCompleteJSCallback(val:String):void {
				this._uploadCompleteJSCallback = val;
			}
			
			public function get uploadCompleteJSCallback():String {
				return this._uploadCompleteJSCallback;
			}
			// ------------------------------------------
			
			// Set method: uploadFieldName
			public function set uploadFieldName(val:String):void {
				if(val == null) return;
				this._uploadFieldName = val;
			}
			
			// Get method: uploadFieldName 
			public function get uploadFieldName():String{
				return this._uploadFieldName;
			}     
			
			// Set uploadUrl
			public function set uploadUrl(strUploadUrl:String):void {
				_strUploadUrl = strUploadUrl;
			}
			
			// Initalize
			private function initCom():void {
				_arrUploadFiles = new Array();				
				enableUI();
				uploadCheck();
				
				updateStatus(ResourceManager.getInstance().getString("Strings", "status_noselection"));
			}
			
			// Called to add file(s) for upload
			private function addFiles():void {
				_refAddFiles = new FileReferenceList();
				_refAddFiles.addEventListener(Event.SELECT, onSelectFile);
				_refAddFiles.browse();
			}
			
			// Called when a file is selected
			private function onSelectFile(event:Event):void {
				var arrFoundList:Array = new Array();
				// Get list of files from fileList, make list of files already on upload list
				for (var i:Number = 0; i < _arrUploadFiles.length; i++) {
					for (var j:Number = 0; j < _refAddFiles.fileList.length; j++) {
						if (_arrUploadFiles[i].name == _refAddFiles.fileList[j].name) {
							arrFoundList.push(_refAddFiles.fileList[j].name);
							_refAddFiles.fileList.splice(j, 1);
							j--;
						}
					}
				}
				if (_refAddFiles.fileList.length >= 1) {				
					for (var k:Number = 0; k < _refAddFiles.fileList.length; k++) {
						_arrUploadFiles.push({
							name:_refAddFiles.fileList[k].name,
							size:formatFileSize(_refAddFiles.fileList[k].size),
							file:_refAddFiles.fileList[k]});
					}
					listFiles.dataProvider = _arrUploadFiles;
					listFiles.selectedIndex = _arrUploadFiles.length - 1;
				}				
				if (arrFoundList.length >= 1) {
					Alert.show(
						StringUtil.substitute(ResourceManager.getInstance().getString("Strings", "alert_fileduplicate_text"), arrFoundList.join("\n• ")),
						ResourceManager.getInstance().getString("Strings", "alert_fileduplicate_title")
					);
				}
				updateProgBar();
				scrollFiles();
				uploadCheck();
				
				updateStatus( ResourceManager.getInstance().getString("Strings", "status_ready") );
			}
			
			// Called to format number to file size
			private function formatFileSize(numSize:Number):String {
				var strReturn:String;
				numSize = Number(numSize / 1000);
				strReturn = String(numSize.toFixed(1) + " KB");
				if (numSize > 1000) {
					numSize = numSize / 1000;
					strReturn = String(numSize.toFixed(1) + " MB");
					if (numSize > 1000) {
						numSize = numSize / 1000;
						strReturn = String(numSize.toFixed(1) + " GB");
					}
				}				
				return strReturn;
			}
			
			// Called to remove selected file(s) for upload
			private function removeFiles():void {
				var arrSelected:Array = listFiles.selectedIndices;
				if (arrSelected.length >= 1) {
					for (var i:Number = 0; i < arrSelected.length; i++) {
						_arrUploadFiles[Number(arrSelected[i])] = null;
					}
					for (var j:Number = 0; j < _arrUploadFiles.length; j++) {
						if (_arrUploadFiles[j] == null) {
							_arrUploadFiles.splice(j, 1);
							j--;
						}
					}
					listFiles.dataProvider = _arrUploadFiles;
					listFiles.selectedIndex = 0;					
				}
				updateProgBar();
				scrollFiles();
				uploadCheck();
			}
			
			// Called to check if there is at least one file to upload
			private function uploadCheck():void {
				if (_arrUploadFiles.length == 0) {
					btnUpload.enabled = false;
					listFiles.verticalScrollPolicy = "off";
				} else {
					btnUpload.enabled = true;
					listFiles.verticalScrollPolicy = "on";
				}
			}
			
			private function updateStatus(msg:String):void {
				feedbackMsg.text = msg;
			}
			
			// Disable UI control
			private function disableUI():void {
				btnAdd.enabled = false;
				btnRemove.enabled = false;
				btnUpload.enabled = false;
				btnCancel.enabled = true;
				listFiles.enabled = false;
				listFiles.verticalScrollPolicy = "off";
			}
			
			// Enable UI control
			private function enableUI():void {
				btnAdd.enabled = true;
				btnRemove.enabled = true;
				btnUpload.enabled = true;
				btnCancel.enabled = false;
				listFiles.enabled = true;
				listFiles.verticalScrollPolicy = "on";
			}
			
			// Scroll listFiles to selected row
			private function scrollFiles():void {
				listFiles.verticalScrollPosition = listFiles.selectedIndex;
				listFiles.validateNow();
			}
			
			// Called to upload file based on current upload number
			private function startUpload():void {
				MonsterDebugger.trace("FileReference", _numCurrentUpload, "", "_numCurrentUpload");
				if (_arrUploadFiles.length > 0) {
					MonsterDebugger.trace("FileReference", _arrUploadFiles.length, "", "_arrUploadFiles.length");
					
					if(_refUploadFile != null) {
						_clearFileReferenceListeners();
					}
					
					disableUI();
					
					listFiles.selectedIndex = _numCurrentUpload;
					scrollFiles();
					
					// Variables to send along with upload
					var sendVars:URLVariables = new URLVariables();
					sendVars.action = "upload";
					
					// Get the cookies
					//ExternalInterface.call('eval','window.cookieStr = function () {return  document.cookie};')
					//var cookieStr:String = ExternalInterface.call('cookieStr'); 
					//var cookieHeader:URLRequestHeader = new URLRequestHeader("Cookie",cookieStr);
					
					//MonsterDebugger.trace(this, cookieHeader);
					
					var request:URLRequest = new URLRequest();
					request.data = sendVars;
				    request.url = _strUploadUrl;;
				    request.method = URLRequestMethod.POST;
					//request.requestHeaders.push(cookieHeader);
					MonsterDebugger.trace("URLRequestMethod", request);
				    _refUploadFile = new FileReference();
				    _refUploadFile = listFiles.selectedItem.file;
					
				    _refUploadFile.addEventListener(ProgressEvent.PROGRESS, onUploadProgress);
				   	_refUploadFile.addEventListener(Event.COMPLETE, onUploadComplete);
				    _refUploadFile.addEventListener(IOErrorEvent.IO_ERROR, onUploadIoError);
				  	_refUploadFile.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onUploadSecurityError);
					_refUploadFile.addEventListener(HTTPStatusEvent.HTTP_STATUS, onUploadStatusError );
					_refUploadFile.addEventListener(Event.OPEN, onEventOpen );
					_refUploadFile.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, onDataEventUCD );
					
					_refUploadFile.upload(request, this._uploadFieldName, false);
					
					MonsterDebugger.trace("FileReference", "upload");
				}
			}

			private function _clearFileReferenceListeners():void {
				_refUploadFile.removeEventListener(ProgressEvent.PROGRESS, onUploadProgress);
				_refUploadFile.removeEventListener(Event.COMPLETE, onUploadComplete);
				_refUploadFile.removeEventListener(IOErrorEvent.IO_ERROR, onUploadIoError);
				_refUploadFile.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onUploadSecurityError);
				_refUploadFile.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onUploadStatusError );
				_refUploadFile.removeEventListener(Event.OPEN, onEventOpen );
				_refUploadFile.removeEventListener(DataEvent.UPLOAD_COMPLETE_DATA, onDataEventUCD );
			}
			
			// Cancel and clear eventlisteners on last upload
			private function clearUpload():void {
				this._clearFileReferenceListeners();
				_refUploadFile.cancel();
				_numCurrentUpload = 0;
				updateProgBar();
				enableUI();
			}
			
			// Called on upload cancel
			private function onUploadCanceled():void {
				clearUpload();
				dispatchEvent(new Event("uploadCancel"));
			}
			
			// Get upload progress
			private function onUploadProgress(event:ProgressEvent):void {
				MonsterDebugger.trace("FileReference", event, "", "ProgressEvent");
				var numPerc:Number = Math.round((event.bytesLoaded / event.bytesTotal) * 100);
				updateProgBar(numPerc);
				var evt:ProgressEvent = new ProgressEvent("uploadProgress", false, false, event.bytesLoaded, event.bytesTotal);
				dispatchEvent(evt);
			}
			
			// Update progBar
			private function updateProgBar(numPerc:Number = 0):void {
				var strLabel:String = (_numCurrentUpload + 1) + "/" + _arrUploadFiles.length;
				strLabel = (_numCurrentUpload + 1 <= _arrUploadFiles.length && numPerc > 0 && numPerc < 100) ? numPerc + "% - " + strLabel : strLabel;
				strLabel = (_numCurrentUpload + 1 == _arrUploadFiles.length && numPerc == 100) ? ResourceManager.getInstance().getString("Strings", "pb_sendcomplete") + strLabel : strLabel;
				strLabel = (_arrUploadFiles.length == 0) ? "" : strLabel;
				progBar.label = strLabel;
				progBar.setProgress(numPerc, 100);
				progBar.validateNow();
			}
			
			// Called on upload complete
			private function onUploadComplete(event:Event):void {
				MonsterDebugger.trace("FileReference", event, "", "Event.COMPLETE")
				_numCurrentUpload++;				
				if (_numCurrentUpload < _arrUploadFiles.length) {
					startUpload();
				} else {
					enableUI();
					clearUpload();
					
					listFiles.dataProvider.removeAll();
					
					_arrUploadFiles = new Array();
					updateProgBar();
					
					try {
						if(this._uploadCompleteJSCallback != null && ExternalInterface.available) {
							MonsterDebugger.trace("FileReference", this._uploadCompleteJSCallback, "", "ExternalInterface.call"); 
							ExternalInterface.call(this._uploadCompleteJSCallback);
						}
					}
					catch(ex:Error) {
						MonsterDebugger.trace("FileReference", ex, "", "ExternalInterface.call"); 
					}
					
					dispatchEvent(new Event("uploadComplete"));
				}
			}
			
			private function onEventOpen(evt:Event):void {
				MonsterDebugger.trace("FileReference", evt, "", "Event.OPEN");
			}
			
			private function onDataEventUCD(evt:DataEvent):void {
				MonsterDebugger.trace("FileReference", evt, "", "DataEvent.UPLOAD_COMPLETE_DATA");
			}
			
			// Called on upload io error
			private function onUploadIoError(event:IOErrorEvent):void {
				MonsterDebugger.trace("FileReference", event, "", "IOErrorEvent")
				enableUI();
				
				var evt:IOErrorEvent = new IOErrorEvent("uploadIoError", false, false, event.text);
				dispatchEvent(evt);
			}
			
			// Called on upload security error
			private function onUploadSecurityError(event:SecurityErrorEvent):void {
				MonsterDebugger.trace("FileReference", event, "", "SecurityErrorEvent")
				enableUI();
				
				var evt:SecurityErrorEvent = new SecurityErrorEvent("uploadSecurityError", false, false, event.text);
				dispatchEvent(evt);
			}
			
			// Called on upload status error
			private function onUploadStatusError(event:HTTPStatusEvent):void {
				MonsterDebugger.trace("FileReference", event, "", "HTTPStatusEvent")
				enableUI();
				
				var evt:HTTPStatusEvent = new HTTPStatusEvent("uploadStatusError", false, false, event.status);
				dispatchEvent(evt);
			}
			
			// Change view state
			private function changeView():void {
				currentState = (currentState == "mini") ? "" : "mini";
			}