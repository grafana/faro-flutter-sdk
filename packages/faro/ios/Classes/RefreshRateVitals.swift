import Foundation
import UIKit
import os

// let logging = Logger(subsystem: "com.example.rumsdk", category: "refresh_vitals")


public class RefreshRateVitals{
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
    private var nextFrameDuration: CFTimeInterval?
    private static var backendSupportedFrameRate = 60.0
    public static var lastRefreshRate: Double? = nil

    init() {
        start()
    }

    deinit {
        stop()
    }

    // MARK: - Internal

      func framesPerSecond(provider: FrameInfoProvider) -> Double? {
        var fps: Double? = nil

        if let lastFrameTimestamp = self.lastFrameTimestamp {
            let currentFrameDuration = provider.currentFrameTimestamp - lastFrameTimestamp
            guard currentFrameDuration > 0 else {
                return nil
            }
            let currentFPS = 1.0 / currentFrameDuration

            // ProMotion displays (e.g. iPad Pro and newer iPhone Pro) can have refresh rate higher than 60 FPS.

            if let expectedCurrentFrameDuration = self.nextFrameDuration, provider.adaptiveFrameRateSupported {
                guard expectedCurrentFrameDuration > 0 else {
                    return nil
                }
                let expectedFPS = 1.0 / expectedCurrentFrameDuration
                fps = currentFPS * (Self.backendSupportedFrameRate / expectedFPS)
            } else {
                fps = currentFPS
            }
        }

        self.lastFrameTimestamp = provider.currentFrameTimestamp
        self.nextFrameDuration = provider.nextFrameTimestamp - provider.currentFrameTimestamp

        return fps
    }

    


    // MARK: - Private

    @objc
    private  func displayTick(link: CADisplayLink) {
        guard let fps = framesPerSecond(provider: link) else {
            return
        }
        RefreshRateVitals.lastRefreshRate = fps

    }

    func start() {
        guard displayLink == nil else {
            return
        }

        NSLog("start in cpuinfo")

        displayLink = CADisplayLink(target: self, selector: #selector(displayTick(link:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastFrameTimestamp = nil
    }

    @objc
    private func appWillResignActive() {
        stop()
    }

    @objc
    private func appDidBecomeActive() {
        start()
    }
}

internal protocol FrameInfoProvider {
    var currentFrameTimestamp: CFTimeInterval { get }

    var nextFrameTimestamp: CFTimeInterval { get }

    var maximumDeviceFramesPerSecond: Int { get }
}

private let adaptiveFrameRateThreshold = 60
extension FrameInfoProvider {
    var adaptiveFrameRateSupported: Bool {
        maximumDeviceFramesPerSecond > adaptiveFrameRateThreshold
    }
}

extension CADisplayLink: FrameInfoProvider {

    var maximumDeviceFramesPerSecond: Int {
        UIScreen.main.maximumFramesPerSecond
    }

    var currentFrameTimestamp: CFTimeInterval {
        timestamp
    }

    var nextFrameTimestamp: CFTimeInterval {
        targetTimestamp
    }
}
