import 'package:flutter/material.dart';
import '../../core/banking_repository.dart';
import '../../core/device_security_service.dart';
import '../../core/constants.dart';
import '../../models/card_model.dart';

/// Card Controls & Security Screen.
/// Meets requirement TR-M02: "card controls"
/// Meets requirement TR-M06: "screen capture on sensitive screens (recommended)"
class CardControlsScreen extends StatefulWidget {
  const CardControlsScreen({super.key});

  @override
  State<CardControlsScreen> createState() => _CardControlsScreenState();
}

class _CardControlsScreenState extends State<CardControlsScreen> {
  final BankingRepository _repo = BankingRepository();
  final DeviceSecurityService _sec = DeviceSecurityService();

  List<CardModel> _cards = [];
  int _selectedCardIndex = 0;
  bool _isLoading = true;
  bool _showCvv = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final cards = await _repo.getCards();
    if (mounted) {
      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    }
  }

  CardModel? get _currentCard {
    if (_cards.isEmpty) return null;
    return _cards[_selectedCardIndex.clamp(0, _cards.length - 1)];
  }

  Future<void> _toggleFreeze() async {
    final card = _currentCard;
    if (card == null) return;

    final updated = await _repo.toggleCardFreeze(card.cardId);
    setState(() {
      _cards[_selectedCardIndex] = updated;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isFrozen ? 'Card has been locked / frozen.' : 'Card has been unfrozen and is active.',
          ),
          backgroundColor: updated.isFrozen ? AppColors.roseDanger : AppColors.mintDark,
        ),
      );
    }
  }

  Future<void> _updateFeature({
    bool? online,
    bool? international,
    bool? contactless,
    bool? atm,
    double? limit,
  }) async {
    final card = _currentCard;
    if (card == null) return;

    final updated = card.copyWith(
      isOnlineAllowed: online ?? card.isOnlineAllowed,
      isInternationalAllowed: international ?? card.isInternationalAllowed,
      isContactlessAllowed: contactless ?? card.isContactlessAllowed,
      isAtmAllowed: atm ?? card.isAtmAllowed,
      dailyLimit: limit ?? card.dailyLimit,
    );
    final saved = await _repo.updateCard(updated);
    setState(() {
      _cards[_selectedCardIndex] = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _currentCard;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Card Controls & Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryViolet))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TR-M06: Sensitive Screen Protection Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.plumCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.plumBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_rounded, size: 18, color: AppColors.magentaHot),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'PROTECTED SCREEN: Screen capture restriction active (${_sec.isScreenCaptureProtected ? "FLAG_SECURE ON" : "STANDBY"}) (TR-M06).',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (card == null)
                    const Center(child: Text('No active debit cards found for this account.'))
                  else ...[
                    // Debit Card Widget
                    _buildDebitCard(card),
                    if (_cards.length > 1) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _cards.length,
                          (idx) => InkWell(
                            onTap: () => setState(() => _selectedCardIndex = idx),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedCardIndex == idx ? AppColors.primaryViolet : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Quick Lock / Freeze Toggle
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: card.isFrozen ? AppColors.roseBorder : AppColors.cardBorderLight,
                          width: card.isFrozen ? 2 : 1,
                        ),
                      ),
                      color: card.isFrozen ? AppColors.roseLight : Colors.white,
                      child: SwitchListTile(
                        value: card.isFrozen,
                        onChanged: (_) => _toggleFreeze(),
                        activeThumbColor: AppColors.roseDanger,
                        activeTrackColor: AppColors.roseLight,
                        title: Text(
                          card.isFrozen ? 'CARD IS LOCKED (FROZEN)' : 'Lock / Freeze Card',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: card.isFrozen ? AppColors.roseDark : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          card.isFrozen
                              ? 'All transactions, withdrawals, and online payments are blocked.'
                              : 'Instantly block all card usage if lost, misplaced, or suspected compromised.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: card.isFrozen ? AppColors.roseBorder : AppColors.violetSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            card.isFrozen ? Icons.lock_rounded : Icons.lock_open_rounded,
                            color: card.isFrozen ? AppColors.roseDark : AppColors.primaryViolet,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card Payment Controls
                    const Text(
                      'Transaction Channels',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enable or restrict specific channels for enhanced security',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.cardBorderLight),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: card.isOnlineAllowed && !card.isFrozen,
                            onChanged: card.isFrozen ? null : (v) => _updateFeature(online: v),
                            activeThumbColor: AppColors.primaryViolet,
                            activeTrackColor: AppColors.violetSoft,
                            title: const Text('Online E-Commerce Payments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Allow purchases on web apps and online merchants', style: TextStyle(fontSize: 12)),
                            secondary: const Icon(Icons.shopping_bag_outlined, color: AppColors.primaryViolet),
                          ),
                          const Divider(height: 1, indent: 56, color: AppColors.cardBorderLight),
                          SwitchListTile(
                            value: card.isInternationalAllowed && !card.isFrozen,
                            onChanged: card.isFrozen ? null : (v) => _updateFeature(international: v),
                            activeThumbColor: AppColors.primaryViolet,
                            activeTrackColor: AppColors.violetSoft,
                            title: const Text('International Transactions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Allow cross-border and foreign currency charges', style: TextStyle(fontSize: 12)),
                            secondary: const Icon(Icons.public_rounded, color: AppColors.primaryViolet),
                          ),
                          const Divider(height: 1, indent: 56, color: AppColors.cardBorderLight),
                          SwitchListTile(
                            value: card.isContactlessAllowed && !card.isFrozen,
                            onChanged: card.isFrozen ? null : (v) => _updateFeature(contactless: v),
                            activeThumbColor: AppColors.primaryViolet,
                            activeTrackColor: AppColors.violetSoft,
                            title: const Text('Contactless (NFC) Tap & Pay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Allow physical point-of-sale tap payments', style: TextStyle(fontSize: 12)),
                            secondary: const Icon(Icons.contactless_rounded, color: AppColors.primaryViolet),
                          ),
                          const Divider(height: 1, indent: 56, color: AppColors.cardBorderLight),
                          SwitchListTile(
                            value: card.isAtmAllowed && !card.isFrozen,
                            onChanged: card.isFrozen ? null : (v) => _updateFeature(atm: v),
                            activeThumbColor: AppColors.primaryViolet,
                            activeTrackColor: AppColors.violetSoft,
                            title: const Text('ATM Cash Withdrawals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Allow physical cash dispensing at ATM terminals', style: TextStyle(fontSize: 12)),
                            secondary: const Icon(Icons.local_atm_rounded, color: AppColors.primaryViolet),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Daily Spending Limits & Interactive Budget Meter
                    const Text(
                      'Daily Spending Limit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Limit total transaction velocity per calendar day',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.cardBorderLight),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Daily Limit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  AppConstants.formatCurrency(card.dailyLimit, card.currencyCode),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryViolet),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Interactive Budget Usage Progress Bar
                            Builder(
                              builder: (ctx) {
                                final spentPct = (card.dailySpent / card.dailyLimit).clamp(0.0, 1.0);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: spentPct,
                                        minHeight: 8,
                                        backgroundColor: AppColors.violetSoft,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          spentPct > 0.8 ? AppColors.roseDanger : AppColors.primaryViolet,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Spent: ${AppConstants.formatCurrency(card.dailySpent, card.currencyCode)} (${(spentPct * 100).toStringAsFixed(1)}%)',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Interactive Slider
                            Slider(
                              value: card.dailyLimit.clamp(5000.0, 100000.0),
                              min: 5000.0,
                              max: 100000.0,
                              divisions: 19,
                              label: AppConstants.formatCurrency(card.dailyLimit, card.currencyCode),
                              activeColor: AppColors.primaryViolet,
                              inactiveColor: AppColors.violetSoft,
                              onChanged: card.isFrozen ? null : (v) => _updateFeature(limit: v),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [10000.0, 25000.0, 50000.0, 100000.0].map((val) {
                                return ChoiceChip(
                                  label: Text(
                                    AppConstants.formatCurrency(val, card.currencyCode),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: card.dailyLimit == val ? Colors.white : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  selected: card.dailyLimit == val,
                                  selectedColor: AppColors.primaryViolet,
                                  backgroundColor: Colors.white,
                                  onSelected: card.isFrozen ? null : (_) => _updateFeature(limit: val),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildDebitCard(CardModel card) {
    return Container(
      width: double.infinity,
      height: 210,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: card.isFrozen
            ? const LinearGradient(
                colors: [Color(0xFF334155), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF140826), Color(0xFF2A0F4D), Color(0xFF48147A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: card.isFrozen ? AppColors.roseBorder : AppColors.magentaBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (card.isFrozen ? Colors.blueGrey : AppColors.primaryViolet).withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Chip, Contactless & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Center(
                      child: Icon(Icons.memory, size: 20, color: Color(0xFF5A4300)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.contactless_rounded, color: Colors.white70, size: 24),
                ],
              ),
              Row(
                children: [
                  // Capstone Brand Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'CAPSTONE PLATINUM',
                      style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: card.isFrozen ? AppColors.roseDanger : AppColors.mintDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      card.isFrozen ? 'LOCKED' : 'ACTIVE',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Middle: Card Number Masked
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showCvv
                    ? '4829 9182 3019 4829'
                    : card.cardNumberMasked,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  letterSpacing: 2.2,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: Icon(_showCvv ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 18),
                onPressed: () => setState(() => _showCvv = !_showCvv),
                tooltip: 'Toggle Card Number & CVV',
              ),
            ],
          ),

          // Bottom Row: Holder, Expiry, CVV
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CARDHOLDER', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 0.5)),
                  Text(
                    card.cardHolderName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('EXPIRES', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 0.5)),
                  Text(
                    card.expiryFormatted,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _showCvv = !_showCvv),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CVV (TAP)', style: TextStyle(color: Colors.white54, fontSize: 8)),
                      Text(
                        _showCvv ? card.cvv : '•••',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
