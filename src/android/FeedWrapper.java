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
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import com.streethawk.library.core.StreetHawk;

/**
 * FeedWrapper receives feed item from server and passes the same to application.
 */
public class FeedWrapper extends BroadcastReceiver implements ISHFeedItemObserver {
	public static FeedWrapper mInstance = null;
	private CallbackContext mFeedItemCallback=null;
	private static CallbackContext mNotifyNewFeedCallback=null;
	private static Context mContext;
	private FeedWrapper(){}

	@Override
	public void onReceive(Context context, Intent intent){
		String action = intent.getAction();
		if (action.equals("com.streethawk.intent.action.newfeed")) {
			 String installId = intent.getStringExtra("installid");
	            if(null==installId)
	                return;
	            if (!(installId.equals(StreetHawk.INSTANCE.getInstallId(context)))) {
	            	return;
	            }
			if(null!=mNotifyNewFeedCallback){
				try{
				JSONObject feedValue = new JSONObject(); 
				feedValue.put("NEW_FEED",1); //TODO correct feed number here
				PluginResult result = new PluginResult(PluginResult.Status.OK,feedValue);
				result.setKeepCallback(true);
				this.mFeedItemCallback.sendPluginResult(result);
				}catch(JSONException e){
					return;
				}
			}
		}
	}

	public void notifyNewFeedCallback(Context context,CallbackContext cb){
		if(null!=context){
			mContext = context;
			mNotifyNewFeedCallback = cb;
		}
	}
	
	
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

