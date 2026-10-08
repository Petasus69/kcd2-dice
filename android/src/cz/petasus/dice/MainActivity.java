package cz.petasus.dice;

import android.app.Activity;
import android.os.Bundle;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.view.View;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.HashMap;

/** Offline-only WebView shell. All resources use a same-origin HTTPS asset host. */
public class MainActivity extends Activity {
 private WebView web;
 private static final String HOST = "dice.local";
 @Override public void onCreate(Bundle state) {
  super.onCreate(state);
  getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
  web = new WebView(this);
  web.setBackgroundColor(0xff20170f);
  WebSettings settings = web.getSettings();
  settings.setJavaScriptEnabled(true);
  settings.setDomStorageEnabled(true);
  settings.setAllowFileAccess(false);
  settings.setAllowContentAccess(false);
  settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
  settings.setMediaPlaybackRequiresUserGesture(false);
  settings.setTextZoom(100);
  settings.setSupportZoom(false);
  web.addJavascriptInterface(new Haptics(), "Android");
  web.setWebViewClient(new WebViewClient() {
   @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
    return !HOST.equals(request.getUrl().getHost());
   }
   @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
    if (!HOST.equals(request.getUrl().getHost())) return empty(403);
    String path = request.getUrl().getPath();
    if (path == null || path.equals("/")) path="/index.html";
    if (path.contains("..") || !request.getMethod().equals("GET")) return empty(403);
    String mime = path.endsWith(".html")?"text/html":path.endsWith(".js")?"text/javascript":path.endsWith(".css")?"text/css":path.endsWith(".jpg")?"image/jpeg":path.endsWith(".svg")?"image/svg+xml":path.endsWith(".ttf")?"font/ttf":"application/octet-stream";
    try {
     InputStream data=getAssets().open("web"+path);
     HashMap<String,String> headers=new HashMap<>();
     headers.put("Cache-Control", "no-cache");
     headers.put("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'none'; object-src 'none'; base-uri 'none'");
     return new WebResourceResponse(mime, "UTF-8", 200, "OK", headers, data);
    } catch (Exception e) { return empty(404); }
   }
   private WebResourceResponse empty(int status) {
    return new WebResourceResponse("text/plain", "UTF-8", status, "Blocked", new HashMap<String,String>(),new ByteArrayInputStream(new byte[0]));
   }
  });
  setContentView(web);
  immersive();
  web.loadUrl("https://"+HOST+"/index.html");
 }
 private void immersive() {
  getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN|View.SYSTEM_UI_FLAG_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY|View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
 }
 @Override public void onWindowFocusChanged(boolean focus) {super.onWindowFocusChanged(focus);if(focus)immersive();}
 @Override public void onBackPressed() {web.evaluateJavascript("window.onNativeBack && window.onNativeBack()",null);}
 @Override protected void onPause() {web.evaluateJavascript("window.dispatchEvent(new Event('pagehide'))",null);web.onPause();super.onPause();}
 @Override protected void onResume() {super.onResume();if(web!=null)web.onResume();}
 @Override protected void onDestroy() {web.removeJavascriptInterface("Android");web.destroy();super.onDestroy();}
 private class Haptics {
  @JavascriptInterface public void haptic(String kind) {
   Vibrator v=(Vibrator)getSystemService(VIBRATOR_SERVICE);
   if(v!=null&&v.hasVibrator())v.vibrate(VibrationEffect.createOneShot("bust".equals(kind)?60:18,VibrationEffect.DEFAULT_AMPLITUDE));
  }
 }
}
