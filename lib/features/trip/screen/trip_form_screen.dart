import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../service/trip_service.dart';

class TripFormScreen extends StatefulWidget {
  final TripService? tripService;
  final TripDetail? initialTrip;

  const TripFormScreen({super.key, this.tripService, this.initialTrip});

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  static const _defaultCountryOptions = <_CountryOption>[
    _CountryOption(
      code: 'JP',
      name: '일본',
      flag: '🇯🇵',
      currency: 'JPY',
      aliases: ['japan', '도쿄', '오사카', '후쿠오카', '교토', '삿포로'],
    ),
    _CountryOption(
      code: 'KR',
      name: '대한민국',
      flag: '🇰🇷',
      currency: 'KRW',
      aliases: ['korea', 'south korea', '한국', '서울', '부산', '제주'],
    ),
    _CountryOption(
      code: 'US',
      name: '미국',
      flag: '🇺🇸',
      currency: 'USD',
      aliases: ['usa', 'united states', 'america', '뉴욕', '엘에이', '하와이'],
    ),
    _CountryOption(
      code: 'CN',
      name: '중국',
      flag: '🇨🇳',
      currency: 'CNY',
      aliases: ['china', '상하이', '베이징', '칭다오'],
    ),
    _CountryOption(
      code: 'TW',
      name: '대만',
      flag: '🇹🇼',
      currency: 'TWD',
      aliases: ['taiwan', '타이베이', '가오슝'],
    ),
    _CountryOption(
      code: 'HK',
      name: '홍콩',
      flag: '🇭🇰',
      currency: 'HKD',
      aliases: ['hong kong'],
    ),
    _CountryOption(
      code: 'MO',
      name: '마카오',
      flag: '🇲🇴',
      currency: 'MOP',
      aliases: ['macau', 'macao'],
    ),
    _CountryOption(
      code: 'VN',
      name: '베트남',
      flag: '🇻🇳',
      currency: 'VND',
      aliases: ['vietnam', '다낭', '나트랑', '하노이', '호치민', '푸꾸옥'],
    ),
    _CountryOption(
      code: 'TH',
      name: '태국',
      flag: '🇹🇭',
      currency: 'THB',
      aliases: ['thailand', '방콕', '푸켓', '치앙마이', '파타야'],
    ),
    _CountryOption(
      code: 'SG',
      name: '싱가포르',
      flag: '🇸🇬',
      currency: 'SGD',
      aliases: ['singapore'],
    ),
    _CountryOption(
      code: 'MY',
      name: '말레이시아',
      flag: '🇲🇾',
      currency: 'MYR',
      aliases: ['malaysia', '쿠알라룸푸르', '코타키나발루', '랑카위'],
    ),
    _CountryOption(
      code: 'PH',
      name: '필리핀',
      flag: '🇵🇭',
      currency: 'PHP',
      aliases: ['philippines', '세부', '보라카이', '마닐라'],
    ),
    _CountryOption(
      code: 'ID',
      name: '인도네시아',
      flag: '🇮🇩',
      currency: 'IDR',
      aliases: ['indonesia', '발리', '자카르타'],
    ),
    _CountryOption(
      code: 'MN',
      name: '몽골',
      flag: '🇲🇳',
      currency: 'MNT',
      aliases: ['mongolia', '울란바토르'],
    ),
    _CountryOption(
      code: 'AU',
      name: '호주',
      flag: '🇦🇺',
      currency: 'AUD',
      aliases: ['australia', '시드니', '멜버른', '브리즈번', '골드코스트'],
    ),
    _CountryOption(
      code: 'NZ',
      name: '뉴질랜드',
      flag: '🇳🇿',
      currency: 'NZD',
      aliases: ['new zealand', '오클랜드', '퀸스타운'],
    ),
    _CountryOption(
      code: 'GB',
      name: '영국',
      flag: '🇬🇧',
      currency: 'GBP',
      aliases: ['uk', 'united kingdom', 'england', '런던'],
    ),
    _CountryOption(
      code: 'FR',
      name: '프랑스',
      flag: '🇫🇷',
      currency: 'EUR',
      aliases: ['france', '파리', '니스'],
    ),
    _CountryOption(
      code: 'IT',
      name: '이탈리아',
      flag: '🇮🇹',
      currency: 'EUR',
      aliases: ['italy', '로마', '피렌체', '베네치아', '밀라노'],
    ),
    _CountryOption(
      code: 'ES',
      name: '스페인',
      flag: '🇪🇸',
      currency: 'EUR',
      aliases: ['spain', '바르셀로나', '마드리드', '세비야'],
    ),
    _CountryOption(
      code: 'PT',
      name: '포르투갈',
      flag: '🇵🇹',
      currency: 'EUR',
      aliases: ['portugal', '리스본', '포르투'],
    ),
    _CountryOption(
      code: 'DE',
      name: '독일',
      flag: '🇩🇪',
      currency: 'EUR',
      aliases: ['germany', '베를린', '뮌헨', '프랑크푸르트'],
    ),
    _CountryOption(
      code: 'CH',
      name: '스위스',
      flag: '🇨🇭',
      currency: 'CHF',
      aliases: ['switzerland', '취리히', '인터라켄'],
    ),
    _CountryOption(
      code: 'AT',
      name: '오스트리아',
      flag: '🇦🇹',
      currency: 'EUR',
      aliases: ['austria', '빈', '비엔나'],
    ),
    _CountryOption(
      code: 'CZ',
      name: '체코',
      flag: '🇨🇿',
      currency: 'CZK',
      aliases: ['czech', 'czech republic', '프라하'],
    ),
    _CountryOption(
      code: 'HU',
      name: '헝가리',
      flag: '🇭🇺',
      currency: 'HUF',
      aliases: ['hungary', '부다페스트'],
    ),
    _CountryOption(
      code: 'TR',
      name: '튀르키예',
      flag: '🇹🇷',
      currency: 'TRY',
      aliases: ['turkey', 'turkiye', '이스탄불', '카파도키아'],
    ),
    _CountryOption(
      code: 'AE',
      name: '아랍에미리트',
      flag: '🇦🇪',
      currency: 'AED',
      aliases: ['uae', 'dubai', '두바이', '아부다비'],
    ),
    _CountryOption(
      code: 'CA',
      name: '캐나다',
      flag: '🇨🇦',
      currency: 'CAD',
      aliases: ['canada', '밴쿠버', '토론토', '몬트리올'],
    ),
    _CountryOption(
      code: 'MX',
      name: '멕시코',
      flag: '🇲🇽',
      currency: 'MXN',
      aliases: ['mexico', '칸쿤', '멕시코시티'],
    ),
    _CountryOption(
      code: 'BR',
      name: '브라질',
      flag: '🇧🇷',
      currency: 'BRL',
      aliases: ['brazil', '리우', '상파울루'],
    ),
    _CountryOption(
      code: 'IN',
      name: '인도',
      flag: '🇮🇳',
      currency: 'INR',
      aliases: ['india', '델리', '뭄바이'],
    ),
    _CountryOption(
      code: 'NP',
      name: '네팔',
      flag: '🇳🇵',
      currency: 'NPR',
      aliases: ['nepal', '카트만두'],
    ),
    _CountryOption(
      code: 'EG',
      name: '이집트',
      flag: '🇪🇬',
      currency: 'EGP',
      aliases: ['egypt', '카이로'],
    ),
    _CountryOption(
      code: 'MA',
      name: '모로코',
      flag: '🇲🇦',
      currency: 'MAD',
      aliases: ['morocco', '마라케시', '카사블랑카'],
    ),
  ];

