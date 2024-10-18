package com.example.rum_sdk;

import androidx.annotation.Nullable;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


public class MemoryUsageInfo {

    private static final File statFile  = new File("/proc/"+android.os.Process.myPid()+"/status");
    private static final Pattern pattern = Pattern.compile("VmRSS:\\s+(\\d+) kB");


    public @Nullable static Double onGetMemoryUsageInfo(){
            if (statFile.exists() && statFile.canRead()) {
                BufferedReader reader = null;
                try {
                    reader = new BufferedReader(new FileReader(statFile));
                    List<String> lines = new ArrayList<>();
                    String line;
                    while ((line = reader.readLine()) != null) {
                        lines.add(line);
                    }

                    Double memorySizeKb = null;
                    for (String l : lines) {
                        Matcher matcher = pattern.matcher(l);
                        if (matcher.find()) {
                            String match = matcher.group(1);
                            if (match != null) {
                                memorySizeKb = Double.parseDouble(match);
                                break;
                            }
                        }
                    }
                    return memorySizeKb;
                } catch (IOException e) {
                    e.printStackTrace();
                } finally {
                    if (reader != null) {
                        try {
                            reader.close();
                        } catch (IOException e) {
                            e.printStackTrace();
                        }
                    }
                }            }
            return null;
    }
}
