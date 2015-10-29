package com.streethawk.feeds;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import android.content.Context;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import com.streethawk.library.feeds.ISHFeedItemObserver;
import com.streethawk.library.feeds.SHFeedItem;

/**
 * FeedWrapper receives feed item from server and passes the same to application.
 */
public class FeedWrapper implements ISHFeedItemObserver {
	public static FeedWrapper mInstance = null;
	private CallbackContext mFeedItemCallback=null;
	private static Context mContext;
	private FeedWrapper(){}

	public static FeedWrapper getInstance(){
		if(null==mInstance)
			mInstance = new FeedWrapper();
		return mInstance;
	}
	
	public void registerFeed(Context context,CallbackContext cb){
		if(null!=context){
			mContext = context;
			SHFeedItem.getInstance(context).registerFeedItemObserver(this);
			mFeedItemCallback = cb;
		}
	}

	@Override
	public void shFeedReceived(JSONArray value){
		if(null!=this.mFeedItemCallback){
			PluginResult result = new PluginResult(PluginResult.Status.OK,value);
			result.setKeepCallback(true);
			this.mFeedItemCallback.sendPluginResult(result);
		}
	}
}

