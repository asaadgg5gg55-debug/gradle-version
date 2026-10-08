#!/bin/bash
# Generates the whole TvLauncher Android project in the current folder.
set -e

mkdir -p app/src/main/java/com/tvlauncher

cat > settings.gradle <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "TvLauncher"
include ':app'
EOF

cat > build.gradle <<'EOF'
plugins {
    id 'com.android.application' version '8.2.0' apply false
}
EOF

cat > gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
android.useAndroidX=false
EOF

cat > app/build.gradle <<'EOF'
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.tvlauncher'
    compileSdk 34

    defaultConfig {
        applicationId "com.tvlauncher"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
        encoding 'UTF-8'
    }
}
EOF

cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-feature android:name="android.software.leanback" android:required="false" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />

    <queries>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
        </intent>
    </queries>

    <application
        android:label="TV Launcher"
        android:supportsRtl="true"
        android:theme="@android:style/Theme.DeviceDefault.NoActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:screenOrientation="sensorLandscape"
            android:configChanges="orientation|screenSize|keyboardHidden|layoutDirection|locale">

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.HOME" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > app/src/main/java/com/tvlauncher/MainActivity.java <<'EOF'
package com.tvlauncher;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public class MainActivity extends Activity {

    static class AppItem {
        String pkg;
        String label;
        Drawable icon;
    }

    private static final int MATCH = LinearLayout.LayoutParams.MATCH_PARENT;
    private static final int WRAP = LinearLayout.LayoutParams.WRAP_CONTENT;

    private final List<AppItem> apps = new ArrayList<AppItem>();
    private final TextView[] tabs = new TextView[3];
    private final Handler handler = new Handler(Looper.getMainLooper());
    private SharedPreferences prefs;
    private FrameLayout content;
    private TextView clock;
    private int currentTab = 0;

    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            clock.setText(new SimpleDateFormat("hh:mm a", Locale.getDefault()).format(new Date()));
            handler.postDelayed(this, 15000);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences("tv", MODE_PRIVATE);
        buildUi();
        if (prefs.getString("name", null) == null) {
            askName();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        loadApps();
        showTab(currentTab);
        handler.post(tick);
    }

    @Override
    protected void onPause() {
        super.onPause();
        handler.removeCallbacks(tick);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        currentTab = 0;
        showTab(0);
    }

    @Override
    public void onBackPressed() {
        // A launcher never closes on Back.
    }

    // ---------------------------------------------------------------- UI

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setLayoutDirection(View.LAYOUT_DIRECTION_LTR);
        root.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{0xFF101C30, 0xFF04070D}));
        root.setPadding(dp(48), dp(20), dp(48), dp(12));

        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);

        String[] names = {"الرئيسية", "التطبيقات", "المفضلة"};
        for (int i = 0; i < 3; i++) {
            final int idx = i;
            TextView t = text(names[i], 18, false);
            t.setPadding(dp(18), dp(10), dp(18), dp(10));
            styleFocus(t, 1.08f, 0x00000000);
            t.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    currentTab = idx;
                    showTab(idx);
                }
            });
            tabs[i] = t;
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(WRAP, WRAP);
            lp.rightMargin = dp(6);
            bar.addView(t, lp);
        }

        bar.addView(new View(this), new LinearLayout.LayoutParams(0, 1, 1f));

        TextView wifi = text("الواي فاي", 16, false);
        wifi.setPadding(dp(16), dp(10), dp(16), dp(10));
        styleFocus(wifi, 1.08f, 0x22FFFFFF);
        wifi.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                openSettings(Settings.ACTION_WIFI_SETTINGS);
            }
        });
        LinearLayout.LayoutParams wl = new LinearLayout.LayoutParams(WRAP, WRAP);
        wl.rightMargin = dp(8);
        bar.addView(wifi, wl);

        TextView sett = text("الإعدادات", 16, false);
        sett.setPadding(dp(16), dp(10), dp(16), dp(10));
        styleFocus(sett, 1.08f, 0x22FFFFFF);
        sett.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                openSettings(Settings.ACTION_SETTINGS);
            }
        });
        bar.addView(sett, new LinearLayout.LayoutParams(WRAP, WRAP));

        clock = text("", 20, true);
        clock.setPadding(dp(20), 0, 0, 0);
        bar.addView(clock, new LinearLayout.LayoutParams(WRAP, WRAP));

        root.addView(bar, new LinearLayout.LayoutParams(MATCH, WRAP));

        content = new FrameLayout(this);
        content.setClipChildren(false);
        root.addView(content, new LinearLayout.LayoutParams(MATCH, 0, 1f));

        setContentView(root);
    }

    private void showTab(int idx) {
        for (int i = 0; i < tabs.length; i++) {
            tabs[i].setTypeface(null, i == idx ? Typeface.BOLD : Typeface.NORMAL);
            tabs[i].setTextColor(i == idx ? Color.WHITE : 0xFF9AA7BA);
        }
        content.removeAllViews();
        View page = (idx == 0) ? buildHome() : buildGrid(idx == 2);
        content.addView(page, new FrameLayout.LayoutParams(MATCH, MATCH));
    }

    private View buildHome() {
        ScrollView sv = new ScrollView(this);
        sv.setVerticalScrollBarEnabled(false);
        sv.setClipChildren(false);

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setClipChildren(false);
        col.setPadding(0, dp(12), 0, dp(24));

        col.addView(buildBanner());

        List<AppItem> favs = favApps();
        if (!favs.isEmpty()) {
            col.addView(buildRow("المفضلة", favs));
        }
        col.addView(buildRow("كل التطبيقات", apps));

        TextView hint = text("اضغط مطولاً على أي تطبيق لإضافته أو إزالته من المفضلة", 13, false);
        hint.setAlpha(0.6f);
        hint.setPadding(0, dp(16), 0, 0);
        col.addView(hint);

        sv.addView(col);
        return sv;
    }

    private View buildBanner() {
        LinearLayout b = new LinearLayout(this);
        b.setOrientation(LinearLayout.VERTICAL);
        b.setPadding(dp(32), dp(24), dp(32), dp(24));
        GradientDrawable g = new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
                new int[]{0xFF1E3A8A, 0xFF6D28D9});
        g.setCornerRadius(dp(20));
        b.setBackground(g);

        b.addView(text("أهلاً، " + prefs.getString("name", "ضيف"), 30, true));

        TextView sub = text(new SimpleDateFormat("EEEE d MMMM", Locale.getDefault()).format(new Date()), 16, false);
        sub.setAlpha(0.8f);
        b.addView(sub);

        final AppItem last = findApp(prefs.getString("last", null));
        if (last != null) {
            TextView btn = text("متابعة: " + last.label, 18, true);
            btn.setPadding(dp(24), dp(12), dp(24), dp(12));
            styleFocus(btn, 1.08f, 0x33FFFFFF);
            btn.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    launch(last);
                }
            });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(WRAP, WRAP);
            lp.topMargin = dp(16);
            b.addView(btn, lp);
        }
        return b;
    }

    private View buildRow(String title, List<AppItem> list) {
        LinearLayout wrap = new LinearLayout(this);
        wrap.setOrientation(LinearLayout.VERTICAL);
        wrap.setClipChildren(false);

        TextView t = text(title, 20, true);
        t.setPadding(dp(4), dp(22), 0, dp(6));
        wrap.addView(t);

        HorizontalScrollView hs = new HorizontalScrollView(this);
        hs.setHorizontalScrollBarEnabled(false);
        hs.setClipChildren(false);
        hs.setClipToPadding(false);

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setClipChildren(false);
        row.setPadding(0, dp(10), 0, dp(10));
        for (AppItem a : list) {
            row.addView(appCell(a), cellParams());
        }
        hs.addView(row);
        wrap.addView(hs);
        return wrap;
    }

    private View buildGrid(boolean favOnly) {
        List<AppItem> list = favOnly ? favApps() : apps;

        ScrollView sv = new ScrollView(this);
        sv.setVerticalScrollBarEnabled(false);
        sv.setClipChildren(false);

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setClipChildren(false);
        col.setPadding(0, dp(20), 0, dp(24));

        if (list.isEmpty()) {
            col.addView(text(favOnly
                    ? "لا توجد تطبيقات مفضلة. اضغط مطولاً على أي تطبيق لإضافته."
                    : "لا توجد تطبيقات", 18, false));
        }

        int cols = Math.max(3, (getResources().getDisplayMetrics().widthPixels - dp(96)) / dp(142));
        LinearLayout row = null;
        for (int i = 0; i < list.size(); i++) {
            if (i % cols == 0) {
                row = new LinearLayout(this);
                row.setOrientation(LinearLayout.HORIZONTAL);
                row.setClipChildren(false);
                col.addView(row);
            }
            row.addView(appCell(list.get(i)), cellParams());
        }

        sv.addView(col);
        return sv;
    }

    private View appCell(final AppItem a) {
        LinearLayout c = new LinearLayout(this);
        c.setOrientation(LinearLayout.VERTICAL);
        c.setGravity(Gravity.CENTER);
        c.setPadding(dp(8), dp(12), dp(8), dp(8));

        ImageView iv = new ImageView(this);
        iv.setImageDrawable(a.icon);
        c.addView(iv, new LinearLayout.LayoutParams(dp(64), dp(64)));

        TextView t = text((isFav(a) ? "★ " : "") + a.label, 13, false);
        t.setSingleLine(true);
        t.setEllipsize(TextUtils.TruncateAt.END);
        t.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams tl = new LinearLayout.LayoutParams(MATCH, WRAP);
        tl.topMargin = dp(8);
        c.addView(t, tl);

        styleFocus(c, 1.12f, 0x22FFFFFF);
        c.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                launch(a);
            }
        });
        c.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View v) {
                toggleFav(a);
                return true;
            }
        });
        return c;
    }

    private LinearLayout.LayoutParams cellParams() {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dp(130), dp(116));
        lp.setMargins(0, 0, dp(12), dp(12));
        return lp;
    }

    // ----------------------------------------------------------- Helpers

    private TextView text(String s, int sp, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(sp);
        t.setTextColor(Color.WHITE);
        if (bold) {
            t.setTypeface(null, Typeface.BOLD);
        }
        return t;
    }

    private void styleFocus(View v, final float scale, final int color) {
        v.setFocusable(true);
        v.setClickable(true);
        setBg(v, false, color);
        v.setOnFocusChangeListener(new View.OnFocusChangeListener() {
            @Override
            public void onFocusChange(View view, boolean focused) {
                float s = focused ? scale : 1f;
                view.animate().scaleX(s).scaleY(s).setDuration(120).start();
                setBg(view, focused, color);
            }
        });
    }

    private void setBg(View v, boolean focused, int color) {
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(dp(14));
        g.setColor(color);
        if (focused) {
            g.setStroke(dp(3), Color.WHITE);
        }
        v.setBackground(g);
    }

    private int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density + 0.5f);
    }

    private void openSettings(String action) {
        try {
            startActivity(new Intent(action));
        } catch (Exception e) {
            Toast.makeText(this, "تعذر فتح الإعدادات", Toast.LENGTH_SHORT).show();
        }
    }

    // -------------------------------------------------------------- Data

    private void loadApps() {
        PackageManager pm = getPackageManager();
        LinkedHashMap<String, AppItem> map = new LinkedHashMap<String, AppItem>();
        String[] cats = {Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER};
        for (String cat : cats) {
            Intent q = new Intent(Intent.ACTION_MAIN, null);
            q.addCategory(cat);
            for (ResolveInfo ri : pm.queryIntentActivities(q, 0)) {
                String p = ri.activityInfo.packageName;
                if (p.equals(getPackageName()) || map.containsKey(p)) {
                    continue;
                }
                AppItem a = new AppItem();
                a.pkg = p;
                a.label = String.valueOf(ri.loadLabel(pm));
                a.icon = ri.loadIcon(pm);
                map.put(p, a);
            }
        }
        apps.clear();
        apps.addAll(map.values());
        Collections.sort(apps, new java.util.Comparator<AppItem>() {
            @Override
            public int compare(AppItem x, AppItem y) {
                return x.label.compareToIgnoreCase(y.label);
            }
        });
    }

    private AppItem findApp(String pkg) {
        if (pkg == null) {
            return null;
        }
        for (AppItem a : apps) {
            if (a.pkg.equals(pkg)) {
                return a;
            }
        }
        return null;
    }

    private boolean isFav(AppItem a) {
        return prefs.getStringSet("favs", new HashSet<String>()).contains(a.pkg);
    }

    private List<AppItem> favApps() {
        List<AppItem> out = new ArrayList<AppItem>();
        for (AppItem a : apps) {
            if (isFav(a)) {
                out.add(a);
            }
        }
        return out;
    }

    private void toggleFav(AppItem a) {
        Set<String> f = new HashSet<String>(prefs.getStringSet("favs", new HashSet<String>()));
        if (f.contains(a.pkg)) {
            f.remove(a.pkg);
            Toast.makeText(this, "أُزيل من المفضلة", Toast.LENGTH_SHORT).show();
        } else {
            f.add(a.pkg);
            Toast.makeText(this, "أُضيف إلى المفضلة", Toast.LENGTH_SHORT).show();
        }
        prefs.edit().putStringSet("favs", f).apply();
        showTab(currentTab);
    }

    private void launch(AppItem a) {
        PackageManager pm = getPackageManager();
        Intent i = pm.getLeanbackLaunchIntentForPackage(a.pkg);
        if (i == null) {
            i = pm.getLaunchIntentForPackage(a.pkg);
        }
        if (i == null) {
            Toast.makeText(this, "تعذر فتح التطبيق", Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            prefs.edit().putString("last", a.pkg).apply();
            startActivity(i);
        } catch (Exception e) {
            Toast.makeText(this, "تعذر فتح التطبيق", Toast.LENGTH_SHORT).show();
        }
    }

    private void askName() {
        final EditText et = new EditText(this);
        et.setSingleLine(true);
        et.setHint("اسمك");
        new AlertDialog.Builder(this)
                .setTitle("أهلاً بك")
                .setMessage("اكتب اسمك ليظهر في الشاشة الرئيسية")
                .setView(et)
                .setCancelable(false)
                .setPositiveButton("متابعة", new android.content.DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(android.content.DialogInterface d, int which) {
                        String n = et.getText().toString().trim();
                        prefs.edit().putString("name", n.isEmpty() ? "ضيف" : n).apply();
                        showTab(currentTab);
                    }
                })
                .show();
    }
}
EOF

echo "Project files generated."
