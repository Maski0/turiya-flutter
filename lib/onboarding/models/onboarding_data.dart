/// Model to store user's onboarding responses
class OnboardingData {
  String? userName;
  List<String> motivations = [];
  String? vedantaFamiliarity;
  List<String> struggles = [];
  String? customStruggle;
  bool? wantsDailyBlessings;
  List<String> dailyPractices = [];
  bool hasCompletedAuth = false;
  
  OnboardingData();
  
  /// Convert to map for storage/API calls
  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'motivations': motivations,
      'vedantaFamiliarity': vedantaFamiliarity,
      'struggles': struggles,
      'customStruggle': customStruggle,
      'wantsDailyBlessings': wantsDailyBlessings,
      'dailyPractices': dailyPractices,
      'hasCompletedAuth': hasCompletedAuth,
    };
  }
  
  /// Create from map
  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    final data = OnboardingData();
    data.userName = json['userName'];
    data.motivations = List<String>.from(json['motivations'] ?? []);
    data.vedantaFamiliarity = json['vedantaFamiliarity'];
    data.struggles = List<String>.from(json['struggles'] ?? []);
    data.customStruggle = json['customStruggle'];
    data.wantsDailyBlessings = json['wantsDailyBlessings'];
    data.dailyPractices = List<String>.from(json['dailyPractices'] ?? []);
    data.hasCompletedAuth = json['hasCompletedAuth'] ?? false;
    return data;
  }
  
  /// Check if onboarding is complete
  bool get isComplete {
    return userName != null &&
        motivations.isNotEmpty &&
        vedantaFamiliarity != null &&
        struggles.isNotEmpty &&
        wantsDailyBlessings != null &&
        dailyPractices.isNotEmpty;
  }
  
  /// Get progress percentage (0.0 to 1.0)
  double get progress {
    int completed = 0;
    int total = 7;
    
    if (userName != null) completed++;
    if (motivations.isNotEmpty) completed++;
    if (vedantaFamiliarity != null) completed++;
    if (struggles.isNotEmpty) completed++;
    if (wantsDailyBlessings != null) completed++;
    if (dailyPractices.isNotEmpty) completed++;
    if (hasCompletedAuth) completed++;
    
    return completed / total;
  }
}

