package com.example.rum_sdk;

import android.content.Context;

import io.flutter.Log;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.Writer;
import java.util.ArrayList;

public class RumCache {

    private final String lastCrashFileName = "last_crash_file";
    private final String lastCrashInfoFileName = "last_crash_info_file";

    private static Context context;

    public RumCache() {
    }


    public static void setContext(Context context) {
        RumCache.context = context;
    }

    public boolean writeToCache(String data) {
        if (RumCache.context == null) {
            return false;
        }

        File cacheDir = RumCache.context.getCacheDir();
        File crashCacheFile = new File(cacheDir, lastCrashFileName);
        try {
                Writer out = new BufferedWriter(new FileWriter(crashCacheFile,true), 1024);
                out.write(data+"\n");
                out.close();
        } catch (IOException e) {
            Log.e("RumCache", "Error writing to cache: " + e.getMessage());
            return false;
        }

        return true;
    }

    public  void removeCacheFile(){
        try{
            File cacheFile  = new File(RumCache.context.getCacheDir(),lastCrashFileName);
            if(cacheFile.exists()){
                cacheFile.delete();
            }

        } catch (Exception e){
            Log.e("RumCache", "Error removing cache file: " + e.getMessage());
        }

    }

    public ArrayList<String> readFromCache() {
        // Implement your read logic here
        ArrayList<String> lst = new ArrayList<>();
        if(RumCache.context == null){
            return lst;
        }
        File cacheDir = RumCache.context.getCacheDir();
        File crashCacheFile = new File(cacheDir, lastCrashFileName);
        try{
            if(crashCacheFile.exists()){
                BufferedReader br = new BufferedReader(new FileReader(crashCacheFile));
                String line;
                while((line = br.readLine()) != null){
                    lst.add(line);
                }
                br.close();
            }

        }catch(Exception e){
            Log.e("RumCache", "Error reading from cache: " + e.getMessage());
        }
        return lst;
    }
}