  late final TripService _tripService;
  late final List<_CountryOption> _countryOptions;
  late final TextEditingController _countrySearchController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _companionSearchController;
  late final TextEditingController _titleController;

  final List<_SelectedCompanion> _companions = [];
  final List<String> _selectedCountryCodes = [];
  UserSearchUser? _searchedUser;
  int? _currentUserId;
  bool _isSearchingCompanion = false;
  int _nextGuestCompanionNumber = 1;
  int _step = 0;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEdit => widget.initialTrip != null;

  @override
  void initState() {
    super.initState();
    _tripService = widget.tripService ?? TripService();
    final trip = widget.initialTrip;

    _countryOptions = [..._defaultCountryOptions];
    for (final country in trip?.countries ?? const <TripCountry>[]) {
      if (!_selectedCountryCodes.contains(country.countryCode)) {
        _selectedCountryCodes.add(country.countryCode);
      }
      final exists = _countryOptions.any(
        (option) => option.code == country.countryCode,
      );
      if (!exists) {
        _countryOptions.add(
          _CountryOption(
            code: country.countryCode,
            name: country.countryName,
            flag: '',
            currency: 'KRW',
          ),
        );
      }
    }

    _countrySearchController = TextEditingController();
    _startDateController = TextEditingController(text: trip?.startDate ?? '');
    _endDateController = TextEditingController(text: trip?.endDate ?? '');
    _companionSearchController = TextEditingController();
    _titleController = TextEditingController(text: trip?.title ?? '');

    if (_isEdit && trip != null) {
      _companions.addAll(
        trip.participants
            .where((participant) => participant.participantRole != 'LEADER')
            .map(
              (participant) => _SelectedCompanion(
                displayName: participant.displayName,
                profileImageUrl: participant.profileImageUrl,
                userId: participant.userId,
              ),
            ),
      );
    }
  }

