import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/admob_service.dart';

class AdPage extends StatefulWidget {
	const AdPage({super.key});

	@override
	State<AdPage> createState() => _AdPageState();
}

class _AdPageState extends State<AdPage> {
	final List<BannerAd?> _bannerAds = [];
	final List<bool> _isBannerLoaded = [];
	AdSize? _adSize;
	late int _bannerCount;

	@override
	void initState() {
		super.initState();
		_loadBannerAds();
		_loadInterstitialAd();
	}

	bool _isAdmobSupported() {
		return Theme.of(context).platform == TargetPlatform.android ||
         Theme.of(context).platform == TargetPlatform.iOS;
	}

	Future<void> _loadBannerAds() async {
		// Skip ads on unsupported platforms (Windows, Linux, macOS, Web)
		if (!_isAdmobSupported()) {
			return;
		}

		// Get the screen width for adaptive banner
		WidgetsBinding.instance.addPostFrameCallback((_) async {
			final context = this.context;
			final screenHeight = MediaQuery.of(context).size.height;
			final screenWidth = MediaQuery.of(context).size.width;
			
			// Calculate how many ads fit in the height (assume ~60 per ad with padding)
			final adHeight = 60.0;
			_bannerCount = (screenHeight / adHeight).toInt();
			_bannerCount = _bannerCount.clamp(2, 10);
			
			// Initialize the lists
			_bannerAds.clear();
			_isBannerLoaded.clear();
			for (int i = 0; i < _bannerCount; i++) {
				_bannerAds.add(null);
				_isBannerLoaded.add(false);
			}
			
			final width = screenWidth.truncate();
			final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
			setState(() {
				_adSize = adSize;
			});
			if (adSize == null) return;
			
			// Load multiple banners
			for (int i = 0; i < _bannerCount; i++) {
				final banner = BannerAd(
					size: adSize,
					adUnitId: AdMobService.getAdUnitId(AdPlacement.bannerAdPage),
					listener: BannerAdListener(
						onAdLoaded: (ad) {
							setState(() {
								_bannerAds[i] = ad as BannerAd;
								_isBannerLoaded[i] = true;
							});
						},
						onAdFailedToLoad: (ad, error) {
							ad.dispose();
							setState(() {
								_isBannerLoaded[i] = false;
							});
						},
					),
					request: const AdRequest(),
				);
				await banner.load();
			}
		});
	}

	void _loadInterstitialAd() {
		// Skip on unsupported platforms
		if (!_isAdmobSupported()) {
			return;
		}

		InterstitialAd.load(
			adUnitId: AdMobService.getAdUnitId(AdPlacement.interstitialStatistics),
			request: const AdRequest(),
			adLoadCallback: InterstitialAdLoadCallback(
				onAdLoaded: (ad) {
					ad.fullScreenContentCallback = FullScreenContentCallback(
						onAdDismissedFullScreenContent: (ad) {
							ad.dispose();
							// Show dialog after interstitial ad closes
							if (mounted) {
								showDialog(
									context: context,
									builder: (context) => AlertDialog(
										title: const Text('GEEEZ!!!'),
                    content: const Text('You\'re so weird brahhh! But I like it 😉. Thank you! 😊❤️'),
										actions: [
											TextButton(
												onPressed: () => Navigator.pop(context),
												child: const Text('OK'),
											),
										],
									),
								);
							}
						},
						onAdFailedToShowFullScreenContent: (ad, error) {
							ad.dispose();
						},
					);
					// Show the interstitial ad as soon as it's loaded
					ad.show();
				},
				onAdFailedToLoad: (error) {
					// Handle error silently
				},
			),
		);
	}

	@override
	void dispose() {
		for (var ad in _bannerAds) {
			ad?.dispose();
		}
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		// Show message if ads are not supported on this platform
		if (!_isAdmobSupported()) {
			return Scaffold(
				appBar: AppBar(title: const Text('Watch Ads')),
				body: const Center(
					child: Text('Ads are not available on this platform'),
				),
			);
		}

		return Scaffold(
			appBar: AppBar(title: const Text('Watch Ads')),
			body: Column(
				children: List.generate(
					_bannerCount,
					(index) => Flexible(
						fit: FlexFit.tight,
						child: Center(
							child: _isBannerLoaded[index] && _bannerAds[index] != null && _adSize != null
									? SizedBox(
											width: _adSize!.width.toDouble(),
											height: _adSize!.height.toDouble(),
											child: AdWidget(ad: _bannerAds[index]!),
										)
									: SizedBox(
											width: _adSize?.width.toDouble() ?? double.infinity,
											height: _adSize?.height.toDouble() ?? 50,
											child: const Placeholder(),
										),
						),
					),
				),
			),
		);
	}
}
