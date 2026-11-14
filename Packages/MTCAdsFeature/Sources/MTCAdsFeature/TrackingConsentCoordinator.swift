import Foundation
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Runs once at startup, before any ad request: Google's UMP consent form (if one applies), then
/// Apple's ATT prompt, then starts the Mobile Ads SDK. Both prompts are system/Google UI — this
/// type owns only the sequencing, never any dialog content of its own.
@MainActor
public enum TrackingConsentCoordinator {
    public static func requestConsentAndStartAds() async {
        await requestConsentInfoUpdate()
        if ConsentInformation.shared.formStatus == .available {
            await presentConsentFormIfRequired()
        }
        await requestTrackingAuthorization()
        MobileAds.shared.start(completionHandler: nil)
    }

    private static func requestConsentInfoUpdate() async {
        let parameters = RequestParameters()
        #if DEBUG
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        #endif
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }
    }

    private static func presentConsentFormIfRequired() async {
        guard let presenter = RootViewController.current() else { return }
        await withCheckedContinuation { continuation in
            ConsentForm.loadAndPresentIfRequired(from: presenter) { _ in
                continuation.resume()
            }
        }
    }

    private static func requestTrackingAuthorization() async {
        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
            }
        }
    }
}