  @override
  void dispose() {
    _countrySearchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _companionSearchController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _step -= 1;
      _errorMessage = null;
    });
  }

  Future<void> _handlePrimaryAction() async {
    if (_step < 3) {
      if (!_validateCurrentStep()) return;
      setState(() {
        _step += 1;
        _errorMessage = null;
      });
      return;
    }

    await _save();
  }

  bool _validateCurrentStep() {
    if (_step == 0 && _selectedCountryCodes.isEmpty) {
      setState(() => _errorMessage = '떠날 국가를 선택해 주세요.');
      return false;
    }
    if (_step == 1 && !_hasValidDateRange()) {
      setState(() => _errorMessage = '시작일과 종료일을 올바른 순서로 입력해 주세요.');
      return false;
    }
    return true;
  }

  bool _hasValidDateRange() {
    final startDate = _nullableText(_startDateController);
    final endDate = _nullableText(_endDateController);
    if (startDate == null || endDate == null) return false;
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!datePattern.hasMatch(startDate) || !datePattern.hasMatch(endDate)) {
      return false;
    }
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    return start != null && end != null && !start.isAfter(end);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final input = _buildInput();
    if (input == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = _isEdit
          ? await _tripService.updateTrip(widget.initialTrip!.id, input)
          : await _tripService.createTrip(input);

      if (_isEdit) {
        await _tripService.updateTripCountries(
          widget.initialTrip!.id,
          input.countries,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '여행 저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  TripFormInput? _buildInput() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _step = 3;
        _errorMessage = '여행 제목을 입력해 주세요.';
      });
      return null;
    }

    final countries = _selectedCountries;
    if (countries.isEmpty) {
      setState(() {
        _step = 0;
        _errorMessage = '떠날 국가를 선택해 주세요.';
      });
      return null;
    }
    if (_companions.any((companion) => companion.displayName.trim().isEmpty)) {
      setState(() {
        _step = 2;
        _errorMessage = '비회원 동행 이름을 입력해 주세요.';
      });
      return null;
    }

    return TripFormInput(
      title: title,
      defaultCurrency: _currencyForCountry(countries.first.code),
      exchangeRateBaseDate: null,
      startDate: _nullableText(_startDateController),
      endDate: _nullableText(_endDateController),
      countries: countries
          .asMap()
          .entries
          .map(
            (entry) => TripCountryInput(
              countryCode: entry.value.code,
              countryName: entry.value.name,
              sortOrder: entry.key,
            ),
          )
          .toList(),
      participants: _isEdit
          ? const []
          : _companions
                .map(
                  (companion) => TripCompanionInput(
                    displayName: companion.displayName.trim(),
                    profileImageUrl: companion.profileImageUrl,
                    userId: companion.userId,
                  ),
                )
                .toList(),
    );
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  void _selectCountry(_CountryOption country) {
    setState(() {
      if (_selectedCountryCodes.contains(country.code)) {
        _selectedCountryCodes.remove(country.code);
      } else {
        _selectedCountryCodes.add(country.code);
      }
      _errorMessage = null;
    });
  }

  Future<int?> _getCurrentUserId() async {
    final cachedUserId = _currentUserId;
    if (cachedUserId != null) return cachedUserId;

    try {
      final user = await _tripService.getCurrentUser();
      if (mounted) setState(() => _currentUserId = user.id);
      return user.id;
    } catch (_) {
      return null;
    }
  }

  String _currencyForCountry(String countryCode) {
    return _countryOptions
        .firstWhere(
          (country) => country.code == countryCode,
          orElse: () => const _CountryOption(
            code: 'KR',
            name: '대한민국',
            flag: '🇰🇷',
            currency: 'KRW',
          ),
        )
        .currency;
  }

  void _addGuestCompanion() {
    if (_companions.length >= 9) return;

    var name = '동행자 $_nextGuestCompanionNumber';
    while (_companions.any((companion) => companion.displayName == name)) {
      _nextGuestCompanionNumber += 1;
      name = '동행자 $_nextGuestCompanionNumber';
    }

    setState(() {
      _companions.add(_SelectedCompanion(displayName: name));
      _nextGuestCompanionNumber += 1;
      _searchedUser = null;
      _errorMessage = null;
    });
  }

  Future<void> _searchCompanionByNickname() async {
    final nickname = _companionSearchController.text.trim();
    if (nickname.length < 2 || nickname.length > 20) {
      setState(() {
        _searchedUser = null;
        _errorMessage = '닉네임은 2~20자로 검색해 주세요.';
      });
      return;
    }

    setState(() {
      _isSearchingCompanion = true;
      _searchedUser = null;
      _errorMessage = null;
    });

    try {
      final result = await _tripService.searchUserByNickname(nickname);
      if (!mounted) return;
      final user = result.user;
      if (user != null && user.userId == await _getCurrentUserId()) {
        if (!mounted) return;
        setState(() {
          _searchedUser = null;
          _errorMessage = '본인은 동행자로 추가할 수 없습니다.';
        });
        return;
      }
      setState(() {
        _searchedUser = user;
        if (!result.found) {
          _errorMessage = '일치하는 사용자를 찾지 못했습니다. 비회원 동행으로 추가할 수 있어요.';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSearchingCompanion = false);
    }
  }

  void _addSearchedUser(UserSearchUser user) {
    if (_currentUserId == user.userId) {
      setState(() {
        _searchedUser = null;
        _errorMessage = '본인은 동행자로 추가할 수 없습니다.';
      });
      return;
    }
    if (_companions.length >= 9 ||
        _companions.any((companion) => companion.userId == user.userId)) {
      return;
    }
    setState(() {
      _companions.add(
        _SelectedCompanion(
          displayName: user.nickname,
          profileImageUrl: user.profileImageUrl,
          userId: user.userId,
        ),
      );
      _companionSearchController.clear();
      _searchedUser = null;
      _errorMessage = null;
    });
  }

  void _removeCompanion(_SelectedCompanion companion) {
    setState(() {
      _companions.remove(companion);
      _errorMessage = null;
    });
  }

  void _renameGuestCompanion(_SelectedCompanion companion, String value) {
    final index = _companions.indexOf(companion);
    if (index < 0 || companion.userId != null) return;
    setState(() {
      _companions[index] = companion.copyWith(displayName: value);
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SafeArea(
          bottom: false,
          child: _TripWizardHeader(title: _headerTitle, onBack: _goBack),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepIndicator(currentStep: _step),
              const SizedBox(height: 20),
              Expanded(child: _buildStep()),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFCC0000),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('saveTripButton'),
                  onPressed: _isSaving ? null : _handlePrimaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  ),
                  child: Text(
                    _isSaving ? '저장 중...' : (_step == 3 ? '완료' : '다음'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _CountryStep(
        searchController: _countrySearchController,
        countries: _filteredCountries,
        selectedCountryCodes: _selectedCountryCodes,
        onSelect: _selectCountry,
        onSearchChanged: () => setState(() {}),
      ),
      1 => _ScheduleStep(
        startDateController: _startDateController,
        endDateController: _endDateController,
        onDateChanged: () => setState(() {}),
      ),
      2 => _CompanionStep(
        searchController: _companionSearchController,
        companions: _companions,
        searchedUser: _searchedUser,
        isSearching: _isSearchingCompanion,
        onSearch: _searchCompanionByNickname,
        onAddGuest: _addGuestCompanion,
        onSelectUser: _addSearchedUser,
        onRenameGuest: _renameGuestCompanion,
        onRemove: _removeCompanion,
        isEdit: _isEdit,
      ),
      _ => _TitleStep(titleController: _titleController),
    };
  }

  String get _headerTitle {
    return switch (_step) {
      0 => '국가 선택',
      1 => '일정 선택',
      2 => '동행 추가',
      _ => '여행 제목',
    };
  }

  List<_CountryOption> get _filteredCountries {
    final keyword = _countrySearchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return _countryOptions;
    return _countryOptions.where((country) {
      return country.matches(keyword);
    }).toList();
  }

  List<_CountryOption> get _selectedCountries {
    return _selectedCountryCodes
        .map(
          (code) =>
              _countryOptions.firstWhere((country) => country.code == code),
        )
        .toList();
  }
}

class _TripWizardHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TripWizardHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left, size: 22),
              color: const Color(0xFF1A1A1A),
              tooltip: '뒤로',
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (index) {
        final isActive = index == currentStep;
        return Padding(
          padding: EdgeInsets.only(right: index == 3 ? 0 : 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: isActive ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

class _CountryStep extends StatelessWidget {
  final TextEditingController searchController;
  final List<_CountryOption> countries;
  final List<String> selectedCountryCodes;
  final ValueChanged<_CountryOption> onSelect;
  final VoidCallback onSearchChanged;

  const _CountryStep({
    required this.searchController,
    required this.countries,
    required this.selectedCountryCodes,
    required this.onSelect,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepTitle(title: '어디로 떠나시나요?', subtitle: '복수 선택 가능'),
        const SizedBox(height: 18),
        _BoxTextField(
          key: const ValueKey('tripCountrySearchField'),
          controller: searchController,
          hintText: '국가 검색',
          prefixIcon: Icons.search,
          onChanged: (_) => onSearchChanged(),
          readOnly: false,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: countries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final country = countries[index];
              final selected = selectedCountryCodes.contains(country.code);
              return _CountryRow(
                country: country,
                isSelected: selected,
                onTap: () => onSelect(country),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final VoidCallback onDateChanged;

  const _ScheduleStep({
    required this.startDateController,
    required this.endDateController,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _StepTitle(title: '언제 떠나시나요?', subtitle: ''),
        const SizedBox(height: 18),
        const _FieldLabel('시작일'),
        _BoxTextField(
          key: const ValueKey('tripStartDateField'),
          controller: startDateController,
          hintText: '2026-04-01',
          suffixText: '›',
          keyboardType: TextInputType.number,
          inputFormatters: const [_DateInputFormatter()],
          onChanged: (_) => onDateChanged(),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('종료일'),
        _BoxTextField(
          key: const ValueKey('tripEndDateField'),
          controller: endDateController,
          hintText: '2026-04-05',
          suffixText: '›',
          keyboardType: TextInputType.number,
          inputFormatters: const [_DateInputFormatter()],
          onChanged: (_) => onDateChanged(),
        ),
        const SizedBox(height: 18),
        _ScheduleSummary(
          startDate: startDateController.text,
          endDate: endDateController.text,
        ),
      ],
    );
  }
}

class _CompanionStep extends StatelessWidget {
  final TextEditingController searchController;
  final List<_SelectedCompanion> companions;
  final UserSearchUser? searchedUser;
  final bool isSearching;
  final VoidCallback onSearch;
  final VoidCallback onAddGuest;
  final ValueChanged<UserSearchUser> onSelectUser;
  final void Function(_SelectedCompanion companion, String value) onRenameGuest;
  final ValueChanged<_SelectedCompanion> onRemove;
  final bool isEdit;

  const _CompanionStep({
    required this.searchController,
    required this.companions,
    required this.searchedUser,
    required this.isSearching,
    required this.onSearch,
    required this.onAddGuest,
    required this.onSelectUser,
    required this.onRenameGuest,
    required this.onRemove,
    required this.isEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _StepTitle(title: '누구와 함께하나요?', subtitle: '방장 포함 최대 10명'),
        const SizedBox(height: 18),
        const _FieldLabel('실제 사용자 초대'),
        _BoxTextField(
          key: const ValueKey('tripCompanionsField'),
          controller: searchController,
          hintText: '사용자 닉네임 입력',
          prefixIcon: Icons.search,
          onSubmitted: (_) => onSearch(),
          readOnly: isEdit,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isEdit || isSearching ? null : onSearch,
          icon: isSearching
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search, size: 16),
          label: const Text('사용자 검색'),
          style: OutlinedButton.styleFrom(
            disabledForegroundColor: const Color(0xFF1A1A1A),
            side: const BorderSide(color: Color(0xFF1A1A1A)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            minimumSize: const Size.fromHeight(42),
          ),
        ),
        const SizedBox(height: 8),
        const _FieldLabel('비회원 동행'),
        OutlinedButton.icon(
          key: const ValueKey('addGuestCompanionButton'),
          onPressed: isEdit ? null : onAddGuest,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
          label: const Text('동행자 이름으로 추가'),
          style: OutlinedButton.styleFrom(
            disabledForegroundColor: const Color(0xFF1A1A1A),
            side: const BorderSide(color: Color(0xFF1A1A1A)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            minimumSize: const Size.fromHeight(42),
          ),
        ),
        if (searchedUser != null) ...[
          const SizedBox(height: 12),
          _UserSearchResultRow(
            key: ValueKey('tripUserSearchResult-${searchedUser!.userId}'),
            user: searchedUser!,
            onTap: () => onSelectUser(searchedUser!),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          '선택된 동행자 (${companions.length + 1}/10)',
          style: const TextStyle(fontSize: 12, color: Color(0xFF4A4A4A)),
        ),
        const SizedBox(height: 10),
        const _CompanionRow(name: '나', role: '방장'),
        ...companions.map(
          (companion) => _CompanionRow(
            key: ValueKey('tripCompanion-${identityHashCode(companion)}'),
            name: companion.displayName,
            role: companion.userId == null ? '비회원' : null,
            editable: companion.userId == null && !isEdit,
            onRename: companion.userId == null
                ? (value) => onRenameGuest(companion, value)
                : null,
            onRemove: () => onRemove(companion),
          ),
        ),
      ],
    );
  }
}

class _TitleStep extends StatelessWidget {
  final TextEditingController titleController;

  const _TitleStep({required this.titleController});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepTitle(title: '여행 제목을 정해주세요', subtitle: '최대 30자'),
        const SizedBox(height: 18),
        _BoxTextField(
          key: const ValueKey('tripTitleField'),
          controller: titleController,
          hintText: '예) 도쿄 벚꽃 4박 5일',
          maxLength: 30,
        ),
      ],
    );
  }
}

class _UserSearchResultRow extends StatelessWidget {
  final UserSearchUser user;
  final VoidCallback onTap;

  const _UserSearchResultRow({
    super.key,
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          border: Border.all(color: const Color(0xFF1A1A1A)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A1A1A),
              child: Text(
                user.nickname.characters.first,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.nickname,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.add, size: 18, color: Color(0xFF1A1A1A)),
          ],
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StepTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
          ),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF4A4A4A)),
      ),
    );
  }
}

class _BoxTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final String? suffixText;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _BoxTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixText,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hintText,
        counterText: maxLength == null ? null : '',
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: const Color(0xFF4A4A4A)),
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: Color(0xFF6B6B6B)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF1A1A1A)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF1A1A1A)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF1A1A1A), width: 1.4),
        ),
      ),
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  const _DateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();

    for (var index = 0; index < limited.length; index++) {
      if (index == 4 || index == 6) buffer.write('-');
      buffer.write(limited[index]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CountryRow extends StatelessWidget {
  final _CountryOption country;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountryRow({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAFAFA) : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFE5E5E5),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text(country.flag)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(country.name, style: const TextStyle(fontSize: 13)),
            ),
            SizedBox(
              width: 20,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1A1A1A) : Colors.white,
                  border: Border.all(color: const Color(0xFF1A1A1A)),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleSummary extends StatelessWidget {
  final String startDate;
  final String endDate;

  const _ScheduleSummary({required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context) {
    final nights = _calculateNights(startDate, endDate);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nights == null ? '일정 미정' : '$nights박 ${nights + 1}일',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${startDate.isEmpty ? '시작일' : startDate} - ${endDate.isEmpty ? '종료일' : endDate}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B6B)),
          ),
        ],
      ),
    );
  }

  int? _calculateNights(String startDate, String endDate) {
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start).inDays;
  }
}

