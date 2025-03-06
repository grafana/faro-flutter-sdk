import Foundation

public class CPUInfo {
    private static let clockSpeedHz: Double = {
        var clockSpeed = sysconf(_SC_CLK_TCK)
        if clockSpeed == -1 {
            perror("sysconf")
            clockSpeed = 100 // Default value if sysconf fails (you can adjust as needed)
        }
        return Double(clockSpeed)
    }()


    private static var lastCpuTime: Double? = nil
    private static var lastProcessTime: Double? = nil
    private  static var loadPrevious : host_cpu_load_info? = nil;


    static func hostCPULoadInfo() -> host_cpu_load_info? {
        let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info>.stride/MemoryLayout<integer_t>.stride
        var size = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
        var cpuLoadInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        if result != KERN_SUCCESS{
            print("Error  - \(#file): \(#function) - kern_result_t = \(result)")
            return nil
        }
        return cpuLoadInfo
    }
    static func measureAppStartUpTime() -> Double {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib : [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, u_int(mib.count), &kinfo, &size, nil, 0)
        let start_time = kinfo.kp_proc.p_starttime
        var time : timeval = timeval(tv_sec: 0, tv_usec: 0)
        gettimeofday(&time, nil)
        let currentTimeMilliseconds = Double(Int64(time.tv_sec) * 1000) + Double(time.tv_usec) / 1000.0
        let processTimeMilliseconds = Double(Int64(start_time.tv_sec) * 1000) + Double(start_time.tv_usec) / 1000.0
        return currentTimeMilliseconds - processTimeMilliseconds

    }



        public static func getCpuInfo() -> Double? {
                if let load = hostCPULoadInfo(){
                    let usrDiff: Double = Double(load.cpu_ticks.0);
                    let sysDiff: Double = Double(load.cpu_ticks.1);
                    let idleDiff: Double = Double(load.cpu_ticks.2);
                    let niceDiff: Double = Double(load.cpu_ticks.3);
                    let cpuTime = (usrDiff + sysDiff + niceDiff + idleDiff ) / clockSpeedHz
                    let processTime = measureAppStartUpTime()
                    if lastCpuTime == nil || lastProcessTime == nil {
                        lastCpuTime = cpuTime
                        lastProcessTime = processTime
                        return 0.0
                    }
                    let relCpuUsage = 100*(cpuTime - lastCpuTime!) / (processTime - lastProcessTime!)
                    lastCpuTime = cpuTime
                    lastProcessTime = processTime
                    return relCpuUsage
                }
                return 0.0
        }
}
