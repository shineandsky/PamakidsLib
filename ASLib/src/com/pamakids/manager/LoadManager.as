package com.pamakids.manager
{
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.system.ImageDecodingPolicy;
	import flash.system.LoaderContext;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;

	/**
	 * 文件加载管理
	 * @author mani
	 */
	public class LoadManager
	{

		public static const BITMAP:String="BITMAP";
		private static var _instance:LoadManager;

		public static function get instance():LoadManager
		{
			if (!_instance)
				_instance=new LoadManager();
			return _instance;
		}

		public function LoadManager()
		{
			loaderDic=new Dictionary();
			loadingDic=new Dictionary();
			loadedDic=new Dictionary();
			savePathDic=new Dictionary();
			onCompleteDic=new Dictionary();
			completeParamsDic=new Dictionary();
		}

		public var errorHandler:Function;

		private var completeParamsDic:Dictionary; //加载完成后回调函数的参数字典

		private var loadedDic:Dictionary; //已经加载的数据字典

		private var loaderDic:Dictionary; //Loader字典

		private var loaderFormate:Dictionary=new Dictionary();

		private var loadingDic:Dictionary; //正在加载字典

		private var onCompleteDic:Dictionary; //加载完成后回调函数字典

		private var savePathDic:Dictionary; //存储路径字典

		/**
		 * 加载
		 * @param url url地址
		 * @param onComplete 加载完成回调函数
		 * @param savePath //存储路径
		 * @param params //传递的参数
		 * @param loadingCallBack //加载的回调函数
		 * @param formate 加载文件的格式
		 */
		public function load(url:String, onComplete:Function, savePath:String=null, params:Array=null, loadingCallBack:Function=null, forceReload:Boolean=false, formate:String=URLLoaderDataFormat.BINARY):void
		{
			var b:ByteArray;

			//如果有存储路径，先去本地缓存找是否有
			if (savePath) //一个return会一直load下去,两个return条件会更严密?
			{
				var cachedData:Object=FileManager.readFile(savePath);
				if (cachedData is ByteArray)
					cachedData=cachedData as ByteArray;
				if (cachedData)
				{
					params ? onComplete(cachedData, params) : onComplete(cachedData);
					return;
				}
			}

			var u:URLLoader=loadingDic[url];
			var arr:Array;
			completeParamsDic[onComplete]=params;

			//如果有正在加载的，则把加载完成的回调函数添加到数组里
			if (u)
			{
				arr=loaderDic[u];
				if (arr.indexOf(onComplete) == -1)
					arr.push(onComplete);
				return;
			}

			if (!forceReload)
			{
				b=loadedDic[url] as ByteArray;

				//如果从程序缓存里找到了已加载的数据，则返回
				if (b)
				{
					if (params)
					{
						onComplete(b, params);
						delete completeParamsDic[onComplete];
					}
					else
					{
						onComplete(b);
					}
					return;
				}
			}

			//开始加载
			u=new URLLoader();
			loaderFormate[u]=formate;
			loadingDic[url]=u;
			if (savePath)
				savePathDic[u]=savePath;
			loaderDic[u]=[onComplete];
			if (formate == BITMAP)
				formate=URLLoaderDataFormat.BINARY;
			u.dataFormat=formate;
			u.load(new URLRequest(url));
			completeParamsDic[u]=params;
			u.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			u.addEventListener(Event.COMPLETE, onBinaryLoaded);
			if (loadingCallBack)
			{
				u.addEventListener(ProgressEvent.PROGRESS, loadingCallBack);
			}
		}

		protected function onLoaded(event:Event):void
		{
			var l:LoaderInfo=event.target as LoaderInfo;
			l.removeEventListener(Event.COMPLETE, onLoaded);
			var callbacks:Array=loaderDic[l.loader];
			delete loaderDic[l.loader];

			var params:Array;

			//每个回调函数都调用
			params=completeParamsDic[l.loader];
			delete completeParamsDic[l.loader];
			for each (var f:Function in callbacks)
			{
				params ? f(l.content, params) : f(l.content);
			}
		}

		private function getBitmapFromByteArray(byteArray:ByteArray, callbacks:Array=null, params:Array=null):void
		{
			var l:Loader=new Loader();
			var lc:LoaderContext=new LoaderContext();
			lc.imageDecodingPolicy=ImageDecodingPolicy.ON_LOAD;
			loaderDic[l]=callbacks;
			l.loadBytes(byteArray, lc);
			completeParamsDic[l]=params;
			l.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoaded);
		}

		private function ioErrorHandler(event:IOErrorEvent):void
		{
			trace('load io error');
			if (errorHandler != null)
				errorHandler();
		}

		private function onBinaryLoaded(event:Event):void
		{
			var u:URLLoader=event.target as URLLoader;
			u.removeEventListener(Event.COMPLETE, onBinaryLoaded);
			var f:Function;
			var arr:Array=loaderDic[u];
			var params:Array;

			var b:ByteArray=u.data as ByteArray;
			if (b && b.length == 0)
				return;

			//将加载的数据存到应用缓存里
			for (var key:String in loadingDic)
			{
				if (loadingDic[key] == u)
				{
					loadedDic[key]=u.data;
					delete loadingDic[key];
					break;
				}
			}

			//将加载数据存到本地文件
			var savePath:String=savePathDic[u];
			if (savePath)
			{
				FileManager.saveFile(savePath, u.data);
				delete savePathDic[u];
			}
			delete loaderDic[u];
			var formate:String=loaderFormate[u];
			delete loaderFormate[u];
			params=completeParamsDic[u];
			delete completeParamsDic[u];
			if (formate == BITMAP && b)
			{
				getBitmapFromByteArray(b, arr, params);
				return;
			}

			//每个回调函数都调用
			for each (f in arr)
			{
				params ? f(u.data, params) : f(u.data);
			}
		}
	}
}