class _CompanionRow extends StatelessWidget {
  final String name;
  final String? role;
  final bool editable;
  final ValueChanged<String>? onRename;
  final VoidCallback? onRemove;

  const _CompanionRow({
    super.key,
    required this.name,
    this.role,
    this.editable = false,
    this.onRename,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFFAFAFA),
            foregroundColor: const Color(0xFF6B6B6B),
            child: Text(
              name.characters.first,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: editable
                ? TextFormField(
                    key: const ValueKey('guestCompanionNameField'),
                    initialValue: name,
                    onChanged: onRename,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 13),
                  )
                : Text(name, style: const TextStyle(fontSize: 13)),
          ),
          if (role != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1A1A1A)),
              ),
              child: Text(
                role!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else if (onRemove != null)
            const SizedBox(width: 8),
          if (onRemove != null)
            IconButton(
              key: const ValueKey('removeCompanionButton'),
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
              color: const Color(0xFF9E9E9E),
              tooltip: '삭제',
            ),
        ],
      ),
    );
  }
}

class _CountryOption {
  final String code;
  final String name;
  final String flag;
  final String currency;
  final List<String> aliases;

  const _CountryOption({
    required this.code,
    required this.name,
    required this.flag,
    required this.currency,
    this.aliases = const [],
  });

  bool matches(String keyword) {
    return name.toLowerCase().contains(keyword) ||
        code.toLowerCase().contains(keyword) ||
        currency.toLowerCase().contains(keyword) ||
        aliases.any((alias) => alias.toLowerCase().contains(keyword));
  }
}

class _SelectedCompanion {
  final String displayName;
  final String? profileImageUrl;
  final int? userId;

  const _SelectedCompanion({
    required this.displayName,
    this.profileImageUrl,
    this.userId,
  });

  _SelectedCompanion copyWith({String? displayName}) {
    return _SelectedCompanion(
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl,
      userId: userId,
    );
  }
}
