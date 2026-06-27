import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/address_location_picker_result.dart';
import '../../../../models/user_profile_model.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../widgets/bang_select_field.dart';
import '../../application/address_form_presenter.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key, this.initialAddress});

  final SavedAddressModel? initialAddress;

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen>
    with WidgetsBindingObserver {
  static const String _fixedProvince = 'Jawa Tengah';
  static const double _buttonRadius = 10;
  static const Map<String, Map<String, Map<String, List<String>>>>
  _coverageData = {
    'Kota Salatiga': {
      'Argomulyo': {
        'Cebongan': ['50736'],
        'Kumpulrejo': ['50734'],
        'Ledok': ['50732'],
        'Noborejo': ['50736'],
        'Randuacir': ['50735'],
        'Tegalrejo': ['50733'],
      },
      'Sidomukti': {
        'Dukuh': ['50722'],
        'Kalicacing': ['50724'],
        'Kecandran': ['50723'],
        'Mangunsari': ['50721'],
      },
      'Sidorejo': {
        'Blotongan': ['50715'],
        'Bugel': ['50713'],
        'Kauman Kidul': ['50712'],
        'Pulutan': ['50716'],
        'Salatiga': ['50711'],
        'Sidorejo Lor': ['50714'],
      },
      'Tingkir': {
        'Gendongan': ['50743'],
        'Kalibening': ['50744'],
        'Kutowinangun Kidul': ['50742'],
        'Kutowinangun Lor': ['50742'],
        'Sidorejo Kidul': ['50741'],
        'Tingkir Lor': ['50746'],
        'Tingkir Tengah': ['50745'],
      },
    },
    'Kabupaten Semarang': {
      'Ambarawa': {
        'Bejalen': ['50611'],
        'Pasekan': ['50611'],
        'Baran': ['50611'],
        'Kranggan': ['50611'],
        'Kupang': ['50611'],
        'Lodoyong': ['50611'],
        'Ngampin': ['50611'],
        'Panjang': ['50611'],
        'Pojoksari': ['50611'],
        'Tambakboyo': ['50611'],
      },
      'Bancak': {
        'Bancak': ['50182'],
        'Bata': ['50182'],
        'Jlumpang': ['50182'],
        'Lembu': ['50182'],
        'Plumutan': ['50182'],
        'Pucung': ['50182'],
        'Rejosari': ['50182'],
        'Wonokerto': ['50182'],
      },
      'Bandungan': {
        'Banyukuning': ['50614'],
        'Candi': ['50614'],
        'Duren': ['50614'],
        'Jetis': ['50614'],
        'Jimbaran': ['50614'],
        'Kenteng': ['50614'],
        'Mlilir': ['50614'],
        'Pakopen': ['50614'],
        'Sidomukti': ['50614'],
        'Bandungan': ['50614'],
      },
      'Banyubiru': {
        'Banyubiru': ['50664'],
        'Gedong': ['50664'],
        'Kebondowo': ['50664'],
        'Kebumen': ['50664'],
        'Kemambang': ['50664'],
        'Ngrapah': ['50664'],
        'Rowoboni': ['50664'],
        'Sepakung': ['50664'],
        'Tegaron': ['50664'],
        'Wirogomo': ['50664'],
      },
      'Bawen': {
        'Asinan': ['50661'],
        'Doplang': ['50661'],
        'Kandangan': ['50661'],
        'Lemahireng': ['50661'],
        'Polosiri': ['50661'],
        'Poncoruso': ['50661'],
        'Samban': ['50661'],
        'Bawen': ['50661'],
        'Harjosari': ['50661'],
      },
      'Bergas': {
        'Bergas Kidul': ['50552'],
        'Diwak': ['50552'],
        'Gebugan': ['50552'],
        'Gondoriyo': ['50552'],
        'Jatijajar': ['50552'],
        'Munding': ['50552'],
        'Pagersari': ['50552'],
        'Randugunting': ['50552'],
        'Wringin Putih': ['50552'],
        'Bergas Lor': ['50552'],
        'Karangjati': ['50552'],
        'Ngempon': ['50552'],
        'Wujil': ['50552'],
      },
      'Bringin': {
        'Banding': ['50772'],
        'Bringin': ['50772'],
        'Gogodalem': ['50772'],
        'Kalijambe': ['50772'],
        'Kalikurmo': ['50772'],
        'Lebak': ['50772'],
        'Nyemoh': ['50772'],
        'Pakis': ['50772'],
        'Popongan': ['50772'],
        'Rembes': ['50772'],
        'Sambirejo': ['50772'],
        'Sendang': ['50772'],
        'Tanjung': ['50772'],
        'Tempuran': ['50772'],
        'Truko': ['50772'],
        'Wiru': ['50772'],
      },
      'Getasan': {
        'Batur': ['50774'],
        'Getasan': ['50774'],
        'Jetak': ['50774'],
        'Kopeng': ['50774'],
        'Manggihan': ['50774'],
        'Ngrawan': ['50774'],
        'Nogosaren': ['50774'],
        'Polobogo': ['50774'],
        'Samirono': ['50774'],
        'Sumogawe': ['50774'],
        'Tajuk': ['50774'],
        'Tolokan': ['50774'],
        'Wates': ['50774'],
      },
      'Jambu': {
        'Bedono': ['50663'],
        'Brongkol': ['50663'],
        'Gemawang': ['50663'],
        'Genting': ['50663'],
        'Jambu': ['50663'],
        'Kebondalem': ['50663'],
        'Kelurahan': ['50663'],
        'Kuwarasan': ['50663'],
        'Rejosari': ['50663'],
        'Gondoriyo': ['50663'],
      },
      'Kaliwungu': {
        'Jetis': ['50778'],
        'Kaliwungu': ['50778'],
        'Kener': ['50778'],
        'Kradenan': ['50778'],
        'Mukiran': ['50778'],
        'Pager': ['50778'],
        'Papringan': ['50778'],
        'Payungan': ['50778'],
        'Rogomulyo': ['50778'],
        'Siwal': ['50778'],
        'Udanwuh': ['50778'],
      },
      'Pabelan': {
        'Bejaten': ['50771'],
        'Bendungan': ['50771'],
        'Giling': ['50771'],
        'Glawan': ['50771'],
        'Jembrak': ['50771'],
        'Kadirejo': ['50771'],
        'Karanggondang': ['50771'],
        'Kauman Lor': ['50771'],
        'Pabelan': ['50771'],
        'Padaan': ['50771'],
        'Segiri': ['50771'],
        'Semowo': ['50771'],
        'Sukoharjo': ['50771'],
        'Sumberejo': ['50771'],
        'Terban': ['50771'],
        'Tukang': ['50771'],
        'Ujung-Ujung': ['50771'],
      },
      'Pringapus': {
        'Candirejo': ['50553'],
        'Derekan': ['50553'],
        'Jatirunggo': ['50553'],
        'Klepu': ['50553'],
        'Penawangan': ['50553'],
        'Pringsari': ['50553'],
        'Wonorejo': ['50553'],
        'Wonoyoso': ['50553'],
        'Pringapus': ['50553'],
      },
      'Suruh': {
        'Beji Lor': ['50776'],
        'Bonomerto': ['50776'],
        'Cukilan': ['50776'],
        'Dadapayam': ['50776'],
        'Dersansari': ['50776'],
        'Gunung Tumpeng': ['50776'],
        'Jatirejo': ['50776'],
        'Kebowan': ['50776'],
        'Kedungringin': ['50776'],
        'Ketanggi': ['50776'],
        'Krandon Lor': ['50776'],
        'Medayu': ['50776'],
        'Plumbon': ['50776'],
        'Purworejo': ['50776'],
        'Reksosari': ['50776'],
        'Sukorejo': ['50776'],
        'Suruh': ['50776'],
      },
      'Susukan': {
        'Badran': ['50777'],
        'Bakalrejo': ['50777'],
        'Gentan': ['50777'],
        'Kemetul': ['50777'],
        'Kenteng': ['50777'],
        'Ketapang': ['50777'],
        'Koripan': ['50777'],
        'Muncar': ['50777'],
        'Ngasinan': ['50777'],
        'Sidoharjo': ['50777'],
        'Susukan': ['50777'],
        'Tawang': ['50777'],
        'Timpik': ['50777'],
      },
      'Sumowono': {
        'Bumen': ['50662'],
        'Candigaron': ['50662'],
        'Duren': ['50662'],
        'Jubelan': ['50662'],
        'Kebonagung': ['50662'],
        'Kemawi': ['50662'],
        'Kemitir': ['50662'],
        'Keseneng': ['50662'],
        'Lanjan': ['50662'],
        'Losari': ['50662'],
        'Mendongan': ['50662'],
        'Ngadikerso': ['50662'],
        'Piyanggang': ['50662'],
        'Pledokan': ['50662'],
        'Sumowono': ['50662'],
        'Trayu': ['50662'],
      },
      'Tengaran': {
        'Barukan': ['50775'],
        'Bener': ['50775'],
        'Butuh': ['50775'],
        'Cukil': ['50775'],
        'Duren': ['50775'],
        'Karangduren': ['50775'],
        'Klero': ['50775'],
        'Nyamat': ['50775'],
        'Patemon': ['50775'],
        'Regunung': ['50775'],
        'Sruwen': ['50775'],
        'Sugihan': ['50775'],
        'Tegalrejo': ['50775'],
        'Tegalwaton': ['50775'],
        'Tengaran': ['50775'],
      },
      'Tuntang': {
        'Candirejo': ['50773'],
        'Delik': ['50773'],
        'Gedangan': ['50773'],
        'Jombor': ['50773'],
        'Kalibeji': ['50773'],
        'Karanganyar': ['50773'],
        'Karang Tengah': ['50773'],
        'Kesongo': ['50773'],
        'Lopait': ['50773'],
        'Ngajaran': ['50773'],
        'Rowosari': ['50773'],
        'Sraten': ['50773'],
        'Tlogo': ['50773'],
        'Tlompakan': ['50773'],
        'Tuntang': ['50773'],
        'Watuagung': ['50773'],
      },
      'Ungaran Barat': {
        'Branjang': ['50511'],
        'Gogik': ['50511'],
        'Kalisidi': ['50511'],
        'Keji': ['50511'],
        'Lerep': ['50511'],
        'Nyatnyono': ['50511'],
        'Bandarjo': ['50511'],
        'Candirejo': ['50511'],
        'Genuk': ['50511'],
        'Langensari': ['50511'],
        'Ungaran': ['50511'],
      },
      'Ungaran Timur': {
        'Kalikayen': ['50512'],
        'Kalongan': ['50512'],
        'Kawengen': ['50512'],
        'Leyangan': ['50512'],
        'Mluweh': ['50512'],
        'Beji': ['50512'],
        'Gedanganak': ['50512'],
        'Kalirejo': ['50512'],
        'Sidomulyo': ['50512'],
        'Susukan': ['50512'],
      },
    },
  };

  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _detailController = TextEditingController();
  final _customLabelController = TextEditingController();
  final _recipientFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _fullAddressFocusNode = FocusNode();
  final _customLabelFocusNode = FocusNode();
  bool _wasKeyboardVisible = false;

  String? _selectedLabel;
  final String _selectedProvince = _fixedProvince;
  String? _selectedCityRegency;
  String? _selectedDistrict;
  String? _selectedSubDistrict;
  String? _selectedPostalCode;
  String? _labelErrorText;
  String? _coverageErrorText;
  String? _locationErrorText;
  double? _selectedLatitude;
  double? _selectedLongitude;

  bool _isDefault = false;
  bool _isLoadingProfile = true;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isEditMode => widget.initialAddress != null;
  bool get _isCustomLabel => _selectedLabel == 'Lainnya';
  String get _resolvedAddressLabel {
    final selected = (_selectedLabel ?? '').trim();
    if (selected == 'Lainnya') {
      return _customLabelController.text.trim();
    }

    return selected;
  }

  List<String> get _cityRegencyOptions {
    const preferredOrder = <String>['Kabupaten Semarang', 'Kota Salatiga'];
    final options = _coverageData.keys.toList();
    options.sort((a, b) {
      final aIndex = preferredOrder.indexOf(a);
      final bIndex = preferredOrder.indexOf(b);

      if (aIndex == -1 && bIndex == -1) {
        return a.compareTo(b);
      }
      if (aIndex == -1) {
        return 1;
      }
      if (bIndex == -1) {
        return -1;
      }
      return aIndex.compareTo(bIndex);
    });
    return options;
  }

  List<String> get _districtOptions {
    final cityRegency = _selectedCityRegency;
    if (cityRegency == null) {
      return const [];
    }
    return (_coverageData[cityRegency] ?? const {}).keys.toList();
  }

  List<String> get _subDistrictOptions {
    final cityRegency = _selectedCityRegency;
    final district = _selectedDistrict;
    if (cityRegency == null || district == null) {
      return const [];
    }

    return (_coverageData[cityRegency]?[district] ?? const {}).keys.toList();
  }

  List<String> get _postalCodeOptions {
    final cityRegency = _selectedCityRegency;
    final district = _selectedDistrict;
    final subDistrict = _selectedSubDistrict;
    if (cityRegency == null || district == null || subDistrict == null) {
      return const [];
    }

    return (_coverageData[cityRegency]?[district]?[subDistrict] ?? const [])
        .toList();
  }

  void _fillFormFromAddress(SavedAddressModel address) {
    _selectedLabel = AddressFormPresenter.normalizeAddressLabel(address.label);
    _customLabelController.text = _selectedLabel == 'Lainnya'
        ? address.label.trim()
        : '';
    _labelErrorText = null;
    _locationErrorText = null;
    _recipientController.text = address.recipientName;
    _phoneController.text = address.phone;

    final rawFullAddress = address.fullAddress.trim();
    if (rawFullAddress.isNotEmpty) {
      _hydrateCoverageSelection(rawFullAddress);
      _fullAddressController.text = _extractManualDetailFromFullAddress(
        rawFullAddress,
      );
    } else {
      // Fallback for legacy/partial payloads so edit form is never blank.
      final fallbackAddress = address.displayAddress.trim();
      _hydrateCoverageSelection(fallbackAddress);
      _fullAddressController.text = _extractManualDetailFromFullAddress(
        fallbackAddress,
      );
    }

    _detailController.clear();
    _isDefault = address.isDefault;
    if (AddressFormPresenter.isCoordinatePairValid(
      address.latitude,
      address.longitude,
    )) {
      _selectedLatitude = address.latitude;
      _selectedLongitude = address.longitude;
    } else {
      _selectedLatitude = null;
      _selectedLongitude = null;
    }
    _isLoadingProfile = false;
  }

  void _hydrateCoverageSelection(String fullAddress) {
    final normalized = fullAddress.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }

    for (final cityRegency in _coverageData.keys) {
      final cityNeedle = cityRegency.toLowerCase();
      if (!normalized.contains(cityNeedle)) {
        continue;
      }

      _selectedCityRegency = cityRegency;
      final districts = _coverageData[cityRegency] ?? const {};

      for (final district in districts.keys) {
        if (normalized.contains(district.toLowerCase())) {
          _selectedDistrict = district;
          break;
        }
      }

      if (_selectedDistrict != null) {
        final subDistricts = districts[_selectedDistrict!] ?? const {};
        for (final subDistrict in subDistricts.keys) {
          if (normalized.contains(subDistrict.toLowerCase())) {
            _selectedSubDistrict = subDistrict;
            break;
          }
        }

        _selectedSubDistrict ??= subDistricts.keys.isNotEmpty
            ? subDistricts.keys.first
            : null;
      }

      final postalMatch = RegExp(r'\b\d{5}\b').firstMatch(normalized);
      if (postalMatch != null) {
        final found = postalMatch.group(0);
        if (found != null) {
          if (_selectedDistrict != null && _selectedSubDistrict != null) {
            final options =
                districts[_selectedDistrict!]?[_selectedSubDistrict!] ??
                const [];
            _selectedPostalCode = options.contains(found)
                ? found
                : (options.isNotEmpty ? options.first : null);
          } else {
            _selectedPostalCode = found;
          }
        }
      }

      if (_selectedDistrict != null &&
          _selectedSubDistrict != null &&
          _selectedPostalCode == null) {
        final options =
            districts[_selectedDistrict!]?[_selectedSubDistrict!] ?? const [];
        if (options.isNotEmpty) {
          _selectedPostalCode = options.first;
        }
      }
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isEditMode) {
      _fillFormFromAddress(widget.initialAddress!);
    } else {
      _selectedLabel = 'Rumah';
      _customLabelController.clear();
      _prefillUserData();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) {
      return;
    }

    final isKeyboardVisible = View.of(context).viewInsets.bottom > 0;
    final didKeyboardClose = _wasKeyboardVisible && !isKeyboardVisible;
    _wasKeyboardVisible = isKeyboardVisible;

    if (didKeyboardClose) {
      _unfocusWhenKeyboardClosed();
    }
  }

  bool get _hasFocusedField =>
      _recipientFocusNode.hasFocus ||
      _phoneFocusNode.hasFocus ||
      _fullAddressFocusNode.hasFocus ||
      _customLabelFocusNode.hasFocus;

  void _syncKeyboardVisibility(bool isKeyboardOpen) {
    _wasKeyboardVisible = isKeyboardOpen;
  }

  void _unfocusWhenKeyboardClosed() {
    if (!mounted) {
      return;
    }

    final view = View.maybeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (view?.viewInsets.bottom ?? 0) > 0) {
        return;
      }

      if (_hasFocusedField) {
        _dismissAddressFormFocus();
      }
    });
  }

  void _dismissAddressFormFocus() {
    _recipientFocusNode.unfocus();
    _phoneFocusNode.unfocus();
    _fullAddressFocusNode.unfocus();
    _customLabelFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleBackNavigation() {
    if (!mounted) {
      return;
    }

    if (_hasFocusedField || MediaQuery.viewInsetsOf(context).bottom > 0) {
      _dismissAddressFormFocus();
      _unfocusWhenKeyboardClosed();
      return;
    }

    context.pop(false);
  }

  @override
  void didUpdateWidget(covariant AddAddressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldId = oldWidget.initialAddress?.id;
    final newAddress = widget.initialAddress;

    if (newAddress != null && newAddress.id != oldId) {
      setState(() {
        _fillFormFromAddress(newAddress);
      });
    }
  }

  Future<void> _prefillUserData() async {
    try {
      final profile = await AuthService.fetchCurrentUserProfile();

      if (!mounted) {
        return;
      }

      _recipientController.text = profile.name;
      _phoneController.text = profile.phone;
    } catch (_) {
      // Keep fields empty if profile prefill fails.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).height < 760;
    final fieldSpacing = isCompact ? 10.0 : 12.0;
    final buttonHeight = AppTextScaling.adaptive(
      context,
      normal: isCompact ? 48.0 : 52.0,
      large: isCompact ? 54.0 : 58.0,
    );
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    _syncKeyboardVisibility(isKeyboardOpen);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _isEditMode ? 'Ubah Alamat' : 'Tambah Alamat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final keyboardBottomInset = MediaQuery.viewInsetsOf(
                      context,
                    ).bottom;

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        12 + keyboardBottomInset,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(
                                label: 'Nama Penerima',
                                controller: _recipientController,
                                focusNode: _recipientFocusNode,
                                hintText: 'Nama penerima',
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return 'Nama penerima wajib diisi';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: fieldSpacing),
                              _buildTextField(
                                label: 'Nomor Telepon',
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                hintText: '08xxxxxxxxxx',
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return 'Nomor telepon wajib diisi';
                                  }
                                  final normalized = text.replaceAll(
                                    RegExp(r'[^0-9+]'),
                                    '',
                                  );
                                  if (!RegExp(
                                    r'^\+?[0-9]{10,15}$',
                                  ).hasMatch(normalized)) {
                                    return 'Format nomor telepon tidak valid';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: fieldSpacing),
                              _buildCoverageSelectorFields(),
                              SizedBox(height: fieldSpacing),
                              _buildTextField(
                                label: 'Detail Alamat',
                                controller: _fullAddressController,
                                focusNode: _fullAddressFocusNode,
                                hintText: 'Jalan, no rumah, RT/RW, patokan',
                                maxLines: isCompact ? 2 : 3,
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return 'Detail alamat wajib diisi';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: fieldSpacing),
                              _buildLocationPickerCard(),
                              const SizedBox(height: 10),
                              _buildAddressSettingsSection(),
                              SizedBox(height: isCompact ? 10 : 14),
                              if (_isEditMode)
                                _buildEditAddressActions(buttonHeight)
                              else
                                SizedBox(
                                  width: double.infinity,
                                  height: buttonHeight,
                                  child: ElevatedButton(
                                    onPressed: (_isSubmitting || _isDeleting)
                                        ? null
                                        : _handleSave,
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          _buttonRadius,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Simpan Alamat',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildEditAddressActions(double buttonHeight) {
    final effectiveButtonHeight = (buttonHeight - 6).clamp(44.0, buttonHeight);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: effectiveButtonHeight,
            child: OutlinedButton(
              onPressed: (_isSubmitting || _isDeleting)
                  ? null
                  : _handleDeleteAddress,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_buttonRadius),
                ),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : const Text(
                      'Hapus Alamat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: effectiveButtonHeight,
            child: ElevatedButton(
              onPressed: (_isSubmitting || _isDeleting) ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_buttonRadius),
                ),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text(
                      'Simpan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) {
      return;
    }

    final currentState = _formKey.currentState;
    if (currentState == null) {
      return;
    }

    final isFormValid = currentState.validate();
    final addressLabel = _resolvedAddressLabel;
    final hasSelectedLabel = addressLabel.isNotEmpty;
    final hasCoverageSelection = _hasCompleteCoverageSelection();
    final hasPinnedLocation = AddressFormPresenter.isCoordinatePairValid(
      _selectedLatitude,
      _selectedLongitude,
    );

    if (!hasSelectedLabel) {
      setState(() {
        _labelErrorText = _isCustomLabel
            ? null
            : 'Tandai sebagai wajib dipilih';
      });
    }

    if (!hasPinnedLocation) {
      setState(() {
        _locationErrorText = 'Lokasi di peta wajib dipilih';
      });
    }

    if (!hasCoverageSelection) {
      setState(() {
        _coverageErrorText =
            'Pilih Kabupaten/Kota, Kecamatan, Kelurahan/Desa, dan Kode Pos terlebih dahulu';
      });
    }

    if (!isFormValid ||
        !hasSelectedLabel ||
        !hasCoverageSelection ||
        !hasPinnedLocation) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final rawFullAddress = _composeFullAddress();

      final normalizedFullAddress = rawFullAddress;
      double? latitudeToSave;
      double? longitudeToSave;

      latitudeToSave = _selectedLatitude;
      longitudeToSave = _selectedLongitude;

      try {
        await AuthService.validateSavedAddress(fullAddress: rawFullAddress);
      } on AuthException {
        // Keep raw address text when geocoding is unavailable.
      }

      if (!AddressFormPresenter.isCoordinatePairValid(
        latitudeToSave,
        longitudeToSave,
      )) {
        throw const AuthException(
          'Koordinat alamat belum valid. Pilih titik di peta atau cek kembali alamat lengkap.',
        );
      }

      if (_isEditMode) {
        await AuthService.updateSavedAddress(
          addressId: widget.initialAddress!.id,
          label: addressLabel,
          recipientName: _recipientController.text.trim(),
          phone: _phoneController.text.trim(),
          fullAddress: normalizedFullAddress,
          detail: '',
          latitude: latitudeToSave,
          longitude: longitudeToSave,
          isDefault: _isDefault,
        );
      } else {
        await AuthService.createSavedAddress(
          label: addressLabel,
          recipientName: _recipientController.text.trim(),
          phone: _phoneController.text.trim(),
          fullAddress: normalizedFullAddress,
          detail: '',
          latitude: latitudeToSave,
          longitude: longitudeToSave,
          isDefault: _isDefault,
        );
      }

      await ref.read(authSessionProvider.notifier).refreshSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Alamat berhasil diperbarui.'
                : 'Alamat berhasil disimpan.',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop(true);
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openLocationPicker() async {
    if (_isSubmitting || _isDeleting) {
      return;
    }

    _dismissAddressFormFocus();

    final result = await context.push<AddressLocationPickerResult>(
      AppRoutes.addressLocationPicker,
      extra: {
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'restrictAddressSearchToServiceArea': true,
      },
    );

    if (!mounted) {
      return;
    }

    _dismissAddressFormFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _dismissAddressFormFocus();
      }
    });

    if (result == null) {
      return;
    }

    setState(() {
      _selectedLatitude = result.latitude;
      _selectedLongitude = result.longitude;
      _locationErrorText = null;
    });
  }

  Future<void> _handleDeleteAddress() async {
    if (!_isEditMode || _isDeleting || _isSubmitting) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Alamat'),
          content: const Text('Yakin ingin menghapus alamat ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await AuthService.deleteSavedAddress(
        addressId: widget.initialAddress!.id,
      );

      await ref.read(authSessionProvider.notifier).refreshSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat berhasil dihapus.'),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop(true);
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    FocusNode? focusNode,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        hintText: hintText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        filled: true,
        fillColor: AppColors.white,
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDefaultAddressToggle() {
    final isDisabled = _isSubmitting || _isDeleting;

    return Semantics(
      label: 'Jadikan alamat utama',
      toggled: _isDefault,
      button: true,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Jadikan alamat utama',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          _AddressDefaultToggle(
            value: _isDefault,
            enabled: !isDisabled,
            onChanged: (value) {
              if (!isDisabled) {
                setState(() {
                  _isDefault = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDefaultAddressToggle(),
        const SizedBox(height: 6),
        _buildAddressLabelSelector(),
      ],
    );
  }

  Widget _buildOutlinedSection({
    required String label,
    required Widget child,
    required bool hasError,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: hasError ? AppColors.error : AppColors.border,
      ),
    );

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: hasError ? AppColors.error : AppColors.textSecondary,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.all(14),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        errorBorder: border,
        focusedErrorBorder: border,
      ),
      child: child,
    );
  }

  Widget _buildCoverageSelectorFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReadOnlyAreaField(label: 'Provinsi', value: _selectedProvince),
        const SizedBox(height: 10),
        _buildAreaDropdownField(
          label: 'Kabupaten/Kota',
          value: _selectedCityRegency,
          hintText: 'Pilih kabupaten/kota',
          items: _cityRegencyOptions,
          onChanged: (value) {
            if (_isSubmitting || _isDeleting) {
              return;
            }
            setState(() {
              _selectedCityRegency = value;
              _selectedDistrict = null;
              _selectedSubDistrict = null;
              _selectedPostalCode = null;
              _coverageErrorText = null;
            });
          },
        ),
        const SizedBox(height: 10),
        _buildAreaDropdownField(
          label: 'Kecamatan',
          value: _selectedDistrict,
          hintText: _selectedCityRegency == null
              ? 'Pilih kabupaten/kota dulu'
              : 'Pilih kecamatan',
          items: _districtOptions,
          onChanged: _selectedCityRegency == null
              ? null
              : (value) {
                  if (_isSubmitting || _isDeleting) {
                    return;
                  }
                  setState(() {
                    _selectedDistrict = value;
                    _selectedSubDistrict = null;
                    _selectedPostalCode = null;
                    _coverageErrorText = null;
                  });
                },
        ),
        const SizedBox(height: 10),
        _buildAreaDropdownField(
          label: 'Kelurahan/Desa',
          value: _selectedSubDistrict,
          hintText: _selectedDistrict == null
              ? 'Pilih kecamatan dulu'
              : 'Pilih kelurahan/desa',
          items: _subDistrictOptions,
          onChanged: _selectedDistrict == null
              ? null
              : (value) {
                  if (_isSubmitting || _isDeleting) {
                    return;
                  }
                  setState(() {
                    _selectedSubDistrict = value;
                    final postalOptions = _postalCodeOptions;
                    _selectedPostalCode = postalOptions.isNotEmpty
                        ? postalOptions.first
                        : null;
                    _coverageErrorText = null;
                  });
                },
        ),
        const SizedBox(height: 10),
        _buildAreaDropdownField(
          label: 'Kode Pos',
          value: _selectedPostalCode,
          hintText: _selectedSubDistrict == null
              ? 'Pilih kelurahan/desa dulu'
              : 'Pilih kode pos',
          items: _postalCodeOptions,
          onChanged: _selectedSubDistrict == null
              ? null
              : (value) {
                  if (_isSubmitting || _isDeleting) {
                    return;
                  }
                  setState(() {
                    _selectedPostalCode = value;
                    _coverageErrorText = null;
                  });
                },
        ),
        if (_coverageErrorText != null) ...[
          const SizedBox(height: 6),
          Text(
            _coverageErrorText!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyAreaField({
    required String label,
    required String value,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: border,
        enabledBorder: border,
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAreaDropdownField({
    required String label,
    required String? value,
    required String hintText,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    final isEnabled = onChanged != null && items.isNotEmpty;

    return BangSelectField(
      label: label,
      value: value,
      hintText: hintText,
      items: items,
      enabled: isEnabled,
      onChanged: onChanged,
      labelFontSize: 12,
      labelBottomSpacing: 4,
      fieldFontSize: 14,
      hintFontSize: 14,
      borderRadius: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      selectedFontWeight: FontWeight.w500,
    );
  }

  Widget _buildLocationPickerCard() {
    final hasPinnedLocation = AddressFormPresenter.isCoordinatePairValid(
      _selectedLatitude,
      _selectedLongitude,
    );

    return _buildOutlinedSection(
      label: 'Lokasi di Peta',
      hasError: _locationErrorText != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasPinnedLocation
                ? 'Titik: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}'
                : 'Belum ada titik terpilih. Pilih titik di peta untuk lanjut simpan alamat.',
            style: TextStyle(
              color: hasPinnedLocation
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: hasPinnedLocation ? 13 : 11.5,
              fontWeight: hasPinnedLocation ? FontWeight.w600 : FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (_locationErrorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _locationErrorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openLocationPicker,
              style:
                  OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.55),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_buttonRadius),
                    ),
                  ).copyWith(
                    overlayColor: WidgetStatePropertyAll(
                      AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
              child: Text(
                hasPinnedLocation
                    ? 'Ubah Titik di Peta'
                    : 'Pilih Titik di Peta',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressLabelSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useInlineLayout = constraints.maxWidth >= 320;
        final label = const Text(
          'Tandai sebagai',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
          ),
        );
        final options = _buildAddressLabelOptionsRow();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (useInlineLayout)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  label,
                  const SizedBox(width: 12),
                  Expanded(child: options),
                ],
              )
            else ...[
              label,
              const SizedBox(height: 4),
              options,
            ],
            if (_isCustomLabel) ...[
              const SizedBox(height: 10),
              _buildTextField(
                label: 'Label Alamat',
                controller: _customLabelController,
                focusNode: _customLabelFocusNode,
                hintText: 'Contoh: Kos, Toko, Kontrakan',
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Label alamat wajib diisi';
                  }
                  return null;
                },
              ),
            ],
            if (_labelErrorText != null) ...[
              const SizedBox(height: 6),
              Text(
                _labelErrorText!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAddressLabelOptionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildAddressLabelOption(
            label: 'Rumah',
            isSelected: _selectedLabel == 'Rumah',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildAddressLabelOption(
            label: 'Kantor',
            isSelected: _selectedLabel == 'Kantor',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildAddressLabelOption(
            label: 'Lainnya',
            isSelected: _selectedLabel == 'Lainnya',
          ),
        ),
      ],
    );
  }

  Widget _buildAddressLabelOption({
    required String label,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_buttonRadius),
        onTap: () {
          if (_isSubmitting || _isDeleting) {
            return;
          }
          setState(() {
            _selectedLabel = label;
            if (label != 'Lainnya') {
              _customLabelController.clear();
            }
            _labelErrorText = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(_buttonRadius),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.3 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _hasCompleteCoverageSelection() {
    return _selectedCityRegency != null &&
        _selectedDistrict != null &&
        _selectedSubDistrict != null &&
        _selectedPostalCode != null;
  }

  String _composeFullAddress() {
    final detailText = _fullAddressController.text.trim();
    final segments = <String>[
      detailText,
      _selectedSubDistrict ?? '',
      _selectedDistrict != null ? 'Kec. $_selectedDistrict' : '',
      _selectedCityRegency ?? '',
      _selectedProvince,
      _selectedPostalCode ?? '',
    ];

    return segments.where((segment) => segment.trim().isNotEmpty).join(', ');
  }

  String _extractManualDetailFromFullAddress(String fullAddress) {
    final text = fullAddress.trim();
    if (text.isEmpty) {
      return '';
    }

    final fullParts = text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (fullParts.isEmpty) {
      return text;
    }

    final areaParts = <String>[
      _selectedSubDistrict ?? '',
      _selectedDistrict != null ? 'Kec. $_selectedDistrict' : '',
      _selectedCityRegency ?? '',
      _selectedProvince,
      _selectedPostalCode ?? '',
    ].where((part) => part.trim().isNotEmpty).toList();

    if (areaParts.isNotEmpty && fullParts.length > areaParts.length) {
      var isSuffixMatch = true;
      for (var i = 0; i < areaParts.length; i++) {
        final fromFull = fullParts[fullParts.length - areaParts.length + i]
            .toLowerCase();
        final fromArea = areaParts[i].toLowerCase();

        final normalizedFull = fromFull.replaceAll('kec. ', '').trim();
        final normalizedArea = fromArea.replaceAll('kec. ', '').trim();

        if (normalizedFull != normalizedArea) {
          isSuffixMatch = false;
          break;
        }
      }

      if (isSuffixMatch) {
        return fullParts.take(fullParts.length - areaParts.length).join(', ');
      }
    }

    return fullParts.first;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recipientFocusNode.dispose();
    _phoneFocusNode.dispose();
    _fullAddressFocusNode.dispose();
    _customLabelFocusNode.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    _fullAddressController.dispose();
    _detailController.dispose();
    _customLabelController.dispose();
    super.dispose();
  }
}

class _AddressDefaultToggle extends StatelessWidget {
  const _AddressDefaultToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final trackColor = !enabled
        ? AppColors.border.withValues(alpha: 0.72)
        : value
        ? AppColors.success
        : AppColors.border.withValues(alpha: 0.82);
    final thumbShadowColor = AppColors.black.withValues(
      alpha: enabled ? 0.12 : 0.06,
    );

    return Semantics(
      checked: value,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 54,
            height: 30,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: enabled
                      ? AppColors.white
                      : AppColors.white.withValues(alpha: 0.86),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: thumbShadowColor,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
