import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/address_location_picker_result.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_session_provider.dart';
import '../services/auth_service.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key, this.initialAddress});

  final SavedAddressModel? initialAddress;

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  static const String _fixedProvince = 'Jawa Tengah';
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
  String _selectedLocationSource = 'Belum dipilih';

  bool _isDefault = false;
  bool _isLoadingProfile = true;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isEditMode => widget.initialAddress != null;
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

  String _normalizeAddressLabel(String rawLabel) {
    final normalized = rawLabel.trim().toLowerCase();
    if (normalized.contains('kantor') || normalized.contains('office')) {
      return 'Kantor';
    }
    return 'Rumah';
  }

  void _fillFormFromAddress(SavedAddressModel address) {
    _selectedLabel = _normalizeAddressLabel(address.label);
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

    _detailController.text = address.detail;
    _isDefault = address.isDefault;
    if (_isCoordinatePairValid(address.latitude, address.longitude)) {
      _selectedLatitude = address.latitude;
      _selectedLongitude = address.longitude;
      _selectedLocationSource = 'Alamat tersimpan';
    } else {
      _selectedLatitude = null;
      _selectedLongitude = null;
      _selectedLocationSource = 'Belum dipilih';
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
    if (_isEditMode) {
      _fillFormFromAddress(widget.initialAddress!);
    } else {
      _selectedLabel = 'Rumah';
      _prefillUserData();
    }
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
    final buttonHeight = isCompact ? 48.0 : 52.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Form Alamat',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => context.pop(false),
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
                            _buildAddressLabelSelector(),
                            SizedBox(height: fieldSpacing),
                            _buildTextField(
                              label: 'Nama Penerima',
                              controller: _recipientController,
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
                            _buildCoverageSelectorCard(),
                            SizedBox(height: fieldSpacing),
                            _buildTextField(
                              label: 'Detail Alamat',
                              controller: _fullAddressController,
                              hintText: 'Jalan, nomor rumah, RT/RW, patokan',
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
                            SizedBox(height: fieldSpacing),
                            _buildTextField(
                              label: 'Detail Tambahan (Opsional)',
                              controller: _detailController,
                              hintText: 'Contoh: Pagar hitam, lantai 2',
                              maxLines: isCompact ? 1 : 2,
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Jadikan alamat utama'),
                              value: _isDefault,
                              onChanged: (value) {
                                setState(() {
                                  _isDefault = value;
                                });
                              },
                              activeThumbColor: AppColors.primary,
                            ),
                            SizedBox(height: isCompact ? 10 : 14),
                            if (_isEditMode)
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: buttonHeight,
                                      child: OutlinedButton(
                                        onPressed:
                                            (_isSubmitting || _isDeleting)
                                            ? null
                                            : _handleDeleteAddress,
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppColors.error,
                                          ),
                                          foregroundColor: AppColors.error,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: _isDeleting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.error,
                                                    ),
                                              )
                                            : const Text('Hapus Alamat'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: buttonHeight,
                                      child: ElevatedButton(
                                        onPressed:
                                            (_isSubmitting || _isDeleting)
                                            ? null
                                            : _handleSave,
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
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
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.white,
                                                    ),
                                              )
                                            : const Text(
                                                'Simpan',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
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
                                      borderRadius: BorderRadius.circular(12),
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
    final hasSelectedLabel = (_selectedLabel ?? '').trim().isNotEmpty;
    final hasCoverageSelection = _hasCompleteCoverageSelection();
    final hasPinnedLocation = _isCoordinatePairValid(
      _selectedLatitude,
      _selectedLongitude,
    );

    if (!hasSelectedLabel) {
      setState(() {
        _labelErrorText = 'Label alamat wajib dipilih';
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

      if (!_isCoordinatePairValid(latitudeToSave, longitudeToSave)) {
        throw const AuthException(
          'Koordinat alamat belum valid. Pilih titik di peta atau cek kembali alamat lengkap.',
        );
      }

      if (_isEditMode) {
        await AuthService.updateSavedAddress(
          addressId: widget.initialAddress!.id,
          label: _selectedLabel!,
          recipientName: _recipientController.text.trim(),
          phone: _phoneController.text.trim(),
          fullAddress: normalizedFullAddress,
          detail: _detailController.text.trim(),
          latitude: latitudeToSave,
          longitude: longitudeToSave,
          isDefault: _isDefault,
        );
      } else {
        await AuthService.createSavedAddress(
          label: _selectedLabel!,
          recipientName: _recipientController.text.trim(),
          phone: _phoneController.text.trim(),
          fullAddress: normalizedFullAddress,
          detail: _detailController.text.trim(),
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

    final result = await context.push<AddressLocationPickerResult>(
      AppRoutes.addressLocationPicker,
      extra: {'latitude': _selectedLatitude, 'longitude': _selectedLongitude},
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _selectedLatitude = result.latitude;
      _selectedLongitude = result.longitude;
      _selectedLocationSource = result.source == 'gps'
          ? 'Lokasi saat ini'
          : 'Dipilih di peta';
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
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverageSelectorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _coverageErrorText == null
              ? AppColors.border
              : AppColors.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wilayah Pengantaran *',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildReadOnlyAreaField(label: 'Provinsi', value: _selectedProvince),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildReadOnlyAreaField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Builder(
          builder: (fieldContext) {
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: !isEnabled
                  ? null
                  : () async {
                      await _scrollDropdownFieldIntoView(fieldContext);
                      if (!mounted || !fieldContext.mounted) return;
                      final pickedValue = await _showAreaOptionsMenu(
                        fieldContext: fieldContext,
                        items: items,
                      );
                      if (pickedValue != null) {
                        onChanged(pickedValue);
                      }
                    },
              child: InputDecorator(
                isEmpty: (value ?? '').trim().isEmpty,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (value ?? '').trim().isNotEmpty
                            ? value!.trim()
                            : hintText,
                        style: TextStyle(
                          color: (value ?? '').trim().isNotEmpty
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isEnabled
                          ? AppColors.textSecondary
                          : AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _scrollDropdownFieldIntoView(BuildContext fieldContext) async {
    await Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.12,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  Future<String?> _showAreaOptionsMenu({
    required BuildContext fieldContext,
    required List<String> items,
  }) {
    if (!mounted || !fieldContext.mounted) {
      return Future.value(null);
    }

    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final fieldBox = fieldContext.findRenderObject() as RenderBox;
    final fieldWidth = fieldBox.size.width;
    final fieldTopLeft = fieldBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final fieldBottomRight = fieldBox.localToGlobal(
      fieldBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    final position = RelativeRect.fromLTRB(
      fieldTopLeft.dx,
      fieldBottomRight.dy + 4,
      overlayBox.size.width - fieldBottomRight.dx,
      overlayBox.size.height - fieldBottomRight.dy,
    );

    return showMenu<String>(
      context: context,
      position: position,
      color: AppColors.white,
      surfaceTintColor: AppColors.white,
      shadowColor: Colors.black26,
      constraints: BoxConstraints(
        minWidth: fieldWidth,
        maxWidth: fieldWidth,
        maxHeight: 300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: items
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                item,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildLocationPickerCard() {
    final hasPinnedLocation = _isCoordinatePairValid(
      _selectedLatitude,
      _selectedLongitude,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _locationErrorText == null
              ? AppColors.border
              : AppColors.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Lokasi di Peta *',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasPinnedLocation
                ? 'Titik: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}'
                : 'Belum ada titik terpilih. Pilih titik di peta untuk lanjut simpan alamat.',
            style: TextStyle(
              color: hasPinnedLocation
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: hasPinnedLocation ? FontWeight.w600 : FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (_locationErrorText != null) ...[
            const SizedBox(height: 6),
            Text(
              _locationErrorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          if (hasPinnedLocation) ...[
            const SizedBox(height: 4),
            Text(
              'Sumber: $_selectedLocationSource',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openLocationPicker,
              icon: Icon(
                hasPinnedLocation
                    ? Icons.edit_location_alt
                    : Icons.map_outlined,
              ),
              label: Text(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Label Alamat',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildAddressLabelOption(
                label: 'Rumah',
                isSelected: _selectedLabel == 'Rumah',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAddressLabelOption(
                label: 'Kantor',
                isSelected: _selectedLabel == 'Kantor',
              ),
            ),
          ],
        ),
        if (_labelErrorText != null) ...[
          const SizedBox(height: 6),
          Text(
            _labelErrorText!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
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
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_isSubmitting || _isDeleting) {
            return;
          }
          setState(() {
            _selectedLabel = label;
            _labelErrorText = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _isCoordinatePairValid(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return false;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return false;
    }

    if (latitude == 0 && longitude == 0) {
      return false;
    }

    return true;
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
    _recipientController.dispose();
    _phoneController.dispose();
    _fullAddressController.dispose();
    _detailController.dispose();
    super.dispose();
  }
}
