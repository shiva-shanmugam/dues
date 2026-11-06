class MerchantNormalizer {
  const MerchantNormalizer();

  static final _aliases = <RegExp, String>{
    RegExp(r'\bNETFLIX\b'): 'Netflix',
    RegExp(r'\bSPOTIFY\b'): 'Spotify',
    RegExp(r'\b(YOUTUBE|GOOGLE\s*YOUTUBE)\b'): 'YouTube Premium',
    RegExp(r'\b(AMAZON\s*PRIME|AMZN\s*PRIME)\b'): 'Amazon Prime',
    RegExp(r'\b(HOTSTAR|DISNEY\+?\s*HOTSTAR)\b'): 'Disney+ Hotstar',
    RegExp(r'\bAPPLE(\.COM)?(/BILL)?\b'): 'Apple',
    RegExp(r'\bGOOGLE\s*ONE\b'): 'Google One',
    RegExp(r'\bADOBE\b'): 'Adobe',
    RegExp(r'\bMICROSOFT\b|\bMSFT\b'): 'Microsoft',
    RegExp(r'\bCULT\.?\s*FIT\b|\bCUREFIT\b'): 'Cult.fit',
    RegExp(r'\bJIO\b'): 'Jio',
    RegExp(r'\bAIRTEL\b'): 'Airtel',
    RegExp(r'\bNOTION\b'): 'Notion',
    RegExp(r'\bDROPBOX\b'): 'Dropbox',
    RegExp(r'\bSWIGGY\s*ONE\b'): 'Swiggy One',
    RegExp(r'\bZOMATO\s*(GOLD)?\b'): 'Zomato Gold',
  };

  String normalize(String raw) {
    var value = raw.toUpperCase().trim();
    value = value
        .replaceAll(RegExp(r'https?://|WWW\.'), '')
        .replaceAll(RegExp(r'\b(POS|ECOM|UPI|VPA|IN\*)\b'), ' ')
        .replaceAll(RegExp(r'@[A-Z0-9._-]+'), ' ')
        .replaceAll(RegExp(r'\.(COM|IN|CO\.IN)\b'), ' ')
        .replaceAll(
          RegExp(
            r'\b(INDIA|MUMBAI|BENGALURU|BANGALORE|DELHI|GURGAON|GURUGRAM)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^A-Z0-9+&. ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final entry in _aliases.entries) {
      if (entry.key.hasMatch(value)) return entry.value;
    }

    value = value.replaceAll(
      RegExp(r'\b(PAYMENTS?|SERVICES?|PVT|PRIVATE|LTD|LIMITED)\b'),
      ' ',
    );
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isEmpty) return 'Unknown';
    return value
        .split(' ')
        .take(4)
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0]}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
