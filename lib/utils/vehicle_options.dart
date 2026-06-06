const vehicleTypeOptions = <String>[
  'Motor Matic',
  'Motor Manual',
  'Motor Lainnya',
];

const vehicleBrandOptions = <String>['Honda', 'Yamaha', 'Suzuki', 'Kawasaki'];

List<String> vehicleTypeItems({String? selected}) {
  return _optionsWithSelected(vehicleTypeOptions, selected);
}

List<String> vehicleBrandItems({String? selected}) {
  return _optionsWithSelected(vehicleBrandOptions, selected);
}

List<String> _optionsWithSelected(List<String> options, String? selected) {
  final normalizedSelected = (selected ?? '').trim();
  if (normalizedSelected.isEmpty || options.contains(normalizedSelected)) {
    return options;
  }

  return <String>[...options, normalizedSelected];
}
