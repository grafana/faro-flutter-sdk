package com.example.rum_sdk;

import android.os.Build;
import android.os.SystemClock;
import android.system.Os;
import android.system.OsConstants;
import android.os.Process;

import androidx.annotation.RequiresApi;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;


@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class CPUInfo {


    private static final long clockSpeedHz = Os.sysconf(OsConstants._SC_CLK_TCK);
    private static final File statFile = new File("/proc/"+ Process.myPid() +"/stat");
    private static Double lastCpuTime =null;
    private static Double lastProcessTime =null;

    public static Double onGetCpuInfo() {
        if (statFile.exists() && statFile.canRead()) {
            try {
                BufferedReader   reader = new BufferedReader(new FileReader(statFile));
                String line = reader.readLine();
                reader.close();
                String []statArray = line.split(" ");
                int utime = Integer.parseInt(statArray[13]);
                int stime = Integer.parseInt(statArray[14]);
                int cutime = Integer.parseInt(statArray[15]);
                int cstime = Integer.parseInt(statArray[16]);
                Double cpuTime = (double) ((utime+stime+cutime+cstime)/clockSpeedHz);
                Double uptime = SystemClock.elapsedRealtime()/1000.0;
                Long startTime = Long.parseLong(statArray[21]);
                Double processTime = uptime - (startTime / clockSpeedHz);
                if(lastCpuTime == null){
                    lastCpuTime = cpuTime;
                    lastProcessTime = processTime;
                    return 0.0;
                }
                return 100*((cpuTime - lastCpuTime) / (processTime - lastProcessTime));

            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }
        return null;
    }
}
